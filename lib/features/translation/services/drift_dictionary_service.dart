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
      // First check if database has any entries at all
      final totalCount = await (_database.selectOnly(_database.dictionaryEntries)
          ..addColumns([_database.dictionaryEntries.id.count()]))
          .getSingle();
      final totalEntries = totalCount.read(_database.dictionaryEntries.id.count()) ?? 0;
      
      print('DriftDictionary: Total entries in database: $totalEntries');
      
      if (totalEntries == 0) {
        print('DriftDictionary: Database is empty! Dictionary needs to be loaded.');
        stopwatch.stop();
        return [];
      }
      
      // First try exact match using Wiktionary format
      print('DriftDictionary: Looking for exact match of "${word.toLowerCase()}" (${sourceLanguage} -> ${targetLanguage})');
      
      final exactQuery = _database.select(_database.dictionaryEntries)
        ..where((e) => 
          e.writtenRep.equals(word.toLowerCase()) & 
          e.sourceLanguage.equals(sourceLanguage) &
          e.targetLanguage.equals(targetLanguage)
        )
        ..orderBy([
          (e) => OrderingTerm(expression: e.frequency, mode: OrderingMode.desc),
        ])
        ..limit(limit);
      
      final exactResults = await exactQuery.get();
      print('DriftDictionary: Exact match found ${exactResults.length} results');
      
      if (exactResults.isNotEmpty) {
        stopwatch.stop();
        return exactResults.map((row) => _convertToModelEntry(row)).toList();
      }
      
      // If no exact match, try FTS search using Wiktionary format
      try {
        final ftsResults = await _database.customSelect('''
          SELECT de.* FROM dictionary_entries de
          JOIN dictionary_fts fts ON de.id = fts.rowid
          WHERE dictionary_fts MATCH ? 
            AND de.source_language = ? 
            AND de.target_language = ?
          ORDER BY bm25(dictionary_fts) ASC, de.frequency DESC
          LIMIT ?
        ''', variables: [
          Variable(word.toLowerCase()),
          Variable(sourceLanguage),
          Variable(targetLanguage),
          Variable(limit),
        ]).get();
        
        print('DriftDictionary: FTS search found ${ftsResults.length} results');
        stopwatch.stop();
        return ftsResults.map((row) => _convertToModelEntryFromMap(row.data)).toList();
      } catch (ftsError) {
        print('DriftDictionary: FTS search failed: $ftsError, falling back to basic search');
        
        // Fallback: try basic LIKE search using Wiktionary format
        final likeQuery = _database.select(_database.dictionaryEntries)
          ..where((e) => 
            e.writtenRep.like('%${word.toLowerCase()}%') & 
            e.sourceLanguage.equals(sourceLanguage) &
            e.targetLanguage.equals(targetLanguage)
          )
          ..orderBy([
            (e) => OrderingTerm(expression: e.frequency, mode: OrderingMode.desc),
          ])
          ..limit(limit);
        
        final likeResults = await likeQuery.get();
        print('DriftDictionary: LIKE search found ${likeResults.length} results');
        
        stopwatch.stop();
        return likeResults.map((row) => _convertToModelEntry(row)).toList();
      }
    } catch (e) {
      stopwatch.stop();
      print('DriftDictionary: Lookup failed with error: $e');
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
      // Parse language pair (e.g., "en-es" -> source: "en", target: "es")
      final languageParts = (entry.language ?? 'unknown-unknown').split('-');
      final sourceLanguage = languageParts.isNotEmpty ? languageParts[0] : 'unknown';
      final targetLanguage = languageParts.length > 1 ? languageParts[1] : 'unknown';
      
      final companion = DictionaryEntriesCompanion.insert(
        writtenRep: entry.word, // Use Wiktionary writtenRep field
        sense: Value(entry.definition), // Use Wiktionary sense field
        transList: entry.definition, // For now, use definition as translation (TODO: support pipe-separated)
        pos: Value(entry.partOfSpeech), // Use Wiktionary pos field
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        frequency: const Value(1000), // Default frequency
        pronunciation: Value(entry.pronunciation),
        examples: Value(entry.exampleSentence),
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
          source_language || '-' || target_language as language_pair,
          source,
          COUNT(*) as entry_count
        FROM dictionary_entries 
        GROUP BY source_language, target_language, source
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
  
  /// Debug method to check database state
  Future<void> debugDatabaseState() async {
    try {
      // Get total count
      final allEntries = await _database.select(_database.dictionaryEntries).get();
      print('DriftDictionary Debug: Total entries: ${allEntries.length}');
      
      if (allEntries.isNotEmpty) {
        print('DriftDictionary Debug: First 5 entries:');
        for (int i = 0; i < allEntries.length && i < 5; i++) {
          final entry = allEntries[i];
          print('  ${i + 1}. "${entry.writtenRep}" (${entry.sourceLanguage}-${entry.targetLanguage}) -> "${entry.sense ?? entry.transList}"');
        }
      }
      
      // Check specific test words
      final testWords = ['for', 'hello', 'autobiography'];
      for (final word in testWords) {
        final results = await (_database.select(_database.dictionaryEntries)
          ..where((e) => e.writtenRep.equals(word.toLowerCase()))).get();
        print('DriftDictionary Debug: Word "$word" found ${results.length} times');
      }
      
      // Check language pairs (using Wiktionary format)
      final languagePairsResult = await _database.customSelect('''
        SELECT source_language, target_language, COUNT(*) as count 
        FROM dictionary_entries 
        GROUP BY source_language, target_language
      ''').get();
      
      print('DriftDictionary Debug: Language pairs:');
      for (final row in languagePairsResult) {
        final sourceLang = row.data['source_language'];
        final targetLang = row.data['target_language'];
        final count = row.data['count'];
        print('  $sourceLang->$targetLang: $count entries');
      }
      
    } catch (e) {
      print('DriftDictionary Debug: Error checking database state: $e');
    }
  }
  
  // Private helper methods
  
  model.DictionaryEntry _convertToModelEntry(DictionaryEntry row) {
    // Parse pipe-separated translations from WikiDict format
    final translations = row.transList.split(' | ')
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim())
        .toList();
    
    // Primary translation is the first one, rest become synonyms
    final primaryTranslation = translations.isNotEmpty ? translations.first : row.sense ?? '';
    final synonyms = translations.length > 1 ? translations.skip(1).toList() : <String>[];
    
    return model.DictionaryEntry(
      id: row.id,
      word: row.writtenRep, // Use Wiktionary writtenRep field
      language: '${row.sourceLanguage}-${row.targetLanguage}', // Construct language pair
      definition: primaryTranslation, // Primary translation from transList
      pronunciation: row.pronunciation,
      partOfSpeech: row.pos, // Use Wiktionary pos field
      exampleSentence: row.examples,
      sourceDictionary: row.source ?? 'Unknown',
      createdAt: row.createdAt,
      // Add synonyms from pipe-separated list
      synonyms: synonyms,
    );
  }
  
  model.DictionaryEntry _convertToModelEntryFromMap(Map<String, Object?> data) {
    // Parse pipe-separated translations from WikiDict format
    final transListRaw = data['trans_list'] as String? ?? '';
    final translations = transListRaw.split(' | ')
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim())
        .toList();
    
    // Primary translation is the first one, rest become synonyms
    final primaryTranslation = translations.isNotEmpty ? translations.first : data['sense'] as String? ?? '';
    final synonyms = translations.length > 1 ? translations.skip(1).toList() : <String>[];
    
    return model.DictionaryEntry(
      id: data['id'] as int?,
      word: data['written_rep'] as String, // Use Wiktionary writtenRep field
      language: '${data['source_language']}-${data['target_language']}', // Construct language pair
      definition: primaryTranslation, // Primary translation from transList
      pronunciation: data['pronunciation'] as String?,
      partOfSpeech: data['pos'] as String?, // Use Wiktionary pos field
      exampleSentence: data['examples'] as String?,
      sourceDictionary: data['source'] as String? ?? 'Unknown',
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      // Add synonyms from pipe-separated list
      synonyms: synonyms,
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