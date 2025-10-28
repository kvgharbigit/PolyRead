// Translation Service Tests
// TODO: Update tests to work with DriftTranslationService instead of the old TranslationService

/*
import 'package:flutter_test/flutter_test.dart';
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/dictionary_service.dart';
import 'package:polyread/features/translation/services/translation_cache_service.dart';
import 'package:polyread/features/translation/models/translation_request.dart';
// import 'package:polyread/features/translation/models/dictionary_entry.dart'; // Not currently used in test
import 'dart:math';

void main() {
  group('Translation Service Tests', () {
    late TranslationService translationService;
    late MockDictionaryService mockDictionaryService;
    late MockTranslationCacheService mockCacheService;

    setUp(() {
      mockDictionaryService = MockDictionaryService();
      mockCacheService = MockTranslationCacheService();
      translationService = TranslationService(
        dictionaryService: mockDictionaryService,
        cacheService: mockCacheService,
      );
    });

    tearDown(() async {
      await translationService.dispose();
    });

    group('Word-Level Translation Tests', () {
      test('should translate single words correctly', () async {
        final testWords = generateRandomWords(10);
        
        for (final word in testWords) {
          final response = await translationService.translateText(
            text: word,
            sourceLanguage: 'en',
            targetLanguage: 'es',
            useCache: false,
          );
          
          expect(response.success, isTrue, reason: 'Translation of "$word" should succeed');
          expect(response.request.text, equals(word));
          expect(response.latencyMs, greaterThan(0));
          expect(response.source, isNotNull);
        }
      });

      test('should handle special characters in words', () async {
        final specialWords = [
          'café', 'naïve', 'résumé', 'piñata', 'jalapeño',
          'château', 'façade', 'fiancé', 'cliché', 'exposé'
        ];
        
        for (final word in specialWords) {
          final response = await translationService.translateText(
            text: word,
            sourceLanguage: 'fr',
            targetLanguage: 'en',
            useCache: false,
          );
          
          expect(response.success, isTrue, reason: 'Translation of "$word" should succeed');
          expect(response.request.text, equals(word));
        }
      });

      test('should detect single words correctly', () async {
        final singleWords = ['hello', 'world', 'translate', 'language'];
        final multiWords = ['hello world', 'good morning', 'how are you'];
        
        for (final word in singleWords) {
          final response = await translationService.translateText(
            text: word,
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          
          // Single words should go through dictionary lookup first
          expect(response.source, equals(TranslationSource.dictionary));
        }
        
        for (final phrase in multiWords) {
          final response = await translationService.translateText(
            text: phrase,
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          
          // Multi-word phrases should skip dictionary and use ML providers
          expect(response.source, isNot(equals(TranslationSource.dictionary)));
        }
      });

      test('should cache word translations', () async {
        const testWord = 'hello';
        
        // First translation - should not be from cache
        final firstResponse = await translationService.translateText(
          text: testWord,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          useCache: true,
        );
        expect(firstResponse.fromCache, isFalse);
        
        // Second translation - should be from cache
        final secondResponse = await translationService.translateText(
          text: testWord,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          useCache: true,
        );
        expect(secondResponse.fromCache, isTrue);
        expect(secondResponse.latencyMs, equals(0)); // Cache hits are instant
      });

      test('should handle empty and invalid words', () async {
        final invalidInputs = ['', '   ', '\n', '\t', 'a' * 100]; // Very long word
        
        for (final input in invalidInputs) {
          final response = await translationService.translateText(
            text: input,
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          
          if (input.trim().isEmpty) {
            expect(response.success, isFalse, reason: 'Empty input should fail');
          } else if (input.length >= 50) {
            // Very long inputs should be treated as sentences, not words
            expect(response.source, isNot(equals(TranslationSource.dictionary)));
          }
        }
      });
    });

    group('Sentence-Level Translation Tests', () {
      test('should translate sentences correctly', () async {
        final testSentences = generateRandomSentences(10);
        
        for (final sentence in testSentences) {
          final response = await translationService.translateText(
            text: sentence,
            sourceLanguage: 'en',
            targetLanguage: 'es',
            useCache: false,
          );
          
          expect(response.success, isTrue, reason: 'Translation of "$sentence" should succeed');
          expect(response.request.text, equals(sentence));
          expect(response.latencyMs, greaterThan(0));
          expect(response.translatedText, isNotNull);
        }
      });

      test('should handle different sentence structures', () async {
        final sentenceTypes = [
          'This is a simple declarative sentence.',
          'Is this a question?',
          'What a beautiful day!',
          'Please translate this sentence.',
          'The quick brown fox jumps over the lazy dog.',
          'In 2023, artificial intelligence revolutionized translation technology.',
          'She said, "I love learning new languages."',
          'The café was closed; however, the library remained open.',
        ];
        
        for (final sentence in sentenceTypes) {
          final response = await translationService.translateText(
            text: sentence,
            sourceLanguage: 'en',
            targetLanguage: 'fr',
            useCache: false,
          );
          
          expect(response.success, isTrue, reason: 'Translation of "$sentence" should succeed');
          expect(response.source, isIn([TranslationSource.mlKit, TranslationSource.server]));
        }
      });

      test('should handle long paragraphs', () async {
        final longText = '''
          Machine translation has revolutionized how we communicate across language barriers. 
          Modern neural networks can now translate complex texts with remarkable accuracy, 
          preserving context and meaning while adapting to different writing styles. 
          This technology enables real-time communication between people who speak different languages, 
          breaking down barriers and fostering global understanding.
        '''.trim();
        
        final response = await translationService.translateText(
          text: longText,
          sourceLanguage: 'en',
          targetLanguage: 'de',
          useCache: false,
        );
        
        expect(response.success, isTrue);
        expect(response.translatedText, isNotNull);
        expect(response.latencyMs, greaterThan(0));
      });

      test('should preserve formatting in translations', () async {
        final formattedTexts = [
          'Line 1\nLine 2\nLine 3',
          'Word1\tWord2\tWord3',
          'Multiple   spaces   between   words',
          '  Leading and trailing spaces  ',
        ];
        
        for (final text in formattedTexts) {
          final response = await translationService.translateText(
            text: text,
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          
          expect(response.success, isTrue, reason: 'Formatted text should translate successfully');
          expect(response.request.text, equals(text)); // Original text preserved in request
        }
      });

      test('should handle multilingual sentences', () async {
        final multilingualTexts = [
          'Hello world, bonjour monde!',
          'I speak English y también español.',
          'Tokyo (東京) is the capital of Japan.',
          'The café serves excellent caffè.',
        ];
        
        for (final text in multilingualTexts) {
          final response = await translationService.translateText(
            text: text,
            sourceLanguage: 'en',
            targetLanguage: 'fr',
          );
          
          expect(response.success, isTrue, reason: 'Multilingual text should translate');
        }
      });
    });

    group('Performance and Reliability Tests', () {
      test('should handle concurrent translations', () async {
        final testTexts = generateRandomTexts(20);
        final futures = testTexts.map((text) => translationService.translateText(
          text: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          useCache: false,
        ));
        
        final responses = await Future.wait(futures);
        
        for (final response in responses) {
          expect(response.success, isTrue, reason: 'Concurrent translations should succeed');
        }
      });

      test('should measure translation latency', () async {
        final testCases = [
          ('word', 'hello'),
          ('phrase', 'good morning'),
          ('sentence', 'The weather is beautiful today.'),
          ('paragraph', 'This is a longer text with multiple sentences. It should take more time to translate than a single word. The translation service should handle it efficiently.'),
        ];
        
        final latencies = <String, List<int>>{};
        
        for (final (type, text) in testCases) {
          latencies[type] = [];
          
          // Run multiple iterations to get average latency
          for (int i = 0; i < 5; i++) {
            final stopwatch = Stopwatch()..start();
            
            final response = await translationService.translateText(
              text: text,
              sourceLanguage: 'en',
              targetLanguage: 'es',
              useCache: false,
            );
            
            stopwatch.stop();
            latencies[type]!.add(stopwatch.elapsedMilliseconds);
            
            expect(response.success, isTrue);
            expect(response.latencyMs, greaterThan(0));
          }
        }
        
        // Verify latency trends (longer texts generally take longer)
        final avgLatencies = latencies.map((key, values) => 
          MapEntry(key, values.reduce((a, b) => a + b) / values.length));
        
        print('Average latencies: $avgLatencies');
        
        // Words should generally be faster than sentences
        expect(avgLatencies['word']!, lessThan(avgLatencies['sentence']!));
      });

      test('should handle provider fallback', () async {
        // Test that when one provider fails, it falls back to the next
        final response = await translationService.translateText(
          text: 'This should test provider fallback.',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );
        
        expect(response.success, isTrue);
        expect(response.providerId, isNotNull);
        expect(response.source, isNotNull);
      });

      test('should validate translation request equality', () {
        final request1 = TranslationRequest(
          text: 'Hello World',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          timestamp: DateTime.now(),
        );
        
        final request2 = TranslationRequest(
          text: 'hello world', // Different case
          sourceLanguage: 'en',
          targetLanguage: 'es',
          timestamp: DateTime.now().add(Duration(seconds: 1)), // Different timestamp
        );
        
        final request3 = TranslationRequest(
          text: 'Hello World',
          sourceLanguage: 'en',
          targetLanguage: 'fr', // Different target language
          timestamp: DateTime.now(),
        );
        
        // Same text (case-insensitive) and languages should be equal
        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
        
        // Different target language should not be equal
        expect(request1, isNot(equals(request3)));
        expect(request1.hashCode, isNot(equals(request3.hashCode)));
      });
    });

    group('Error Handling Tests', () {
      test('should handle network errors gracefully', () async {
        // This would test actual network error scenarios
        // For now, test with unsupported language pairs
        final response = await translationService.translateText(
          text: 'Test text',
          sourceLanguage: 'unsupported',
          targetLanguage: 'also_unsupported',
        );
        
        expect(response.success, isFalse);
        expect(response.error, isNotNull);
      });

      test('should handle very long texts', () async {
        final veryLongText = 'word ' * 1000; // 5000 characters
        
        final response = await translationService.translateText(
          text: veryLongText,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );
        
        // Should either succeed or fail gracefully
        expect(response.error, anyOf(isNull, isA<String>()));
      });
    });
  });
}

// Helper functions for generating random test data
List<String> generateRandomWords(int count) {
  final words = [
    'hello', 'world', 'translate', 'language', 'book', 'read', 'study', 'learn',
    'computer', 'technology', 'artificial', 'intelligence', 'machine', 'neural',
    'network', 'deep', 'learning', 'natural', 'processing', 'algorithm',
    'beautiful', 'amazing', 'wonderful', 'fantastic', 'excellent', 'perfect',
    'house', 'family', 'friend', 'happiness', 'love', 'peace', 'freedom',
    'journey', 'adventure', 'discovery', 'exploration', 'knowledge', 'wisdom'
  ];
  
  final random = Random();
  return List.generate(count, (_) => words[random.nextInt(words.length)]);
}

List<String> generateRandomSentences(int count) {
  final sentences = [
    'The quick brown fox jumps over the lazy dog.',
    'Machine learning is transforming the world of technology.',
    'I love reading books in different languages.',
    'Translation technology has made the world more connected.',
    'Learning new languages opens doors to different cultures.',
    'Artificial intelligence helps us communicate across language barriers.',
    'The future of translation is bright and exciting.',
    'Every language carries the history and culture of its people.',
    'Technology should serve humanity and bring us closer together.',
    'Reading in multiple languages enriches our understanding of the world.',
    'Translation is both an art and a science.',
    'Language learning is a journey of discovery and growth.',
    'Communication is the foundation of human connection.',
    'Every word carries meaning, context, and emotion.',
    'The beauty of language lies in its infinite expressiveness.'
  ];
  
  final random = Random();
  return List.generate(count, (_) => sentences[random.nextInt(sentences.length)]);
}

List<String> generateRandomTexts(int count) {
  final words = generateRandomWords(count ~/ 2);
  final sentences = generateRandomSentences(count ~/ 2);
  final combined = [...words, ...sentences];
  combined.shuffle();
  return combined.take(count).toList();
}

// Mock implementations for testing
class MockDictionaryService implements DictionaryService {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<DictionaryEntry>> lookupWord({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
    int limit = 5,
  }) async {
    // Mock dictionary entries
    return [
      DictionaryEntry(
        word: word,
        language: sourceLanguage,
        definition: 'Mock definition for $word',
        sourceDictionary: 'test_dictionary',
        createdAt: DateTime.now(),
      )
    ];
  }

  @override
  Future<List<DictionaryEntry>> searchEntries({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
    int limit = 20,
  }) async {
    return [];
  }

  @override
  Future<int> addEntry(DictionaryEntry entry) async {
    return 1;
  }

  @override
  Future<void> addEntries(List<DictionaryEntry> entries, {
    Function(int processed, int total)? onProgress,
  }) async {}

  @override
  Future<void> importStarDict({
    required String dictionaryName,
    required List<StarDictEntry> entries,
    required String sourceLanguage,
    required String targetLanguage,
    Function(int processed, int total)? onProgress,
  }) async {}

  @override
  Future<DictionaryStats> getStats() async {
    return const DictionaryStats(totalEntries: 1000, languageStats: {});
  }

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> clearDictionary(String dictionaryName) async {}
}

class MockTranslationCacheService implements TranslationCacheService {
  final Map<String, TranslationResponse> _cache = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<TranslationResponse?> getCachedTranslation(TranslationRequest request) async {
    final cached = _cache[request.cacheKey];
    if (cached != null) {
      return TranslationResponse.fromCached(cached);
    }
    return null;
  }

  @override
  Future<void> cacheTranslation(TranslationRequest request, TranslationResponse response) async {
    _cache[request.cacheKey] = response;
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
  }

  @override
  Future<void> clearOldEntries({int maxAgeDays = 30}) async {}

  @override
  Future<CacheStats> getStats() async {
    return CacheStats(
      totalEntries: _cache.length, 
      totalSize: _cache.length * 100,
    );
  }

  @override
  Future<void> dispose() async {}
}
*/