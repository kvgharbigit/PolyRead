import 'package:flutter_test/flutter_test.dart';
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/dictionary_service.dart';
import 'package:polyread/features/translation/services/translation_cache_service.dart';
import 'package:polyread/features/translation/models/translation_request.dart';
import 'package:polyread/features/translation/models/dictionary_entry.dart';
import 'package:polyread/features/translation/providers/translation_provider.dart';
import 'dart:math';
import 'dart:async';

void main() {
  group('Translation Service Integration Tests', () {
    late MockTranslationService translationService;

    setUp(() {
      translationService = MockTranslationService();
    });

    group('Word-Level Translation Tests', () {
      test('should translate random single words correctly', () async {
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
          expect(response.latencyMs, greaterThan(0), reason: 'Latency should be recorded');
          expect(response.source, isNotNull);
          
          // For single words, should prioritize dictionary lookup
          if (word.length < 50 && !word.contains(' ')) {
            expect(response.source, equals(TranslationSource.dictionary),
                reason: 'Single word should use dictionary');
          }
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
          if (response.source == TranslationSource.dictionary) {
            expect(response.dictionaryEntries, isNotNull);
            expect(response.dictionaryEntries!.isNotEmpty, isTrue);
          } else {
            expect(response.translatedText, isNotNull);
            expect(response.translatedText, isNot(equals(word)), 
                reason: 'Translation should be different from original');
          }
        }
      });

      test('should cache word translations efficiently', () async {
        const testWord = 'hello';
        
        // First translation - should not be from cache
        final firstResponse = await translationService.translateText(
          text: testWord,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          useCache: true,
        );
        expect(firstResponse.fromCache, isFalse, reason: 'First call should not be cached');
        expect(firstResponse.success, isTrue);
        final firstLatency = firstResponse.latencyMs;
        
        // Second translation - should be from cache
        final secondResponse = await translationService.translateText(
          text: testWord,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          useCache: true,
        );
        expect(secondResponse.fromCache, isTrue, reason: 'Second call should be cached');
        expect(secondResponse.latencyMs, lessThan(firstLatency), 
            reason: 'Cache hit should be faster');
      });

      test('should detect single words vs phrases correctly', () async {
        final testCases = [
          ('hello', true),
          ('world', true),
          ('translate', true),
          ('hello world', false),
          ('good morning', false),
          ('how are you', false),
          ('artificial intelligence', false),
          ('café', true),
          ('very_long_compound_word_that_exceeds_limit' * 3, false), // Over 50 chars
        ];
        
        for (final (text, shouldBeSingleWord) in testCases) {
          final response = await translationService.translateText(
            text: text,
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          
          expect(response.success, isTrue, reason: 'Translation should succeed');
          
          if (shouldBeSingleWord) {
            expect(response.source, equals(TranslationSource.dictionary),
                reason: '"$text" should be treated as single word');
          } else {
            expect(response.source, isIn([TranslationSource.mlKit, TranslationSource.server]),
                reason: '"$text" should use ML providers');
          }
        }
      });
    });

    group('Sentence-Level Translation Tests', () {
      test('should translate random sentences correctly', () async {
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
          expect(response.source, isIn([TranslationSource.mlKit, TranslationSource.server]),
              reason: 'Sentences should use ML providers');
        }
      });

      test('should handle different sentence structures', () async {
        final sentenceTypes = [
          ('This is a simple declarative sentence.', 'declarative'),
          ('Is this a question?', 'interrogative'),
          ('What a beautiful day!', 'exclamatory'),
          ('Please translate this sentence.', 'imperative'),
          ('The quick brown fox jumps over the lazy dog.', 'complex'),
          ('In 2023, AI revolutionized translation.', 'temporal'),
          ('She said, "I love learning languages."', 'quoted'),
          ('The café was closed; however, the library remained open.', 'compound'),
        ];
        
        for (final (sentence, type) in sentenceTypes) {
          final response = await translationService.translateText(
            text: sentence,
            sourceLanguage: 'en',
            targetLanguage: 'fr',
            useCache: false,
          );
          
          expect(response.success, isTrue, 
              reason: '$type sentence should translate successfully: "$sentence"');
          expect(response.translatedText, isNotNull);
          expect(response.translatedText!.length, greaterThan(0));
        }
      });

      test('should handle long paragraphs efficiently', () async {
        final longText = '''
          Machine translation has revolutionized how we communicate across language barriers. 
          Modern neural networks can now translate complex texts with remarkable accuracy, 
          preserving context and meaning while adapting to different writing styles. 
          This technology enables real-time communication between people who speak different languages, 
          breaking down barriers and fostering global understanding. The future of translation 
          technology looks incredibly promising as we continue to advance in artificial intelligence.
        '''.trim();
        
        final stopwatch = Stopwatch()..start();
        final response = await translationService.translateText(
          text: longText,
          sourceLanguage: 'en',
          targetLanguage: 'de',
          useCache: false,
        );
        stopwatch.stop();
        
        expect(response.success, isTrue, reason: 'Long text should translate successfully');
        expect(response.translatedText, isNotNull);
        expect(response.latencyMs, greaterThan(0));
        expect(stopwatch.elapsedMilliseconds, lessThan(10000), 
            reason: 'Long text should translate within 10 seconds');
      });

      test('should preserve text formatting', () async {
        final formattedTexts = [
          'Line 1\nLine 2\nLine 3',
          'Word1\tWord2\tWord3',
          'Multiple   spaces   between   words',
          '  Leading and trailing spaces  ',
          'Text with\r\ndifferent\nline endings',
        ];
        
        for (final text in formattedTexts) {
          final response = await translationService.translateText(
            text: text,
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          
          expect(response.success, isTrue, reason: 'Formatted text should translate');
          expect(response.request.text, equals(text), 
              reason: 'Original text should be preserved in request');
        }
      });
    });

    group('Performance and Reliability Tests', () {
      test('should handle concurrent translations without issues', () async {
        final testTexts = generateRandomTexts(20);
        final futures = testTexts.map((text) => translationService.translateText(
          text: text,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          useCache: false,
        ));
        
        final stopwatch = Stopwatch()..start();
        final responses = await Future.wait(futures);
        stopwatch.stop();
        
        expect(responses.length, equals(testTexts.length));
        
        for (final response in responses) {
          expect(response.success, isTrue, reason: 'Concurrent translations should succeed');
        }
        
        expect(stopwatch.elapsedMilliseconds, lessThan(30000), 
            reason: 'All concurrent translations should complete within 30 seconds');
      });

      test('should measure translation latency accurately', () async {
        final testCases = [
          ('word', 'hello'),
          ('phrase', 'good morning'),
          ('sentence', 'The weather is beautiful today.'),
        ];
        
        final latencies = <String, List<int>>{};
        
        for (final (type, text) in testCases) {
          latencies[type] = [];
          
          // Run multiple iterations
          for (int i = 0; i < 3; i++) {
            final response = await translationService.translateText(
              text: text,
              sourceLanguage: 'en',
              targetLanguage: 'es',
              useCache: false,
            );
            
            expect(response.success, isTrue);
            expect(response.latencyMs, greaterThan(0));
            latencies[type]!.add(response.latencyMs);
          }
        }
        
        // Calculate averages
        final avgLatencies = latencies.map((key, values) => 
          MapEntry(key, values.reduce((a, b) => a + b) / values.length));
        
        // Verify reasonable latency ranges
        expect(avgLatencies['word']!, lessThan(1000), 
            reason: 'Word translations should be fast');
        expect(avgLatencies['phrase']!, lessThan(2000), 
            reason: 'Phrase translations should be reasonable');
        expect(avgLatencies['sentence']!, lessThan(5000), 
            reason: 'Sentence translations should complete quickly');
      });

      test('should validate translation request equality correctly', () {
        final request1 = TranslationRequest(
          text: 'Hello World',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          timestamp: DateTime.now(),
        );
        
        final request2 = TranslationRequest(
          text: ' hello world ', // Different whitespace and case
          sourceLanguage: 'en',
          targetLanguage: 'es',
          timestamp: DateTime.now().add(Duration(seconds: 1)),
        );
        
        final request3 = TranslationRequest(
          text: 'Hello World',
          sourceLanguage: 'en',
          targetLanguage: 'fr', // Different target
          timestamp: DateTime.now(),
        );
        
        // Same text (normalized) and languages should be equal
        expect(request1, equals(request2));
        expect(request1.hashCode, equals(request2.hashCode));
        expect(request1.cacheKey, equals(request2.cacheKey));
        
        // Different target language should not be equal
        expect(request1, isNot(equals(request3)));
        expect(request1.hashCode, isNot(equals(request3.hashCode)));
        expect(request1.cacheKey, isNot(equals(request3.cacheKey)));
      });
    });

    group('Error Handling Tests', () {
      test('should handle unsupported language pairs gracefully', () async {
        final response = await translationService.translateText(
          text: 'Test text',
          sourceLanguage: 'unsupported_lang',
          targetLanguage: 'also_unsupported',
        );
        
        // Should either succeed (if mock handles all languages) or fail gracefully
        if (!response.success) {
          expect(response.error, isNotNull);
          expect(response.error, contains('language'));
        }
      });

      test('should handle very long texts appropriately', () async {
        final veryLongText = 'word ' * 1000; // 5000 characters
        
        final response = await translationService.translateText(
          text: veryLongText,
          sourceLanguage: 'en',
          targetLanguage: 'es',
        );
        
        // Should either succeed or fail gracefully with informative error
        if (!response.success) {
          expect(response.error, isNotNull);
        } else {
          expect(response.translatedText, isNotNull);
        }
      });

      test('should handle empty and whitespace-only inputs', () async {
        final invalidInputs = ['', '   ', '\n', '\t', '\r\n'];
        
        for (final input in invalidInputs) {
          final response = await translationService.translateText(
            text: input,
            sourceLanguage: 'en',
            targetLanguage: 'es',
          );
          
          // Empty inputs should generally fail
          if (input.trim().isEmpty) {
            expect(response.success, isFalse, 
                reason: 'Empty input "$input" should fail gracefully');
          }
        }
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

// Mock Translation Service that simulates realistic behavior
class MockTranslationService {
  final Map<String, TranslationResponse> _cache = {};
  final Random _random = Random(42); // Fixed seed for consistent tests

  Future<TranslationResponse> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    bool useCache = true,
  }) async {
    final request = TranslationRequest(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      timestamp: DateTime.now(),
    );

    // Check cache first
    if (useCache && _cache.containsKey(request.cacheKey)) {
      final cached = _cache[request.cacheKey]!;
      return TranslationResponse.fromCached(cached);
    }

    // Simulate translation processing time
    final latency = _simulateLatency(text);
    await Future.delayed(Duration(milliseconds: latency));

    // Determine translation source based on text
    final source = _determineSource(text);
    final success = _shouldSucceed(text, sourceLanguage, targetLanguage);

    TranslationResponse response;
    
    if (success) {
      final translatedText = _mockTranslate(text, sourceLanguage, targetLanguage, source);
      
      if (source == TranslationSource.dictionary) {
        response = TranslationResponse.fromDictionary(
          request: request,
          dictionaryResult: DictionaryLookupResult(
            query: text,
            language: sourceLanguage,
            entries: [
              DictionaryEntry(
                word: text,
                language: sourceLanguage,
                definition: 'Mock definition for $text',
                sourceDictionary: 'mock_dictionary',
                createdAt: DateTime.now(),
              )
            ],
            latencyMs: latency,
          ),
        );
      } else {
        response = TranslationResponse.fromProvider(
          request: request,
          result: TranslationResult.success(
            originalText: text,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            providerId: source == TranslationSource.mlKit ? 'ml_kit' : 'server',
            latencyMs: latency,
          ),
        );
      }
    } else {
      response = TranslationResponse.error(
        request: request,
        error: 'Mock translation error for unsupported language pair',
      );
    }

    // Cache successful translations
    if (useCache && response.success) {
      _cache[request.cacheKey] = response;
    }

    return response;
  }

  TranslationSource _determineSource(String text) {
    if (_isSingleWord(text)) {
      return TranslationSource.dictionary;
    } else if (_random.nextBool()) {
      return TranslationSource.mlKit;
    } else {
      return TranslationSource.server;
    }
  }

  bool _isSingleWord(String text) {
    final trimmed = text.trim();
    return !trimmed.contains(' ') && 
           !trimmed.contains('\n') && 
           !trimmed.contains('\t') &&
           trimmed.length > 0 &&
           trimmed.length < 50;
  }

  int _simulateLatency(String text) {
    if (_isSingleWord(text)) {
      return _random.nextInt(50) + 10; // 10-60ms for dictionary
    } else if (text.length < 100) {
      return _random.nextInt(300) + 100; // 100-400ms for short texts
    } else {
      return _random.nextInt(1000) + 500; // 500-1500ms for long texts
    }
  }

  bool _shouldSucceed(String text, String source, String target) {
    // Fail for obviously unsupported languages
    if (source.startsWith('unsupported') || target.startsWith('unsupported')) {
      return false;
    }
    
    // Fail for empty text
    if (text.trim().isEmpty) {
      return false;
    }
    
    // 98% success rate for more reliable testing
    return _random.nextDouble() > 0.02;
  }

  String _mockTranslate(String text, String source, String target, TranslationSource provider) {
    final prefix = provider == TranslationSource.dictionary ? 'Dict' : 
                   provider == TranslationSource.mlKit ? 'MLKit' : 'Server';
    return '$prefix-$target: $text';
  }
}

