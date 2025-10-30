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
      
      // First try exact match using Wiktionary format (forward direction)
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
      print('DriftDictionary: Forward direction (${sourceLanguage}->${targetLanguage}) found ${exactResults.length} results');
      
      // Log exact matches if found
      for (int i = 0; i < exactResults.length && i < 3; i++) {
        final result = exactResults[i];
        print('DriftDictionary: Forward match ${i + 1}: word="${result.writtenRep}" trans="${result.transList}" (${result.sourceLanguage}->${result.targetLanguage})');
      }
      
      if (exactResults.isNotEmpty) {
        stopwatch.stop();
        return exactResults.map((row) => _convertToModelEntry(row)).toList();
      }
      
      // If no forward match found, try reverse direction for bidirectional support
      print('DriftDictionary: No forward match found, trying reverse direction (${targetLanguage} -> ${sourceLanguage})');
      
      final reverseQuery = _database.select(_database.dictionaryEntries)
        ..where((e) => 
          e.writtenRep.equals(word.toLowerCase()) & 
          e.sourceLanguage.equals(targetLanguage) &
          e.targetLanguage.equals(sourceLanguage)
        )
        ..orderBy([
          (e) => OrderingTerm(expression: e.frequency, mode: OrderingMode.desc),
        ])
        ..limit(limit);
      
      final reverseResults = await reverseQuery.get();
      print('DriftDictionary: Reverse direction (${targetLanguage}->${sourceLanguage}) found ${reverseResults.length} results');
      
      // Log reverse matches if found
      for (int i = 0; i < reverseResults.length && i < 3; i++) {
        final result = reverseResults[i];
        print('DriftDictionary: Reverse match ${i + 1}: word="${result.writtenRep}" trans="${result.transList}" (${result.sourceLanguage}->${result.targetLanguage})');
      }
      
      if (reverseResults.isNotEmpty) {
        stopwatch.stop();
        // Reverse results are actually in the correct direction already
        return reverseResults.map((row) => _convertToModelEntry(row)).toList();
      }
      
      // Quick debug: Show first few entries and language pairs
      print('DriftDictionary: DEBUG - Word "${word.toLowerCase()}" not found. Quick database check...');
      
      // Check language pairs quickly
      final pairs = await _database.customSelect('''
        SELECT source_language, target_language, COUNT(*) as count 
        FROM dictionary_entries 
        GROUP BY source_language, target_language
        ORDER BY count DESC LIMIT 5
      ''').get();
      
      print('DriftDictionary: Language pairs in database:');
      for (final row in pairs) {
        print('  ${row.data['source_language']}->${row.data['target_language']}: ${row.data['count']} entries');
      }
      
      // Show first few entries that should contain the word we're looking for
      final samples = await (_database.select(_database.dictionaryEntries)
        ..where((e) => e.sourceLanguage.equals('en') & e.targetLanguage.equals('es'))
        ..limit(10)).get();
      print('DriftDictionary: First 10 en->es entries:');
      for (int i = 0; i < samples.length; i++) {
        final entry = samples[i];
        print('  ${i+1}. "${entry.writtenRep}" -> "${entry.transList}"');
      }
      
      // Try to find entries that start with the same letter as the word we're looking for
      final similarStart = await (_database.select(_database.dictionaryEntries)
        ..where((e) => e.writtenRep.like('${word.toLowerCase()[0]}%') & 
                       e.sourceLanguage.equals('en') & 
                       e.targetLanguage.equals('es'))
        ..limit(5)).get();
      print('DriftDictionary: Entries starting with "${word.toLowerCase()[0]}":');
      for (int i = 0; i < similarStart.length; i++) {
        final entry = similarStart[i];
        print('  ${i+1}. "${entry.writtenRep}" -> "${entry.transList}"');
      }
      
      // No exact match found - return empty to fall back to ML Kit
      print('DriftDictionary: No exact match found for "$word", returning empty (will fall back to ML Kit)');
      stopwatch.stop();
      return [];
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
      final companion = DictionaryEntriesCompanion.insert(
        writtenRep: entry.writtenRep, // Use modern Wiktionary writtenRep field
        sense: Value(entry.sense), // Use modern Wiktionary sense field
        transList: entry.transList, // Use modern Wiktionary trans_list field
        pos: Value(entry.pos), // Use modern Wiktionary pos field
        sourceLanguage: entry.sourceLanguage,
        targetLanguage: entry.targetLanguage,
        frequency: const Value(1000), // Default frequency
        pronunciation: Value(entry.pronunciation),
        examples: Value(entry.examples),
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
        writtenRep: starDictEntry.word,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        sense: starDictEntry.definition,
        transList: starDictEntry.definition, // For StarDict, definition serves as translation
        pos: starDictEntry.partOfSpeech,
        pronunciation: starDictEntry.pronunciation,
        examples: starDictEntry.exampleSentence,
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
      final testWords = ['for', 'hello', 'autobiography', 'located', 'under', 'states', 'the', 'and', 'a'];
      for (final word in testWords) {
        final results = await (_database.select(_database.dictionaryEntries)
          ..where((e) => e.writtenRep.equals(word.toLowerCase()) & 
                         e.sourceLanguage.equals('en') & 
                         e.targetLanguage.equals('es'))).get();
        print('DriftDictionary Debug: Word "$word" (en->es) found ${results.length} times');
        if (results.isNotEmpty) {
          print('  First match: "${results.first.writtenRep}" -> "${results.first.transList}"');
        }
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
  
  /// Debug method to check if common words exist
  Future<void> debugCommonWords() async {
    try {
      print('DriftDictionary Debug: Checking common English words in en->es dictionary...');
      
      final commonWords = ['the', 'and', 'a', 'to', 'of', 'in', 'that', 'have', 'I', 'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at', 'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she', 'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what', 'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me'];
      
      int foundCount = 0;
      for (final word in commonWords) {
        final results = await (_database.select(_database.dictionaryEntries)
          ..where((e) => e.writtenRep.equals(word.toLowerCase()) & 
                         e.sourceLanguage.equals('en') & 
                         e.targetLanguage.equals('es'))
          ..limit(1)).get();
        
        if (results.isNotEmpty) {
          foundCount++;
          print('  ✓ "$word" -> "${results.first.transList}"');
        } else {
          print('  ✗ "$word" not found');
        }
      }
      
      print('DriftDictionary Debug: Found $foundCount/${commonWords.length} common words');
      
    } catch (e) {
      print('DriftDictionary Debug: Error checking common words: $e');
    }
  }
  
  /// Comprehensive dictionary exploration
  Future<void> exploreDictionary() async {
    try {
      print('\n🔍 DICTIONARY EXPLORATION REPORT 🔍');
      print('=' * 50);
      
      // 1. Basic stats
      final totalCount = await (_database.selectOnly(_database.dictionaryEntries)
          ..addColumns([_database.dictionaryEntries.id.count()]))
          .getSingle();
      final total = totalCount.read(_database.dictionaryEntries.id.count()) ?? 0;
      print('📊 Total entries: $total');
      
      // 2. Language pairs
      final languagePairs = await _database.customSelect('''
        SELECT source_language, target_language, COUNT(*) as count 
        FROM dictionary_entries 
        GROUP BY source_language, target_language
        ORDER BY count DESC
      ''').get();
      
      print('\n🌍 Language pairs:');
      for (final row in languagePairs) {
        print('  ${row.data['source_language']}->${row.data['target_language']}: ${row.data['count']} entries');
      }
      
      // 3. Sample entries by length (to see data quality)
      print('\n📝 Sample entries by word length:');
      for (int len = 1; len <= 10; len++) {
        final samples = await (_database.select(_database.dictionaryEntries)
          ..where((e) => e.writtenRep.length.equals(len) & 
                         e.sourceLanguage.equals('en') & 
                         e.targetLanguage.equals('es'))
          ..limit(3)).get();
        
        if (samples.isNotEmpty) {
          print('  Length $len: ${samples.map((e) => '"${e.writtenRep}"').join(', ')}');
        }
      }
      
      // 4. Check for HTML contamination
      final htmlEntries = await (_database.select(_database.dictionaryEntries)
        ..where((e) => e.writtenRep.like('%<%') | e.writtenRep.like('%>%'))
        ..limit(10)).get();
      
      print('\n🚨 HTML contamination check:');
      print('  Entries with HTML tags: ${htmlEntries.length}');
      for (int i = 0; i < htmlEntries.length && i < 5; i++) {
        print('    "${htmlEntries[i].writtenRep}" -> "${htmlEntries[i].transList}"');
      }
      
      // 5. Shortest and longest entries
      final shortest = await (_database.select(_database.dictionaryEntries)
        ..where((e) => e.sourceLanguage.equals('en') & e.targetLanguage.equals('es'))
        ..orderBy([(e) => OrderingTerm(expression: e.writtenRep.length)])
        ..limit(5)).get();
      
      final longest = await (_database.select(_database.dictionaryEntries)
        ..where((e) => e.sourceLanguage.equals('en') & e.targetLanguage.equals('es'))
        ..orderBy([(e) => OrderingTerm(expression: e.writtenRep.length, mode: OrderingMode.desc)])
        ..limit(5)).get();
      
      print('\n📏 Entry length analysis:');
      print('  Shortest entries:');
      for (final entry in shortest) {
        print('    "${entry.writtenRep}" (${entry.writtenRep.length} chars) -> "${entry.transList}"');
      }
      print('  Longest entries:');
      for (final entry in longest) {
        print('    "${entry.writtenRep}" (${entry.writtenRep.length} chars) -> "${entry.transList.length > 50 ? entry.transList.substring(0, 50) + '...' : entry.transList}"');
      }
      
      // 6. Random sample to see overall quality
      final randomSample = await _database.customSelect('''
        SELECT * FROM dictionary_entries 
        WHERE source_language = 'en' AND target_language = 'es'
        ORDER BY RANDOM() 
        LIMIT 10
      ''').get();
      
      print('\n🎲 Random sample (10 entries):');
      for (final row in randomSample) {
        final word = row.data['written_rep'] as String;
        final trans = row.data['trans_list'] as String;
        print('    "$word" -> "$trans"');
      }
      
      // 7. Check specific words you might expect
      final expectedWords = ['house', 'water', 'food', 'good', 'bad', 'big', 'small', 'red', 'blue', 'green', 'book', 'table', 'chair', 'door', 'window'];
      print('\n🏠 Basic vocabulary check:');
      int basicFound = 0;
      for (final word in expectedWords) {
        final results = await (_database.select(_database.dictionaryEntries)
          ..where((e) => e.writtenRep.equals(word.toLowerCase()) & 
                         e.sourceLanguage.equals('en') & 
                         e.targetLanguage.equals('es'))
          ..limit(1)).get();
        
        if (results.isNotEmpty) {
          basicFound++;
          print('    ✓ "$word" -> "${results.first.transList}"');
        } else {
          print('    ✗ "$word" not found');
        }
      }
      print('  Found $basicFound/${expectedWords.length} basic words');
      
      print('\n' + '=' * 50);
      print('🎯 CONCLUSION:');
      if (basicFound < expectedWords.length / 2) {
        print('  📚 This appears to be a SPECIALIZED dictionary (Wiktionary-style)');
        print('  💡 Recommended: Use ML Kit for common words, dictionary for rare/technical terms');
      } else {
        print('  📖 This appears to be a GENERAL-PURPOSE dictionary');
        print('  💡 Investigate why common words are not being found');
      }
      
    } catch (e) {
      print('DriftDictionary Debug: Error exploring dictionary: $e');
    }
  }
  
  // Private helper methods
  
  /// Check if a dictionary match is relevant for the searched word
  bool _isRelevantMatch(String searchWord, String foundWord) {
    final cleanFoundWord = foundWord.toLowerCase().trim();
    
    print('DriftDictionary: _isRelevantMatch checking "$searchWord" vs "$cleanFoundWord"');
    
    // Exact match is always relevant
    if (cleanFoundWord == searchWord) {
      print('DriftDictionary: Exact match found');
      return true;
    }
    
    // If the found word starts with the search word, it's probably relevant
    if (cleanFoundWord.startsWith(searchWord)) {
      print('DriftDictionary: Prefix match found');
      return true;
    }
    
    // If the search word is very short (1-2 chars), be more strict
    if (searchWord.length <= 2) {
      print('DriftDictionary: Short search word, requiring exact match');
      return cleanFoundWord == searchWord;
    }
    
    // For proper nouns like "States", be more lenient with certain patterns
    if (searchWord.length >= 4) {
      // Check if it's a word boundary match (after space, dash, or start)
      final pattern = RegExp(r'(^|\s|-)' + RegExp.escape(searchWord) + r'(\s|-|$)');
      if (pattern.hasMatch(cleanFoundWord)) {
        print('DriftDictionary: Word boundary match found');
        return true;
      }
    }
    
    // For longer words, check if it's a reasonable substring match
    // Avoid matches where the search word is buried deep in a complex term
    final searchIndex = cleanFoundWord.indexOf(searchWord);
    if (searchIndex == -1) {
      print('DriftDictionary: No substring match');
      return false;
    }
    
    // If the match is at the beginning or after a space/dash, it's probably relevant
    if (searchIndex == 0) {
      print('DriftDictionary: Match at beginning');
      return true;
    }
    if (searchIndex > 0 && (cleanFoundWord[searchIndex - 1] == ' ' || cleanFoundWord[searchIndex - 1] == '-')) {
      print('DriftDictionary: Match after word boundary');
      return true;
    }
    
    // If the found word is much longer than the search word, it's probably not relevant
    if (cleanFoundWord.length > searchWord.length * 3) {
      print('DriftDictionary: Found word too long (${cleanFoundWord.length} vs ${searchWord.length})');
      return false;
    }
    
    // If it's a place name match (like "States" in "United States"), might be relevant
    if (searchWord == "states" && cleanFoundWord.contains("united states")) {
      print('DriftDictionary: Geographic name match');
      return true;
    }
    
    print('DriftDictionary: No relevant match found');
    return false;
  }
  
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
      writtenRep: row.writtenRep, // Use modern Wiktionary writtenRep field
      sourceLanguage: row.sourceLanguage,
      targetLanguage: row.targetLanguage,
      sense: row.sense,
      transList: row.transList ?? primaryTranslation, // Use modern transList field
      pos: row.pos, // Use modern pos field
      pronunciation: row.pronunciation,
      examples: row.examples,
      sourceDictionary: row.source ?? 'Unknown',
      createdAt: row.createdAt,
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
      writtenRep: data['written_rep'] as String, // Use modern Wiktionary writtenRep field
      sourceLanguage: data['source_language'] as String,
      targetLanguage: data['target_language'] as String,
      sense: data['sense'] as String?,
      transList: data['trans_list'] as String, // Use modern transList field
      pos: data['pos'] as String?, // Use modern pos field
      pronunciation: data['pronunciation'] as String?,
      examples: data['examples'] as String?,
      sourceDictionary: data['source'] as String? ?? 'Unknown',
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
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