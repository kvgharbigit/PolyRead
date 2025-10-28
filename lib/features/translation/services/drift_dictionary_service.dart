// Drift Dictionary Service - Direct Drift database integration
// Enhanced dictionary service that works directly with Drift AppDatabase

import 'package:drift/drift.dart';
import 'package:polyread/core/database/app_database.dart';
import '../models/dictionary_entry.dart' as model;

class DriftDictionaryService {
  final AppDatabase _database;
  
  DriftDictionaryService(this._database);
  
  /// Look up a word in the dictionary (supports bidirectional Wiktionary lookups)
  Future<List<model.DictionaryEntry>> lookupWord({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
    int limit = 10,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Create language pair patterns for bidirectional lookup
      final languagePairs = [
        '$sourceLanguage-$targetLanguage',
        '$targetLanguage-$sourceLanguage',
        sourceLanguage,
        targetLanguage,
      ];
      
      // First try exact match
      final exactQuery = _database.select(_database.dictionaryEntries)
        ..where((e) => 
          e.lemma.equals(word.toLowerCase()) & 
          e.languagePair.isIn(languagePairs)
        )
        ..orderBy([
          (e) => OrderingTerm(expression: e.frequency, mode: OrderingMode.desc),
        ])
        ..limit(limit);
      
      final exactResults = await exactQuery.get();
      
      if (exactResults.isNotEmpty) {
        stopwatch.stop();
        return exactResults.map((row) => _convertToModelEntry(row)).toList();
      }
      
      // If no exact match, try FTS search
      final ftsResults = await _database.customSelect('''
        SELECT de.* FROM dictionary_entries de
        JOIN dictionary_fts fts ON de.id = fts.rowid
        WHERE dictionary_fts MATCH ? AND de.language_pair IN (?, ?, ?, ?)
        ORDER BY bm25(dictionary_fts) ASC, de.frequency DESC
        LIMIT ?
      ''', variables: [
        Variable(word.toLowerCase()),
        Variable('$sourceLanguage-$targetLanguage'),
        Variable('$targetLanguage-$sourceLanguage'),
        Variable(sourceLanguage),
        Variable(targetLanguage),
        Variable(limit),
      ]).get();
      
      stopwatch.stop();
      return ftsResults.map((row) => _convertToModelEntryFromMap(row.data)).toList();
    } catch (e) {
      stopwatch.stop();
      throw DictionaryException('Dictionary lookup failed: $e');
    }
  }
  
  /// Search dictionary entries with full-text search (supports bidirectional Wiktionary)
  Future<List<model.DictionaryEntry>> searchEntries({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
    int limit = 20,
  }) async {
    try {
      final languagePairs = [
        '$sourceLanguage-$targetLanguage',
        '$targetLanguage-$sourceLanguage',
        sourceLanguage,
        targetLanguage,
      ];
      
      // Search across bidirectional Wiktionary dictionaries
      final results = await _database.customSelect('''
        SELECT de.* FROM dictionary_entries de
        JOIN dictionary_fts fts ON de.id = fts.rowid
        WHERE dictionary_fts MATCH ? AND de.language_pair IN (?, ?, ?, ?)
        ORDER BY bm25(dictionary_fts) ASC, de.frequency DESC
        LIMIT ?
      ''', variables: [
        Variable(query.toLowerCase()),
        Variable('$sourceLanguage-$targetLanguage'),
        Variable('$targetLanguage-$sourceLanguage'),
        Variable(sourceLanguage),
        Variable(targetLanguage),
        Variable(limit),
      ]).get();
      
      return results.map((row) => _convertToModelEntryFromMap(row.data)).toList();
    } catch (e) {
      throw DictionaryException('Dictionary search failed: $e');
    }
  }
  
  /// Add a single dictionary entry
  Future<int> addEntry(model.DictionaryEntry entry) async {
    try {
      final companion = DictionaryEntriesCompanion.insert(
        lemma: entry.word,
        definition: entry.definition,
        partOfSpeech: Value(entry.partOfSpeech),
        languagePair: entry.language ?? 'unknown',
        frequency: const Value(1000), // Default frequency
        pronunciation: Value(entry.pronunciation),
        examples: Value(entry.exampleSentence),
        synonyms: Value(null), // TODO: Add synonyms support
        source: Value(entry.sourceDictionary),
      );
      
      return await _database.into(_database.dictionaryEntries).insert(companion);
    } catch (e) {
      throw DictionaryException('Failed to add dictionary entry: $e');
    }
  }
  
  /// Add multiple dictionary entries in a batch
  Future<void> addEntries(List<model.DictionaryEntry> entries, {
    Function(int processed, int total)? onProgress,
  }) async {
    await _database.transaction(() async {
      for (int i = 0; i < entries.length; i++) {
        await addEntry(entries[i]);
        
        if ((i + 1) % 100 == 0) {
          onProgress?.call(i + 1, entries.length);
        }
      }
    });
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
      return model.DictionaryEntry(
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
      final countResults = await _database.customSelect('''
        SELECT 
          language_pair,
          source,
          COUNT(*) as entry_count
        FROM dictionary_entries 
        GROUP BY language_pair, source
      ''').get();
      
      final totalResult = await _database.customSelect('''
        SELECT COUNT(*) as total FROM dictionary_entries
      ''').get();
      
      final languageStats = <String, Map<String, int>>{};
      
      for (final row in countResults) {
        final language = row.data['language_pair'] as String;
        final dictionary = row.data['source'] as String? ?? 'unknown';
        final count = row.data['entry_count'] as int;
        
        languageStats.putIfAbsent(language, () => {});
        languageStats[language]![dictionary] = count;
      }
      
      final totalEntries = totalResult.isNotEmpty 
          ? totalResult.first.data['total'] as int 
          : 0;
      
      return DictionaryStats(
        totalEntries: totalEntries,
        languageStats: languageStats,
      );
    } catch (e) {
      throw DictionaryException('Failed to get dictionary stats: $e');
    }
  }
  
  /// Clear all dictionary entries
  Future<void> clearAll() async {
    try {
      await _database.delete(_database.dictionaryEntries).go();
    } catch (e) {
      throw DictionaryException('Failed to clear dictionary: $e');
    }
  }
  
  /// Clear entries for a specific dictionary
  Future<void> clearDictionary(String dictionaryName) async {
    try {
      await (_database.delete(_database.dictionaryEntries)
        ..where((e) => e.source.equals(dictionaryName))).go();
    } catch (e) {
      throw DictionaryException('Failed to clear dictionary $dictionaryName: $e');
    }
  }
  
  // Private helper methods
  
  model.DictionaryEntry _convertToModelEntry(DictionaryEntry row) {
    return model.DictionaryEntry(
      id: row.id,
      word: row.lemma,
      language: row.languagePair,
      definition: row.definition,
      pronunciation: row.pronunciation,
      partOfSpeech: row.partOfSpeech,
      exampleSentence: row.examples,
      sourceDictionary: row.source ?? 'Unknown',
      createdAt: DateTime.now(), // TODO: Add created_at field to schema
    );
  }
  
  model.DictionaryEntry _convertToModelEntryFromMap(Map<String, Object?> data) {
    return model.DictionaryEntry(
      id: data['id'] as int?,
      word: data['lemma'] as String,
      language: data['language_pair'] as String,
      definition: data['definition'] as String,
      pronunciation: data['pronunciation'] as String?,
      partOfSpeech: data['part_of_speech'] as String?,
      exampleSentence: data['examples'] as String?,
      sourceDictionary: data['source'] as String? ?? 'Unknown',
      createdAt: DateTime.now(),
    );
  }
}

// Re-export the shared classes from the original dictionary service
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