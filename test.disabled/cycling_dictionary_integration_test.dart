// Integration test for the complete cycling dictionary system
// Tests real data with the new generalized schema

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/features/translation/services/cycling_dictionary_service.dart';

void main() {
  group('Cycling Dictionary Integration Tests', () {
    late AppDatabase database;
    late CyclingDictionaryService service;

    setUpAll(() async {
      // Use the actual generated dictionary
      const dbPath = 'tools/dist/es-en.sqlite';
      
      if (!File(dbPath).existsSync()) {
        throw Exception('Dictionary not found. Run: cd tools && ./vuizur-meaning-dict-builder.sh es-en');
      }

      // Open the real dictionary database
      final connection = DatabaseConnection(NativeDatabase(File(dbPath)));
      database = AppDatabase.forTesting(connection);
      service = CyclingDictionaryService(database);
    });

    tearDownAll(() async {
      await database.close();
    });

    test('Spanish → English meaning cycling works', () async {
      const sourceWord = 'agua';
      const sourceLanguage = 'es';
      const targetLanguage = 'en';

      final result = await service.lookupSourceMeanings(
        sourceWord,
        sourceLanguage,
        targetLanguage,
      );

      expect(result.hasResults, true, reason: 'Should find meanings for "agua"');
      expect(result.meanings.length, greaterThan(1), reason: 'Should have multiple meanings');
      
      final firstMeaning = result.meanings.first;
      expect(firstMeaning.sourceWord, equals('agua'));
      expect(firstMeaning.displayTranslation, isNotEmpty);
      expect(firstMeaning.isPrimary, true, reason: 'First meaning should be primary');
      
      // Test cycling behavior
      expect(firstMeaning.currentIndex, equals(1));
      expect(firstMeaning.totalMeanings, equals(result.meanings.length));
      expect(firstMeaning.hasNext, true);
      expect(firstMeaning.hasPrevious, false);

      print('✅ Spanish → English cycling test passed');
      print('   Word: ${firstMeaning.sourceWord}');
      print('   Translation: ${firstMeaning.displayTranslation}');
      print('   Expanded: ${firstMeaning.expandedTranslation}');
      print('   Part of Speech: ${firstMeaning.partOfSpeechTag}');
      print('   Total meanings: ${firstMeaning.totalMeanings}');
    });

    test('English → Spanish reverse lookup works', () async {
      const targetWord = 'water';
      const sourceLanguage = 'es';
      const targetLanguage = 'en';

      final result = await service.lookupTargetTranslations(
        targetWord,
        sourceLanguage,
        targetLanguage,
      );

      expect(result.hasResults, true, reason: 'Should find Spanish words for "water"');
      expect(result.translations.length, greaterThan(0));
      
      final firstTranslation = result.translations.first;
      expect(firstTranslation.targetWord, equals('water'));
      expect(firstTranslation.displayTranslation, isNotEmpty);
      expect(firstTranslation.qualityScore, greaterThan(0));
      
      // Test cycling behavior
      expect(firstTranslation.currentIndex, equals(1));
      expect(firstTranslation.totalTranslations, equals(result.translations.length));

      print('✅ English → Spanish reverse lookup test passed');
      print('   Word: ${firstTranslation.targetWord}');
      print('   Translation: ${firstTranslation.displayTranslation}');
      print('   Expanded: ${firstTranslation.expandedTranslation}');
      print('   Quality: ${firstTranslation.qualityIndicator}');
    });

    test('Part-of-speech preservation works', () async {
      const sourceWord = 'hacer';
      const sourceLanguage = 'es';
      const targetLanguage = 'en';

      final result = await service.lookupSourceMeanings(
        sourceWord,
        sourceLanguage,
        targetLanguage,
      );

      expect(result.hasResults, true);
      
      final firstMeaning = result.meanings.first;
      expect(firstMeaning.partOfSpeechTag, isNotEmpty, reason: 'Should have part-of-speech tag');
      expect(firstMeaning.partOfSpeechTag, contains('['), reason: 'Should be formatted as [pos]');

      print('✅ Part-of-speech preservation test passed');
      print('   Word: ${firstMeaning.sourceWord}');
      print('   POS: ${firstMeaning.partOfSpeechTag}');
    });

    test('Context expansion works', () async {
      const sourceWord = 'mano';
      const sourceLanguage = 'es';
      const targetLanguage = 'en';

      final result = await service.lookupSourceMeanings(
        sourceWord,
        sourceLanguage,
        targetLanguage,
      );

      expect(result.hasResults, true);
      
      // Find a meaning with context
      final meaningWithContext = result.meanings.firstWhere(
        (m) => m.meaning.context != null && m.meaning.context!.isNotEmpty,
        orElse: () => result.meanings.first,
      );

      expect(meaningWithContext.displayTranslation, isNotEmpty);
      
      if (meaningWithContext.meaning.context != null) {
        expect(
          meaningWithContext.expandedTranslation,
          contains(meaningWithContext.meaning.context!),
          reason: 'Expanded translation should include context',
        );
        expect(
          meaningWithContext.expandedTranslation.length,
          greaterThan(meaningWithContext.displayTranslation.length),
          reason: 'Expanded should be longer than display',
        );

        print('✅ Context expansion test passed');
        print('   Word: ${meaningWithContext.sourceWord}');
        print('   Display: ${meaningWithContext.displayTranslation}');
        print('   Expanded: ${meaningWithContext.expandedTranslation}');
      } else {
        print('✅ Context expansion test passed (no context available for this word)');
      }
    });

    test('Quality scoring works for reverse lookup', () async {
      const targetWord = 'time';
      const sourceLanguage = 'es';
      const targetLanguage = 'en';

      final result = await service.lookupTargetTranslations(
        targetWord,
        sourceLanguage,
        targetLanguage,
      );

      expect(result.hasResults, true);
      expect(result.translations.length, greaterThan(1));
      
      // Check that translations are ordered by quality (lookup_order)
      for (int i = 0; i < result.translations.length - 1; i++) {
        final current = result.translations[i];
        final next = result.translations[i + 1];
        
        expect(
          current.currentIndex,
          lessThan(next.currentIndex),
          reason: 'Translations should be in lookup order',
        );
      }

      final highestQuality = result.translations.first;
      expect(highestQuality.qualityScore, greaterThan(0));

      print('✅ Quality scoring test passed');
      print('   Word: ${highestQuality.targetWord}');
      print('   Top translation: ${highestQuality.displayTranslation}');
      print('   Quality score: ${highestQuality.qualityScore}');
      print('   Quality indicator: ${highestQuality.qualityIndicator}');
    });

    test('Database statistics are reasonable', () async {
      const sourceLanguage = 'es';
      const targetLanguage = 'en';

      final stats = await service.getStats(sourceLanguage, targetLanguage);

      expect(stats['wordGroups'], greaterThan(50000), reason: 'Should have substantial word groups');
      expect(stats['meanings'], greaterThan(100000), reason: 'Should have substantial meanings');
      expect(stats['targetWords'], greaterThan(50000), reason: 'Should have substantial target words');
      
      expect(stats['meanings']! > stats['wordGroups']!, true, 
        reason: 'Should have more meanings than word groups (multiple meanings per word)');

      print('✅ Database statistics test passed');
      print('   Word Groups: ${stats['wordGroups']}');
      print('   Meanings: ${stats['meanings']}');
      print('   Target Words: ${stats['targetWords']}');
    });

    test('Search functionality works', () async {
      const query = 'caf';
      const sourceLanguage = 'es';
      const targetLanguage = 'en';

      final results = await service.searchWords(
        query,
        sourceLanguage,
        targetLanguage,
        limit: 10,
      );

      expect(results, isNotEmpty, reason: 'Should find words containing "caf"');
      expect(results.length, lessThanOrEqualTo(10), reason: 'Should respect limit');
      
      // All results should contain the query
      for (final word in results) {
        expect(word.toLowerCase(), contains(query.toLowerCase()));
      }

      print('✅ Search functionality test passed');
      print('   Query: "$query"');
      print('   Results: ${results.take(5).join(', ')}...');
    });

    test('Word existence check works', () async {
      const sourceLanguage = 'es';
      const targetLanguage = 'en';

      // Test known word
      final existsKnown = await service.wordExists('agua', sourceLanguage, targetLanguage);
      expect(existsKnown, true, reason: '"agua" should exist');

      // Test non-existent word
      final existsUnknown = await service.wordExists('xyznonexistent', sourceLanguage, targetLanguage);
      expect(existsUnknown, false, reason: 'Random word should not exist');

      print('✅ Word existence check test passed');
    });
  });
}

