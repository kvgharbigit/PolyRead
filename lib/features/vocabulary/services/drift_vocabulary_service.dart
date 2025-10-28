// Drift Vocabulary Service - Direct integration with Drift database
// Enhanced vocabulary service that works directly with AppDatabase

import 'package:drift/drift.dart';
import 'package:polyread/core/database/app_database.dart';
import '../models/vocabulary_item.dart';
import '../models/vocabulary_item_model.dart';

class DriftVocabularyService {
  final AppDatabase _database;
  
  DriftVocabularyService(this._database);
  
  /// Add a word to vocabulary from translation
  Future<int> addVocabularyItem({
    required String sourceText,
    required String translation,
    required String sourceLanguage,
    required String targetLanguage,
    required int bookId,
    String? context,
    String? bookPosition,
  }) async {
    try {
      final companion = VocabularyItemsCompanion.insert(
        bookId: bookId,
        sourceText: sourceText,
        translation: translation,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        context: Value(context),
        bookPosition: Value(bookPosition),
        reviewCount: const Value(0),
        difficulty: const Value(2.5), // SM-2 default difficulty
        nextReview: Value(DateTime.now().add(const Duration(days: 1))),
        createdAt: Value(DateTime.now()),
        isFavorite: const Value(false),
      );
      
      return await _database.into(_database.vocabularyItems).insert(
        companion,
        onConflict: DoUpdate((old) => companion),
      );
    } catch (e) {
      throw VocabularyException('Failed to add vocabulary item: $e');
    }
  }
  
  /// Get vocabulary items for a book
  Future<List<VocabularyItemModel>> getVocabularyForBook(int bookId) async {
    try {
      final query = _database.select(_database.vocabularyItems)
        ..where((v) => v.bookId.equals(bookId))
        ..orderBy([
          (v) => OrderingTerm(expression: v.createdAt, mode: OrderingMode.desc),
        ]);
      
      final results = await query.get();
      return results.map((row) => VocabularyItemModel.fromDrift(row)).toList();
    } catch (e) {
      throw VocabularyException('Failed to get vocabulary for book: $e');
    }
  }
  
  /// Get items due for review
  Future<List<VocabularyItemModel>> getItemsDueForReview({int limit = 20}) async {
    try {
      final now = DateTime.now();
      final query = _database.select(_database.vocabularyItems)
        ..where((v) => v.nextReview.isSmallerOrEqualValue(now))
        ..orderBy([
          (v) => OrderingTerm(expression: v.nextReview),
        ])
        ..limit(limit);
      
      final results = await query.get();
      return results.map((row) => VocabularyItemModel.fromDrift(row)).toList();
    } catch (e) {
      throw VocabularyException('Failed to get items due for review: $e');
    }
  }
  
  /// Record a review and update SRS data
  Future<void> recordReview({
    required int vocabularyId,
    required bool correct,
    required int difficulty, // 0-5 scale
  }) async {
    try {
      await _database.transaction(() async {
        // Get current item
        final item = await (_database.select(_database.vocabularyItems)
          ..where((v) => v.id.equals(vocabularyId))).getSingle();
        
        // Calculate new SRS values using SM-2 algorithm
        final srsData = _calculateSRS(
          repetitions: item.reviewCount,
          easiness: item.difficulty,
          correct: correct,
          quality: difficulty,
        );
        
        // Update vocabulary item
        await (_database.update(_database.vocabularyItems)
          ..where((v) => v.id.equals(vocabularyId))).write(
          VocabularyItemsCompanion(
            reviewCount: Value(item.reviewCount + 1),
            difficulty: Value(srsData.easiness),
            nextReview: Value(srsData.nextReview),
            lastReviewed: Value(DateTime.now()),
          ),
        );
      });
    } catch (e) {
      throw VocabularyException('Failed to record review: $e');
    }
  }
  
  /// Search vocabulary items
  Future<List<VocabularyItemModel>> searchVocabulary({
    required String query,
    int? bookId,
    int limit = 50,
  }) async {
    try {
      var selectQuery = _database.select(_database.vocabularyItems);
      
      // Add book filter if specified
      if (bookId != null) {
        selectQuery = selectQuery..where((v) => v.bookId.equals(bookId));
      }
      
      // Add text search
      selectQuery = selectQuery
        ..where((v) => 
          v.sourceText.like('%$query%') | 
          v.translation.like('%$query%') |
          v.context.like('%$query%'))
        ..orderBy([
          (v) => OrderingTerm(expression: v.createdAt, mode: OrderingMode.desc),
        ])
        ..limit(limit);
      
      final results = await selectQuery.get();
      return results.map((row) => VocabularyItemModel.fromDrift(row)).toList();
    } catch (e) {
      throw VocabularyException('Failed to search vocabulary: $e');
    }
  }
  
  /// Get vocabulary statistics
  Future<VocabularyStats> getStats() async {
    try {
      final totalQuery = await _database.customSelect('''
        SELECT COUNT(*) as total FROM vocabulary_items
      ''').getSingle();
      
      final reviewsDueQuery = await _database.customSelect('''
        SELECT COUNT(*) as due FROM vocabulary_items 
        WHERE next_review <= ?
      ''', variables: [Variable(DateTime.now())]).getSingle();
      
      final masteredQuery = await _database.customSelect('''
        SELECT COUNT(*) as mastered FROM vocabulary_items 
        WHERE review_count >= 5 AND difficulty > 2.8
      ''').getSingle();
      
      final favoriteQuery = await _database.customSelect('''
        SELECT COUNT(*) as favorites FROM vocabulary_items 
        WHERE is_favorite = 1
      ''').getSingle();
      
      return VocabularyStats(
        totalItems: totalQuery.data['total'] as int,
        itemsDue: reviewsDueQuery.data['due'] as int,
        masteredItems: masteredQuery.data['mastered'] as int,
        favoriteItems: favoriteQuery.data['favorites'] as int,
      );
    } catch (e) {
      throw VocabularyException('Failed to get vocabulary stats: $e');
    }
  }
  
  /// Toggle favorite status
  Future<void> toggleFavorite(int vocabularyId) async {
    try {
      final item = await (_database.select(_database.vocabularyItems)
        ..where((v) => v.id.equals(vocabularyId))).getSingle();
      
      await (_database.update(_database.vocabularyItems)
        ..where((v) => v.id.equals(vocabularyId))).write(
        VocabularyItemsCompanion(
          isFavorite: Value(!item.isFavorite),
        ),
      );
    } catch (e) {
      throw VocabularyException('Failed to toggle favorite: $e');
    }
  }
  
  /// Delete vocabulary item
  Future<bool> deleteVocabularyItem(int vocabularyId) async {
    try {
      final deletedRows = await (_database.delete(_database.vocabularyItems)
        ..where((v) => v.id.equals(vocabularyId))).go();
      
      return deletedRows > 0;
    } catch (e) {
      throw VocabularyException('Failed to delete vocabulary item: $e');
    }
  }
  
  /// Get learning progress for a specific time period
  Future<List<VocabularyProgress>> getProgress({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final results = await _database.customSelect('''
        SELECT 
          DATE(created_at) as date,
          COUNT(*) as items_added,
          SUM(CASE WHEN last_reviewed IS NOT NULL THEN 1 ELSE 0 END) as items_reviewed
        FROM vocabulary_items 
        WHERE created_at BETWEEN ? AND ?
        GROUP BY DATE(created_at)
        ORDER BY date
      ''', variables: [
        Variable(startDate),
        Variable(endDate),
      ]).get();
      
      return results.map((row) => VocabularyProgress(
        date: DateTime.parse(row.data['date'] as String),
        itemsAdded: row.data['items_added'] as int,
        itemsReviewed: row.data['items_reviewed'] as int,
      )).toList();
    } catch (e) {
      throw VocabularyException('Failed to get progress: $e');
    }
  }
  
  // Private helper method for SRS calculation (SM-2 algorithm)
  SRSData _calculateSRS({
    required int repetitions,
    required double easiness,
    required bool correct,
    required int quality, // 0-5 scale
  }) {
    double newEasiness = easiness;
    int newRepetitions = repetitions;
    DateTime nextReview;
    
    if (correct && quality >= 3) {
      // Correct response
      newRepetitions += 1;
      newEasiness = easiness + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      
      if (newEasiness < 1.3) newEasiness = 1.3;
      
      if (newRepetitions == 1) {
        nextReview = DateTime.now().add(const Duration(days: 1));
      } else if (newRepetitions == 2) {
        nextReview = DateTime.now().add(const Duration(days: 6));
      } else {
        final interval = (6 * newEasiness).round();
        nextReview = DateTime.now().add(Duration(days: interval));
      }
    } else {
      // Incorrect response
      newRepetitions = 0;
      nextReview = DateTime.now().add(const Duration(days: 1));
    }
    
    return SRSData(
      repetitions: newRepetitions,
      easiness: newEasiness,
      nextReview: nextReview,
    );
  }
}

// Data classes
class VocabularyStats {
  final int totalItems;
  final int itemsDue;
  final int masteredItems;
  final int favoriteItems;
  
  const VocabularyStats({
    required this.totalItems,
    required this.itemsDue,
    required this.masteredItems,
    required this.favoriteItems,
  });
}

class VocabularyProgress {
  final DateTime date;
  final int itemsAdded;
  final int itemsReviewed;
  
  const VocabularyProgress({
    required this.date,
    required this.itemsAdded,
    required this.itemsReviewed,
  });
}

class SRSData {
  final int repetitions;
  final double easiness;
  final DateTime nextReview;
  
  const SRSData({
    required this.repetitions,
    required this.easiness,
    required this.nextReview,
  });
}

class VocabularyException implements Exception {
  final String message;
  const VocabularyException(this.message);
  
  @override
  String toString() => 'VocabularyException: $message';
}