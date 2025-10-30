// Vocabulary Service - Manages vocabulary learning with SRS
// Handles adding words, review scheduling, and progress tracking

import 'package:sqflite/sqflite.dart';
import '../models/vocabulary_item.dart';

class VocabularyService {
  static const String _tableName = 'vocabulary_items';
  static const String _reviewsTableName = 'vocabulary_reviews';
  
  final Database _database;
  
  VocabularyService(this._database);
  
  /// Initialize vocabulary tables
  Future<void> initialize() async {
    // Create main vocabulary table
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        source_language TEXT NOT NULL,
        target_language TEXT NOT NULL,
        translation TEXT NOT NULL,
        definition TEXT,
        context TEXT,
        book_title TEXT,
        book_location TEXT,
        created_at INTEGER NOT NULL,
        last_reviewed INTEGER NOT NULL,
        tags TEXT,
        status TEXT NOT NULL DEFAULT 'learning',
        srs_repetitions INTEGER NOT NULL DEFAULT 0,
        srs_easiness_factor REAL NOT NULL DEFAULT 2.5,
        srs_interval INTEGER NOT NULL DEFAULT 1,
        srs_lapses INTEGER NOT NULL DEFAULT 0,
        srs_next_review INTEGER NOT NULL,
        srs_total_reviews INTEGER NOT NULL DEFAULT 0,
        srs_correct_reviews INTEGER NOT NULL DEFAULT 0,
        UNIQUE(word, source_language, target_language)
      )
    ''');
    
    // Create reviews history table
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS $_reviewsTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vocabulary_id INTEGER NOT NULL,
        review_date INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        quality INTEGER,
        response_time_ms INTEGER,
        FOREIGN KEY (vocabulary_id) REFERENCES $_tableName (id) ON DELETE CASCADE
      )
    ''');
    
    // Create indexes for performance
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_vocabulary_next_review 
      ON $_tableName(srs_next_review)
    ''');
    
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_vocabulary_status 
      ON $_tableName(status)
    ''');
    
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_vocabulary_language 
      ON $_tableName(source_language, target_language)
    ''');
    
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_reviews_vocabulary 
      ON $_reviewsTableName(vocabulary_id)
    ''');
  }
  
  /// Add a new vocabulary item
  Future<int> addVocabularyItem(VocabularyItem item) async {
    try {
      return await _database.insert(
        _tableName,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw VocabularyException('Failed to add vocabulary item: $e');
    }
  }
  
  /// Get vocabulary item by ID
  Future<VocabularyItem?> getVocabularyItem(int id) async {
    try {
      final results = await _database.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (results.isEmpty) return null;
      return VocabularyItem.fromMap(results.first);
    } catch (e) {
      throw VocabularyException('Failed to get vocabulary item: $e');
    }
  }
  
  /// Get all vocabulary items
  Future<List<VocabularyItem>> getAllVocabularyItems({
    VocabularyStatus? status,
    String? sourceLanguage,
    String? targetLanguage,
    int? limit,
    int? offset,
  }) async {
    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      final conditions = <String>[];
      
      if (status != null) {
        conditions.add('status = ?');
        whereArgs.add(status.name);
      }
      
      if (sourceLanguage != null) {
        conditions.add('source_language = ?');
        whereArgs.add(sourceLanguage);
      }
      
      if (targetLanguage != null) {
        conditions.add('target_language = ?');
        whereArgs.add(targetLanguage);
      }
      
      if (conditions.isNotEmpty) {
        whereClause = conditions.join(' AND ');
      }
      
      final results = await _database.query(
        _tableName,
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );
      
      return results.map((row) => VocabularyItem.fromMap(row)).toList();
    } catch (e) {
      throw VocabularyException('Failed to get vocabulary items: $e');
    }
  }
  
  /// Get items due for review
  Future<List<VocabularyItem>> getItemsDueForReview({
    int limit = 20,
    VocabularyStatus? status,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      String whereClause = 'srs_next_review <= ?';
      List<dynamic> whereArgs = [now];
      
      if (status != null) {
        whereClause += ' AND status = ?';
        whereArgs.add(status.name);
      } else {
        // Default to learning items only
        whereClause += ' AND status = ?';
        whereArgs.add(VocabularyStatus.learning.name);
      }
      
      final results = await _database.query(
        _tableName,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'srs_next_review ASC',
        limit: limit,
      );
      
      return results.map((row) => VocabularyItem.fromMap(row)).toList();
    } catch (e) {
      throw VocabularyException('Failed to get items due for review: $e');
    }
  }
  
  /// Record a review and update SRS data
  Future<void> recordReview({
    required int vocabularyId,
    required ReviewResult result,
  }) async {
    try {
      await _database.transaction((txn) async {
        // Get current item with null safety
        final itemResults = await txn.query(
          _tableName,
          where: 'id = ?',
          whereArgs: [vocabularyId],
        );
        
        if (itemResults.isEmpty) {
          throw VocabularyException('Vocabulary item not found for ID: $vocabularyId');
        }
        
        final currentItem = VocabularyItem.fromMap(itemResults.first);
        
        // Validate result data before processing
        if (result.quality != null && (result.quality! < 0 || result.quality! > 5)) {
          throw VocabularyException('Invalid quality score: ${result.quality}');
        }
        
        // Calculate new SRS data
        final newSrsData = currentItem.srsData.updateFromReview(result);
        
        // Update vocabulary item
        final updatedItem = currentItem.copyWith(
          lastReviewed: result.timestamp,
          srsData: newSrsData,
        );
        
        final updateResult = await txn.update(
          _tableName,
          updatedItem.toMap(),
          where: 'id = ?',
          whereArgs: [vocabularyId],
        );
        
        if (updateResult == 0) {
          throw VocabularyException('Failed to update vocabulary item: no rows affected');
        }
        
        // Record review in history with error handling
        try {
          await txn.insert(_reviewsTableName, {
            'vocabulary_id': vocabularyId,
            'review_date': result.timestamp.millisecondsSinceEpoch,
            'correct': result.correct ? 1 : 0,
            'quality': result.quality,
            'response_time_ms': result.responseTime?.inMilliseconds,
          });
        } catch (reviewError) {
          throw VocabularyException('Failed to record review history: $reviewError');
        }
      });
    } catch (e) {
      if (e is VocabularyException) {
        rethrow;
      }
      throw VocabularyException('Failed to record review: $e');
    }
  }
  
  /// Update vocabulary item
  Future<void> updateVocabularyItem(VocabularyItem item) async {
    try {
      await _database.update(
        _tableName,
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
    } catch (e) {
      throw VocabularyException('Failed to update vocabulary item: $e');
    }
  }
  
  /// Delete vocabulary item
  Future<void> deleteVocabularyItem(int id) async {
    try {
      await _database.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw VocabularyException('Failed to delete vocabulary item: $e');
    }
  }
  
  /// Search vocabulary items
  Future<List<VocabularyItem>> searchVocabulary({
    required String query,
    String? sourceLanguage,
    String? targetLanguage,
    int limit = 50,
  }) async {
    try {
      String whereClause = '(word LIKE ? OR translation LIKE ? OR definition LIKE ?)';
      List<dynamic> whereArgs = ['%$query%', '%$query%', '%$query%'];
      
      if (sourceLanguage != null) {
        whereClause += ' AND source_language = ?';
        whereArgs.add(sourceLanguage);
      }
      
      if (targetLanguage != null) {
        whereClause += ' AND target_language = ?';
        whereArgs.add(targetLanguage);
      }
      
      final results = await _database.query(
        _tableName,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'last_reviewed DESC',
        limit: limit,
      );
      
      return results.map((row) => VocabularyItem.fromMap(row)).toList();
    } catch (e) {
      throw VocabularyException('Failed to search vocabulary: $e');
    }
  }
  
  /// Get vocabulary statistics
  Future<VocabularyStats> getVocabularyStats() async {
    try {
      // Total counts by status with null safety
      final statusCounts = await _database.rawQuery('''
        SELECT status, COUNT(*) as count 
        FROM $_tableName 
        GROUP BY status
      ''');
      
      final statusMap = <VocabularyStatus, int>{};
      for (final row in statusCounts) {
        final statusName = row['status'] as String?;
        if (statusName == null) continue;
        
        final status = VocabularyStatus.values.firstWhere(
          (s) => s.name == statusName,
          orElse: () => VocabularyStatus.learning,
        );
        
        final count = row['count'] as int? ?? 0;
        statusMap[status] = count;
      }
      
      // Items due for review with null safety
      final now = DateTime.now().millisecondsSinceEpoch;
      final dueResults = await _database.rawQuery('''
        SELECT COUNT(*) as due_count 
        FROM $_tableName 
        WHERE srs_next_review <= ? AND status = ?
      ''', [now, VocabularyStatus.learning.name]);
      
      final dueCount = dueResults.isNotEmpty 
          ? (dueResults.first['due_count'] as int? ?? 0)
          : 0;
      
      // Language pairs with null safety
      final languageResults = await _database.rawQuery('''
        SELECT source_language, target_language, COUNT(*) as count 
        FROM $_tableName 
        GROUP BY source_language, target_language
      ''');
      
      final languagePairs = <String, int>{};
      for (final row in languageResults) {
        final sourceLanguage = row['source_language'] as String? ?? 'unknown';
        final targetLanguage = row['target_language'] as String? ?? 'unknown';
        final count = row['count'] as int? ?? 0;
        
        final pair = '$sourceLanguage → $targetLanguage';
        languagePairs[pair] = count;
      }
      
      // Recent activity (last 7 days) with null safety
      final weekAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      final recentResults = await _database.rawQuery('''
        SELECT COUNT(*) as recent_reviews 
        FROM $_reviewsTableName 
        WHERE review_date >= ?
      ''', [weekAgo]);
      
      final recentReviews = recentResults.isNotEmpty 
          ? (recentResults.first['recent_reviews'] as int? ?? 0)
          : 0;
      
      return VocabularyStats(
        totalItems: statusMap.values.fold(0, (sum, count) => sum + count),
        learningItems: statusMap[VocabularyStatus.learning] ?? 0,
        masteredItems: statusMap[VocabularyStatus.mastered] ?? 0,
        suspendedItems: statusMap[VocabularyStatus.suspended] ?? 0,
        itemsDueForReview: dueCount,
        languagePairs: languagePairs,
        recentReviews: recentReviews,
      );
    } catch (e) {
      throw VocabularyException('Failed to get vocabulary stats: $e');
    }
  }
  
  /// Get review history for an item
  Future<List<ReviewRecord>> getReviewHistory(int vocabularyId) async {
    try {
      final results = await _database.query(
        _reviewsTableName,
        where: 'vocabulary_id = ?',
        whereArgs: [vocabularyId],
        orderBy: 'review_date DESC',
      );
      
      return results.map((row) => ReviewRecord.fromMap(row)).toList();
    } catch (e) {
      throw VocabularyException('Failed to get review history: $e');
    }
  }
  
  /// Check if word already exists in vocabulary
  Future<VocabularyItem?> findExistingItem({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final results = await _database.query(
        _tableName,
        where: 'word = ? AND source_language = ? AND target_language = ?',
        whereArgs: [word, sourceLanguage, targetLanguage],
      );
      
      if (results.isEmpty) return null;
      return VocabularyItem.fromMap(results.first);
    } catch (e) {
      throw VocabularyException('Failed to find existing item: $e');
    }
  }
}

class VocabularyStats {
  final int totalItems;
  final int learningItems;
  final int masteredItems;
  final int suspendedItems;
  final int itemsDueForReview;
  final Map<String, int> languagePairs;
  final int recentReviews;
  
  const VocabularyStats({
    required this.totalItems,
    required this.learningItems,
    required this.masteredItems,
    required this.suspendedItems,
    required this.itemsDueForReview,
    required this.languagePairs,
    required this.recentReviews,
  });
  
  double get masteryPercentage {
    return totalItems > 0 ? (masteredItems / totalItems) * 100 : 0.0;
  }
  
  String get mostStudiedLanguagePair {
    if (languagePairs.isEmpty) return 'None';
    return languagePairs.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

class ReviewRecord {
  final int id;
  final int vocabularyId;
  final DateTime reviewDate;
  final bool correct;
  final int? quality;
  final Duration? responseTime;
  
  const ReviewRecord({
    required this.id,
    required this.vocabularyId,
    required this.reviewDate,
    required this.correct,
    this.quality,
    this.responseTime,
  });
  
  factory ReviewRecord.fromMap(Map<String, dynamic> map) {
    return ReviewRecord(
      id: map['id'] as int,
      vocabularyId: map['vocabulary_id'] as int,
      reviewDate: DateTime.fromMillisecondsSinceEpoch(map['review_date'] as int),
      correct: (map['correct'] as int) == 1,
      quality: map['quality'] as int?,
      responseTime: map['response_time_ms'] != null 
          ? Duration(milliseconds: map['response_time_ms'] as int)
          : null,
    );
  }
}

class VocabularyException implements Exception {
  final String message;
  const VocabularyException(this.message);
  
  @override
  String toString() => 'VocabularyException: $message';
}