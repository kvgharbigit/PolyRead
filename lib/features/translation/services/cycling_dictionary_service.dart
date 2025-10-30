// Cycling Dictionary Service for one-level meaning cycling + expansion UI
// Supports both Source→Target and Target→Source with any language pair

import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../models/meaning_entry.dart';

class CyclingDictionaryService {
  final AppDatabase _database;

  CyclingDictionaryService(this._database);

  /// Look up meanings for source word (e.g., Spanish → English)
  /// Returns cyclable meanings in order for UI cycling
  Future<MeaningLookupResult> lookupSourceMeanings(
    String sourceWord,
    String sourceLanguage,
    String targetLanguage,
  ) async {
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
      // Get word group and meanings
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

      final result = await _database.customSelect(
        query,
        variables: [
          Variable<String>(sourceWord.toLowerCase()),
          Variable<String>(sourceLanguage),
          Variable<String>(targetLanguage),
        ],
      ).get();

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
          isPrimary: row.read<int>('is_primary') == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('m_created_at')),
        );

        // Build CyclableMeaning
        meanings.add(CyclableMeaning(
          wordGroup: wordGroup,
          meaning: meaning,
          currentIndex: i + 1,
          totalMeanings: result.length,
        ));
      }

      return MeaningLookupResult(
        query: sourceWord,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        meanings: meanings,
        latencyMs: stopwatch.elapsedMilliseconds,
        fromCache: false,
      );
    } finally {
      stopwatch.stop();
    }
  }

  /// Look up source words for target word (e.g., English → Spanish)
  /// Returns cyclable reverse translations in quality order
  Future<ReverseLookupResult> lookupTargetTranslations(
    String targetWord,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    // Input validation
    if (targetWord.trim().isEmpty) {
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
      throw ArgumentError('Language codes must be at least 2 characters');
    }
    final stopwatch = Stopwatch()..start();

    try {
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