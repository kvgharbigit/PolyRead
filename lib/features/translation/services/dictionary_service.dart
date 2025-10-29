// Dictionary Service - SQLite-based word lookup with FTS support
// Optimized for Vuizur Wiktionary-based language packs

import 'package:sqflite/sqflite.dart';
import '../models/dictionary_entry.dart';

class DictionaryService {
  static const String _tableName = 'dictionary_entries';
  static const String _ftsTableName = 'dictionary_entries_fts';
  
  final Database _database;
  
  DictionaryService(this._database);
  
  /// Initialize dictionary tables with FTS support
  Future<void> initialize() async {
    // Create main dictionary table
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        language TEXT NOT NULL,
        definition TEXT NOT NULL,
        pronunciation TEXT,
        part_of_speech TEXT,
        example_sentence TEXT,
        source_dictionary TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(word, language, source_dictionary)
      )
    ''');
    
    // Create FTS virtual table for fast text search
    await _database.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $_ftsTableName USING fts5(
        word,
        definition,
        example_sentence,
        content='$_tableName',
        content_rowid='id'
      )
    ''');
    
    // Create triggers to keep FTS table in sync
    await _database.execute('''
      CREATE TRIGGER IF NOT EXISTS dictionary_ai AFTER INSERT ON $_tableName BEGIN
        INSERT INTO $_ftsTableName(rowid, word, definition, example_sentence) 
        VALUES (new.id, new.word, new.definition, new.example_sentence);
      END
    ''');
    
    await _database.execute('''
      CREATE TRIGGER IF NOT EXISTS dictionary_ad AFTER DELETE ON $_tableName BEGIN
        INSERT INTO $_ftsTableName($_ftsTableName, rowid, word, definition, example_sentence) 
        VALUES('delete', old.id, old.word, old.definition, old.example_sentence);
      END
    ''');
    
    await _database.execute('''
      CREATE TRIGGER IF NOT EXISTS dictionary_au AFTER UPDATE ON $_tableName BEGIN
        INSERT INTO $_ftsTableName($_ftsTableName, rowid, word, definition, example_sentence) 
        VALUES('delete', old.id, old.word, old.definition, old.example_sentence);
        INSERT INTO $_ftsTableName(rowid, word, definition, example_sentence) 
        VALUES (new.id, new.word, new.definition, new.example_sentence);
      END
    ''');
    
    // Create indexes for performance
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_dictionary_word_lang 
      ON $_tableName(word, language)
    ''');
    
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_dictionary_language 
      ON $_tableName(language)
    ''');
  }
  
  /// Look up a word in the dictionary (supports bidirectional Wiktionary lookups)
  Future<List<DictionaryEntry>> lookupWord({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
    int limit = 10,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // For bidirectional Wiktionary dictionaries, we need to check both:
      // 1. Direct lookup (word in source language)
      // 2. Reverse lookup (word appears in definitions for target language)
      
      // First try exact word match in the source language context
      final exactResults = await _database.query(
        _tableName,
        where: 'word = ? AND (language = ? OR language = ?)',
        whereArgs: [word.toLowerCase(), sourceLanguage, '$sourceLanguage-$targetLanguage'],
        orderBy: 'source_dictionary ASC',
        limit: limit,
      );
      
      if (exactResults.isNotEmpty) {
        stopwatch.stop();
        return exactResults.map((row) => DictionaryEntry.fromMap(row)).toList();
      }
      
      // If no exact match, try FTS search across both directions
      final ftsResults = await _database.rawQuery('''
        SELECT d.* FROM $_tableName d
        JOIN $_ftsTableName fts ON d.id = fts.rowid
        WHERE $_ftsTableName MATCH ? 
        AND (d.language = ? OR d.language = ? OR d.language = ?)
        ORDER BY bm25($_ftsTableName) ASC
        LIMIT ?
      ''', [
        word.toLowerCase(), 
        sourceLanguage, 
        targetLanguage,
        '$sourceLanguage-$targetLanguage',
        limit
      ]);
      
      stopwatch.stop();
      return ftsResults.map((row) => DictionaryEntry.fromMap(row)).toList();
    } catch (e) {
      stopwatch.stop();
      throw DictionaryException('Dictionary lookup failed: $e');
    }
  }
  
  /// Search dictionary entries with full-text search (supports bidirectional Wiktionary)
  Future<List<DictionaryEntry>> searchEntries({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
    int limit = 20,
  }) async {
    try {
      // Search across bidirectional Wiktionary dictionaries
      final results = await _database.rawQuery('''
        SELECT d.* FROM $_tableName d
        JOIN $_ftsTableName fts ON d.id = fts.rowid
        WHERE $_ftsTableName MATCH ? 
        AND (d.language = ? OR d.language = ? OR d.language = ?)
        ORDER BY bm25($_ftsTableName) ASC
        LIMIT ?
      ''', [
        query.toLowerCase(), 
        sourceLanguage, 
        targetLanguage,
        '$sourceLanguage-$targetLanguage',
        limit
      ]);
      
      return results.map((row) => DictionaryEntry.fromMap(row)).toList();
    } catch (e) {
      throw DictionaryException('Dictionary search failed: $e');
    }
  }
  
  /// Add a single dictionary entry
  Future<int> addEntry(DictionaryEntry entry) async {
    try {
      return await _database.insert(
        _tableName,
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw DictionaryException('Failed to add dictionary entry: $e');
    }
  }
  
  /// Add multiple dictionary entries in a batch
  Future<void> addEntries(List<DictionaryEntry> entries, {
    Function(int processed, int total)? onProgress,
  }) async {
    
    for (int i = 0; i < entries.length; i++) {
      var batch = _database.batch();
      
      batch.insert(
        _tableName,
        entries[i].toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Process individually to avoid batch reassignment issues
      await batch.commit(noResult: true);
      
      if ((i + 1) % 100 == 0) {
        onProgress?.call(i + 1, entries.length);
      }
    }
  }
  
  /// Import StarDict format dictionary (handles bidirectional Wiktionary)
  Future<void> importStarDict({
    required String dictionaryName,
    required List<StarDictEntry> entries,
    required String sourceLanguage,
    required String targetLanguage,
    Function(int processed, int total)? onProgress,
  }) async {
    // For Wiktionary dictionaries, use compound language code to indicate bidirectional
    final languageCode = '$sourceLanguage-$targetLanguage';
    
    final dictionaryEntries = entries.map((starDictEntry) {
      return DictionaryEntry(
        word: starDictEntry.word,
        language: languageCode, // e.g., "fr-en" for French-English Wiktionary
        definition: starDictEntry.definition,
        pronunciation: starDictEntry.pronunciation,
        partOfSpeech: starDictEntry.partOfSpeech,
        exampleSentence: starDictEntry.exampleSentence,
        sourceDictionary: dictionaryName,
        createdAt: DateTime.now(),
      );
    }).toList();
    
    await addEntries(dictionaryEntries, onProgress: onProgress);
  }
  
  /// Get dictionary statistics
  Future<DictionaryStats> getStats() async {
    try {
      final countResult = await _database.rawQuery('''
        SELECT 
          language,
          source_dictionary,
          COUNT(*) as entry_count
        FROM $_tableName 
        GROUP BY language, source_dictionary
      ''');
      
      final totalResult = await _database.rawQuery('''
        SELECT COUNT(*) as total FROM $_tableName
      ''');
      
      final languageStats = <String, Map<String, int>>{};
      
      for (final row in countResult) {
        final language = row['language'] as String;
        final dictionary = row['source_dictionary'] as String;
        final count = row['entry_count'] as int;
        
        languageStats.putIfAbsent(language, () => {});
        languageStats[language]![dictionary] = count;
      }
      
      return DictionaryStats(
        totalEntries: totalResult.first['total'] as int,
        languageStats: languageStats,
      );
    } catch (e) {
      throw DictionaryException('Failed to get dictionary stats: $e');
    }
  }
  
  /// Clear all dictionary entries
  Future<void> clearAll() async {
    try {
      await _database.delete(_tableName);
    } catch (e) {
      throw DictionaryException('Failed to clear dictionary: $e');
    }
  }
  
  /// Clear entries for a specific dictionary
  Future<void> clearDictionary(String dictionaryName) async {
    try {
      await _database.delete(
        _tableName,
        where: 'source_dictionary = ?',
        whereArgs: [dictionaryName],
      );
    } catch (e) {
      throw DictionaryException('Failed to clear dictionary $dictionaryName: $e');
    }
  }
}

class StarDictEntry {
  final String word;
  final String definition;
  final String? pronunciation;
  final String? partOfSpeech;
  final String? exampleSentence;
  
  const StarDictEntry({
    required this.word,
    required this.definition,
    this.pronunciation,
    this.partOfSpeech,
    this.exampleSentence,
  });
}

class DictionaryStats {
  final int totalEntries;
  final Map<String, Map<String, int>> languageStats;
  
  const DictionaryStats({
    required this.totalEntries,
    required this.languageStats,
  });
  
  /// Get total entries for a language
  int getLanguageTotal(String language) {
    final stats = languageStats[language];
    if (stats == null) return 0;
    return stats.values.fold(0, (sum, count) => sum + count);
  }
  
  /// Get list of available languages
  List<String> get availableLanguages => languageStats.keys.toList();
  
  /// Get list of dictionaries for a language
  List<String> getDictionaries(String language) {
    return languageStats[language]?.keys.toList() ?? [];
  }
}

class DictionaryException implements Exception {
  final String message;
  const DictionaryException(this.message);
  
  @override
  String toString() => 'DictionaryException: $message';
}