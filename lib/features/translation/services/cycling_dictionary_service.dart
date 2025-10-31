// Cycling Dictionary Service for one-level meaning cycling + expansion UI
// Supports both Source→Target and Target→Source with any language pair

import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../models/meaning_entry.dart';

class CyclingDictionaryService {
  final AppDatabase _database;
  Map<String, String>? _availableLanguagePairs; // Cache of available language pairs

  CyclingDictionaryService(this._database);

  /// Get available language pairs from the database (cached)
  Future<Map<String, String>> _getAvailableLanguagePairs() async {
    if (_availableLanguagePairs != null) {
      return _availableLanguagePairs!;
    }

    final query = '''
      SELECT DISTINCT source_language, target_language 
      FROM word_groups 
      ORDER BY source_language, target_language
    ''';
    
    final result = await _database.customSelect(query).get();
    
    _availableLanguagePairs = {};
    for (final row in result) {
      final source = row.read<String>('source_language');
      final target = row.read<String>('target_language');
      _availableLanguagePairs!['$source-$target'] = '$source-$target';
    }
    
    print('CyclingDictionary: Available language pairs: ${_availableLanguagePairs!.keys.toList()}');
    return _availableLanguagePairs!;
  }

  /// Determine how to use the available dictionary for the requested translation
  Future<({String dictSource, String dictTarget, bool useReverseLookup})> getDictionaryStrategy(
    String requestedSource,
    String requestedTarget,
  ) async {
    final availablePairs = await _getAvailableLanguagePairs();
    
    // Check if we have a direct dictionary (source → target)
    final directPair = '$requestedSource-$requestedTarget';
    if (availablePairs.containsKey(directPair)) {
      print('CyclingDictionary: Direct dictionary available: $directPair');
      return (dictSource: requestedSource, dictTarget: requestedTarget, useReverseLookup: false);
    }
    
    // Check if we have a reverse dictionary (target → source) that we can use backwards
    final reversePair = '$requestedTarget-$requestedSource';
    if (availablePairs.containsKey(reversePair)) {
      print('CyclingDictionary: Reverse dictionary available: $reversePair, will use reverse lookup');
      return (dictSource: requestedTarget, dictTarget: requestedSource, useReverseLookup: true);
    }
    
    // No matching dictionary found
    print('CyclingDictionary: No dictionary available for $requestedSource→$requestedTarget or $requestedTarget→$requestedSource');
    throw Exception('No dictionary available for language pair $requestedSource-$requestedTarget');
  }

  /// Look up meanings for source word
  /// Automatically determines correct dictionary direction and uses appropriate lookup method
  Future<MeaningLookupResult> lookupSourceMeanings(
    String sourceWord,
    String sourceLanguage, // Language of the word we want to translate FROM
    String targetLanguage, // Language we want to translate TO
  ) async {
    print('CyclingDictionary: Need to translate "$sourceWord" from $sourceLanguage to $targetLanguage');
    
    // Input validation
    if (sourceWord.trim().isEmpty) {
      return MeaningLookupResult(
        query: sourceWord,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        meanings: [],
        latencyMs: 0,
        fromCache: false,
      );
    }
    
    if (sourceLanguage.length < 2 || targetLanguage.length < 2) {
      throw ArgumentError('Language codes must be at least 2 characters');
    }
    
    final stopwatch = Stopwatch()..start();

    try {
      // Determine how to use available dictionaries
      final strategy = await getDictionaryStrategy(sourceLanguage, targetLanguage);
      
      if (strategy.useReverseLookup) {
        // Dictionary is backwards (target→source), use reverse lookup table
        print('CyclingDictionary: Using reverse lookup in ${strategy.dictSource}-${strategy.dictTarget} dictionary');
        return await _performReverseLookup(sourceWord, sourceLanguage, targetLanguage, strategy.dictSource, strategy.dictTarget, stopwatch);
      } else {
        // Dictionary is direct (source→target), use normal lookup
        print('CyclingDictionary: Using direct lookup in ${strategy.dictSource}-${strategy.dictTarget} dictionary');
        return await _performDirectLookup(sourceWord, sourceLanguage, targetLanguage, strategy.dictSource, strategy.dictTarget, stopwatch);
      }
    } catch (e) {
      print('CyclingDictionary: Lookup failed: $e');
      stopwatch.stop();
      return MeaningLookupResult(
        query: sourceWord,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        meanings: [],
        latencyMs: stopwatch.elapsedMilliseconds,
        fromCache: false,
      );
    }
  }

  /// Perform direct lookup (word is in the dictionary's source language)
  Future<MeaningLookupResult> _performDirectLookup(
    String word,
    String requestedSource,
    String requestedTarget,
    String dictSource,
    String dictTarget,
    Stopwatch stopwatch,
  ) async {
    final query = '''
      SELECT 
        wg.id as wg_id, wg.base_word, wg.word_forms, wg.part_of_speech as wg_pos,
        wg.source_language, wg.target_language, wg.created_at as wg_created_at,
        m.id as m_id, m.word_group_id, m.meaning_order, m.target_meaning,
        m.context, m.part_of_speech as m_pos, m.is_primary, m.created_at as m_created_at
      FROM word_groups wg
      JOIN meanings m ON m.word_group_id = wg.id
      WHERE wg.base_word = ? COLLATE NOCASE
        AND wg.source_language = ?
        AND wg.target_language = ?
      ORDER BY m.meaning_order
      LIMIT 10
    ''';

    print('CyclingDictionary: Direct lookup: "${word.toLowerCase()}" in $dictSource-$dictTarget');
    
    final result = await _database.customSelect(
      query,
      variables: [
        Variable<String>(word.toLowerCase()),
        Variable<String>(dictSource),
        Variable<String>(dictTarget),
      ],
    ).get();

    print('CyclingDictionary: Direct lookup returned ${result.length} rows');

    final meanings = <CyclableMeaning>[];
    
    for (int i = 0; i < result.length; i++) {
      final row = result[i];
      
      // Build MeaningWordGroup
      final wordGroup = MeaningWordGroup(
        id: row.read<int>('wg_id'),
        baseWord: row.read<String>('base_word'),
        wordForms: row.read<String>('word_forms'),
        partOfSpeech: row.readNullable<String>('wg_pos'),
        sourceLanguage: row.read<String>('source_language'),
        targetLanguage: row.read<String>('target_language'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('wg_created_at')),
      );
      
      // Build MeaningEntry
      final meaning = MeaningEntry(
        id: row.read<int>('m_id'),
        wordGroupId: row.read<int>('word_group_id'),
        meaningOrder: row.read<int>('meaning_order'),
        targetMeaning: row.read<String>('target_meaning'),
        context: row.readNullable<String>('context'),
        partOfSpeech: row.readNullable<String>('m_pos'),
        isPrimary: row.read<bool>('is_primary'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('m_created_at')),
      );
      
      meanings.add(CyclableMeaning(
        wordGroup: wordGroup,
        meaning: meaning,
        currentIndex: meanings.length + 1,
        totalMeanings: result.length,
      ));
    }
    
    stopwatch.stop();
    return MeaningLookupResult(
      query: word,
      sourceLanguage: requestedSource,
      targetLanguage: requestedTarget,
      meanings: meanings,
      latencyMs: stopwatch.elapsedMilliseconds,
      fromCache: false,
    );
  }

  /// Perform reverse lookup (word is in the dictionary's target language, lookup from reverse table)
  Future<MeaningLookupResult> _performReverseLookup(
    String word,
    String requestedSource,
    String requestedTarget,
    String dictSource,
    String dictTarget,
    Stopwatch stopwatch,
  ) async {
    final query = '''
      SELECT 
        trl.target_word, trl.lookup_order, trl.quality_score,
        wg.base_word as source_word, wg.word_forms, wg.part_of_speech as wg_pos,
        wg.source_language, wg.target_language, wg.created_at as wg_created_at,
        wg.id as wg_id,
        m.target_meaning, m.part_of_speech as m_pos, m.context,
        m.id as m_id, m.word_group_id, m.meaning_order, m.is_primary, m.created_at as m_created_at
      FROM target_reverse_lookup trl
      JOIN word_groups wg ON trl.source_word_group_id = wg.id
      JOIN meanings m ON trl.source_meaning_id = m.id
      WHERE trl.target_word = ? COLLATE NOCASE
        AND wg.source_language = ?
        AND wg.target_language = ?
      ORDER BY trl.lookup_order
      LIMIT 10
    ''';

    print('CyclingDictionary: Reverse lookup: "${word.toLowerCase()}" in $dictSource-$dictTarget reverse table');
    
    final result = await _database.customSelect(
      query,
      variables: [
        Variable<String>(word.toLowerCase()),
        Variable<String>(dictSource),
        Variable<String>(dictTarget),
      ],
    ).get();

    print('CyclingDictionary: Reverse lookup returned ${result.length} rows');

    final meanings = <CyclableMeaning>[];
    
    for (int i = 0; i < result.length; i++) {
      final row = result[i];
      
      // Build MeaningWordGroup (represents the source word in the dictionary)
      final wordGroup = MeaningWordGroup(
        id: row.read<int>('wg_id'),
        baseWord: row.read<String>('source_word'),
        wordForms: row.read<String>('word_forms'),
        partOfSpeech: row.readNullable<String>('wg_pos'),
        sourceLanguage: row.read<String>('source_language'),
        targetLanguage: row.read<String>('target_language'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('wg_created_at')),
      );
      
      // Build MeaningEntry (the translation we want to show)
      final meaning = MeaningEntry(
        id: row.read<int>('m_id'),
        wordGroupId: row.read<int>('word_group_id'),
        meaningOrder: row.read<int>('lookup_order'), // Use lookup order for cycling
        targetMeaning: row.read<String>('source_word'), // The source word becomes our "translation"
        context: row.readNullable<String>('context'), // Use actual context information
        partOfSpeech: row.readNullable<String>('m_pos'),
        isPrimary: row.read<int>('lookup_order') == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('m_created_at')),
      );
      
      meanings.add(CyclableMeaning(
        wordGroup: wordGroup,
        meaning: meaning,
        currentIndex: meanings.length + 1,
        totalMeanings: result.length,
      ));
    }
    
    stopwatch.stop();
    return MeaningLookupResult(
      query: word,
      sourceLanguage: requestedSource,
      targetLanguage: requestedTarget,
      meanings: meanings,
      latencyMs: stopwatch.elapsedMilliseconds,
      fromCache: false,
    );
  }

  /// Look up source words for target word (e.g., English → Spanish)
  /// Returns cyclable reverse translations in quality order
  Future<ReverseLookupResult> lookupTargetTranslations(
    String targetWord,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    print('CyclingDictionary: lookupTargetTranslations("$targetWord", "$sourceLanguage", "$targetLanguage")');
    
    // Input validation
    if (targetWord.trim().isEmpty) {
      print('CyclingDictionary: Empty target word, returning empty result');
      return ReverseLookupResult(
        query: targetWord,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        translations: [],
        latencyMs: 0,
        fromCache: false,
      );
    }
    
    if (sourceLanguage.length < 2 || targetLanguage.length < 2) {
      print('CyclingDictionary: Invalid language codes: "$sourceLanguage", "$targetLanguage"');
      throw ArgumentError('Language codes must be at least 2 characters');
    }
    final stopwatch = Stopwatch()..start();

    try {
      print('CyclingDictionary: Executing reverse lookup query with params: word="${targetWord.toLowerCase()}", source="$sourceLanguage", target="$targetLanguage"');
      
      final query = '''
        SELECT 
          trl.target_word, trl.lookup_order, trl.quality_score,
          wg.base_word as source_word,
          m.target_meaning, m.part_of_speech
        FROM target_reverse_lookup trl
        JOIN word_groups wg ON trl.source_word_group_id = wg.id
        JOIN meanings m ON trl.source_meaning_id = m.id
        WHERE trl.target_word = ? COLLATE NOCASE
          AND wg.source_language = ?
          AND wg.target_language = ?
        ORDER BY trl.lookup_order
        LIMIT 8
      ''';

      final result = await _database.customSelect(
        query,
        variables: [
          Variable<String>(targetWord.toLowerCase()),
          Variable<String>(sourceLanguage),
          Variable<String>(targetLanguage),
        ],
      ).get();

      print('CyclingDictionary: Reverse lookup query returned ${result.length} rows');

      final translations = <CyclableReverseLookup>[];
      
      for (int i = 0; i < result.length; i++) {
        final row = result[i];
        
        translations.add(CyclableReverseLookup(
          targetWord: row.read<String>('target_word'),
          sourceWord: row.read<String>('source_word'),
          sourceMeaning: row.read<String>('target_meaning'),
          partOfSpeech: row.readNullable<String>('part_of_speech'),
          qualityScore: row.read<int>('quality_score'),
          currentIndex: i + 1,
          totalTranslations: result.length,
        ));
      }

      return ReverseLookupResult(
        query: targetWord,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        translations: translations,
        latencyMs: stopwatch.elapsedMilliseconds,
        fromCache: false,
      );
    } finally {
      stopwatch.stop();
    }
  }

  /// Get specific meaning by cycling index for source word
  Future<CyclableMeaning?> getMeaningAtIndex(
    String sourceWord,
    String sourceLanguage,
    String targetLanguage,
    int meaningIndex,
  ) async {
    final result = await lookupSourceMeanings(sourceWord, sourceLanguage, targetLanguage);
    
    if (result.hasResults && meaningIndex > 0 && meaningIndex <= result.meanings.length) {
      return result.meanings[meaningIndex - 1];
    }
    
    return null;
  }

  /// Get specific translation by cycling index for target word
  Future<CyclableReverseLookup?> getTranslationAtIndex(
    String targetWord,
    String sourceLanguage,
    String targetLanguage,
    int translationIndex,
  ) async {
    final result = await lookupTargetTranslations(targetWord, sourceLanguage, targetLanguage);
    
    if (result.hasResults && translationIndex > 0 && translationIndex <= result.translations.length) {
      return result.translations[translationIndex - 1];
    }
    
    return null;
  }

  /// Search for words containing query (fuzzy search)
  Future<List<String>> searchWords(
    String query,
    String sourceLanguage,
    String targetLanguage, {
    int limit = 10,
  }) async {
    final searchQuery = '''
      SELECT DISTINCT wg.base_word
      FROM word_groups wg
      WHERE wg.base_word LIKE ? COLLATE NOCASE
        AND wg.source_language = ?
        AND wg.target_language = ?
      ORDER BY 
        CASE WHEN wg.base_word = ? COLLATE NOCASE THEN 0 ELSE 1 END,
        LENGTH(wg.base_word),
        wg.base_word
      LIMIT ?
    ''';

    final result = await _database.customSelect(
      searchQuery,
      variables: [
        Variable<String>('%${query.toLowerCase()}%'),
        Variable<String>(sourceLanguage),
        Variable<String>(targetLanguage),
        Variable<String>(query.toLowerCase()),
        Variable<int>(limit),
      ],
    ).get();

    return result.map((row) => row.read<String>('base_word')).toList();
  }

  /// Get database statistics for language pair
  Future<Map<String, int>> getStats(String sourceLanguage, String targetLanguage) async {
    final wordGroupsQuery = '''
      SELECT COUNT(*) as count
      FROM word_groups
      WHERE source_language = ? AND target_language = ?
    ''';

    final meaningsQuery = '''
      SELECT COUNT(*) as count  
      FROM meanings m
      JOIN word_groups wg ON m.word_group_id = wg.id
      WHERE wg.source_language = ? AND wg.target_language = ?
    ''';

    final reverseQuery = '''
      SELECT COUNT(DISTINCT target_word) as count
      FROM target_reverse_lookup trl
      JOIN word_groups wg ON trl.source_word_group_id = wg.id
      WHERE wg.source_language = ? AND wg.target_language = ?
    ''';

    final wordGroupsResult = await _database.customSelect(
      wordGroupsQuery,
      variables: [Variable<String>(sourceLanguage), Variable<String>(targetLanguage)],
    ).getSingle();

    final meaningsResult = await _database.customSelect(
      meaningsQuery,
      variables: [Variable<String>(sourceLanguage), Variable<String>(targetLanguage)],
    ).getSingle();

    final reverseResult = await _database.customSelect(
      reverseQuery,
      variables: [Variable<String>(sourceLanguage), Variable<String>(targetLanguage)],
    ).getSingle();

    return {
      'wordGroups': wordGroupsResult.read<int>('count'),
      'meanings': meaningsResult.read<int>('count'),
      'targetWords': reverseResult.read<int>('count'),
    };
  }

  /// Check if word exists in dictionary
  Future<bool> wordExists(
    String word,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final query = '''
      SELECT COUNT(*) as count
      FROM word_groups
      WHERE base_word = ? COLLATE NOCASE
        AND source_language = ?
        AND target_language = ?
    ''';

    final result = await _database.customSelect(
      query,
      variables: [
        Variable<String>(word.toLowerCase()),
        Variable<String>(sourceLanguage),
        Variable<String>(targetLanguage),
      ],
    ).getSingle();

    return result.read<int>('count') > 0;
  }

  /// Get random word for testing/learning
  Future<String?> getRandomWord(
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final query = '''
      SELECT base_word
      FROM word_groups
      WHERE source_language = ? AND target_language = ?
      ORDER BY RANDOM()
      LIMIT 1
    ''';

    final result = await _database.customSelect(
      query,
      variables: [Variable<String>(sourceLanguage), Variable<String>(targetLanguage)],
    ).get();

    return result.isNotEmpty ? result.first.read<String>('base_word') : null;
  }
}