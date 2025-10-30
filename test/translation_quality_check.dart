import 'package:flutter_test/flutter_test.dart';
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/translation_cache_service.dart';
import 'package:polyread/features/translation/models/translation_request.dart';
import 'package:polyread/features/translation/models/dictionary_entry.dart';
import 'package:polyread/features/translation/providers/translation_provider.dart';
import 'dart:math';

void main() {
  group('Translation Quality Check', () {
    late MockTranslationService translationService;

    setUp(() {
      translationService = MockTranslationService();
    });

    test('Word-level translation quality examples', () async {
      final testWords = [
        'hello', 'book', 'beautiful', 'computer', 'friend', 
        'happiness', 'journey', 'knowledge', 'café', 'résumé'
      ];

      print('\n=== WORD-LEVEL TRANSLATIONS ===');
      
      for (final word in testWords) {
        final response = await translationService.translateText(
          text: word,
          sourceLanguage: 'en',
          targetLanguage: 'es',
          useCache: false,
        );

        print('Word: "$word"');
        print('  Source: ${response.source.name}');
        print('  Success: ${response.success}');
        print('  Latency: ${response.latencyMs}ms');
        
        if (response.source == TranslationSource.dictionary) {
          if (response.dictionaryEntries != null && response.dictionaryEntries!.isNotEmpty) {
            final entry = response.dictionaryEntries!.first;
            print('  Sense: ${entry.sense}');
            print('  Dictionary: ${entry.sourceDictionary}');
          }
        } else {
          print('  Translation: "${response.translatedText}"');
        }
        print('  Provider: ${response.providerId}');
        print('');

        expect(response.success, isTrue);
      }
    });

    test('Sentence-level translation quality examples', () async {
      final testSentences = [
        'Hello, how are you today?',
        'I am learning a new language.',
        'The weather is beautiful this morning.',
        'Technology is changing the world rapidly.',
        'Can you help me translate this sentence?',
        'Machine learning enables better translations.',
        'I love reading books in different languages.',
        'Translation bridges communication gaps between cultures.',
      ];

      print('\n=== SENTENCE-LEVEL TRANSLATIONS ===');
      
      for (final sentence in testSentences) {
        final response = await translationService.translateText(
          text: sentence,
          sourceLanguage: 'en',
          targetLanguage: 'fr',
          useCache: false,
        );

        print('Original: "$sentence"');
        print('  Source: ${response.source.name}');
        print('  Success: ${response.success}');
        print('  Latency: ${response.latencyMs}ms');
        print('  Translation: "${response.translatedText}"');
        print('  Provider: ${response.providerId}');
        print('');

        expect(response.success, isTrue);
        expect(response.translatedText, isNotNull);
        expect(response.translatedText!.isNotEmpty, isTrue);
      }
    });

    test('Multi-language translation examples', () async {
      final testCases = [
        ('Hello world', 'en', 'es'),
        ('Bonjour le monde', 'fr', 'en'),
        ('Hola mundo', 'es', 'fr'),
        ('Guten Tag', 'de', 'en'),
        ('Ciao mondo', 'it', 'es'),
      ];

      print('\n=== MULTI-LANGUAGE TRANSLATIONS ===');
      
      for (final (text, source, target) in testCases) {
        final response = await translationService.translateText(
          text: text,
          sourceLanguage: source,
          targetLanguage: target,
          useCache: false,
        );

        print('Text: "$text" ($source → $target)');
        print('  Success: ${response.success}');
        print('  Translation: "${response.translatedText}"');
        print('  Source: ${response.source.name}');
        print('  Latency: ${response.latencyMs}ms');
        print('');

        expect(response.success, isTrue);
      }
    });

    test('Complex text translation examples', () async {
      final complexTexts = [
        'The quick brown fox jumps over the lazy dog.',
        'In the midst of winter, I found there was, within me, an invincible summer.',
        'Machine translation has revolutionized how we communicate across language barriers.',
        'Artificial intelligence and neural networks enable more accurate translations than ever before.',
        '''
        Modern language learning apps use sophisticated algorithms 
        to provide personalized learning experiences. These apps can 
        adapt to individual learning styles and pace.
        '''.trim(),
      ];

      print('\n=== COMPLEX TEXT TRANSLATIONS ===');
      
      for (final text in complexTexts) {
        final response = await translationService.translateText(
          text: text,
          sourceLanguage: 'en',
          targetLanguage: 'de',
          useCache: false,
        );

        print('Original (${text.length} chars): "${text.length > 50 ? text.substring(0, 50) + "..." : text}"');
        print('  Success: ${response.success}');
        print('  Source: ${response.source.name}');
        print('  Latency: ${response.latencyMs}ms');
        
        if (response.translatedText != null) {
          final translation = response.translatedText!;
          print('  Translation (${translation.length} chars): "${translation.length > 50 ? translation.substring(0, 50) + "..." : translation}"');
        }
        print('  Provider: ${response.providerId}');
        print('');

        expect(response.success, isTrue);
      }
    });

    test('Performance and caching demonstration', () async {
      final testText = 'This text will be cached after first translation.';
      
      print('\n=== PERFORMANCE & CACHING DEMONSTRATION ===');
      
      // First translation - should not be cached
      print('First translation (not cached):');
      final firstResponse = await translationService.translateText(
        text: testText,
        sourceLanguage: 'en',
        targetLanguage: 'es',
        useCache: true,
      );
      
      print('  Text: "$testText"');
      print('  Translation: "${firstResponse.translatedText}"');
      print('  From cache: ${firstResponse.fromCache}');
      print('  Latency: ${firstResponse.latencyMs}ms');
      print('  Source: ${firstResponse.source.name}');
      print('');

      // Second translation - should be cached
      print('Second translation (cached):');
      final secondResponse = await translationService.translateText(
        text: testText,
        sourceLanguage: 'en',
        targetLanguage: 'es',
        useCache: true,
      );
      
      print('  Text: "$testText"');
      print('  Translation: "${secondResponse.translatedText}"');
      print('  From cache: ${secondResponse.fromCache}');
      print('  Latency: ${secondResponse.latencyMs}ms');
      print('  Performance improvement: ${((firstResponse.latencyMs - secondResponse.latencyMs) / firstResponse.latencyMs * 100).toStringAsFixed(1)}%');
      print('');

      expect(firstResponse.fromCache, isFalse);
      expect(secondResponse.fromCache, isTrue);
      expect(secondResponse.latencyMs, lessThan(firstResponse.latencyMs));
    });

    test('Error handling examples', () async {
      final errorCases = [
        ('', 'en', 'es', 'Empty text'),
        ('   ', 'en', 'es', 'Whitespace only'),
        ('Test text', 'unsupported_lang', 'es', 'Unsupported source language'),
        ('Test text', 'en', 'unsupported_lang', 'Unsupported target language'),
        ('word ' * 500, 'en', 'es', 'Very long text'), // 2500 characters
      ];

      print('\n=== ERROR HANDLING EXAMPLES ===');
      
      for (final (text, source, target, description) in errorCases) {
        final response = await translationService.translateText(
          text: text,
          sourceLanguage: source,
          targetLanguage: target,
          useCache: false,
        );

        print('Case: $description');
        print('  Input: "${text.length > 30 ? text.substring(0, 30) + "..." : text}" ($source → $target)');
        print('  Success: ${response.success}');
        
        if (response.success) {
          print('  Translation: "${response.translatedText}"');
          print('  Source: ${response.source.name}');
        } else {
          print('  Error: ${response.error}');
        }
        print('  Latency: ${response.latencyMs}ms');
        print('');
      }
    });
  });
}

// Enhanced Mock Translation Service with more realistic translations
class MockTranslationService {
  final Map<String, TranslationResponse> _cache = {};
  final Random _random = Random(42);

  // Mock translation dictionaries for more realistic results
  final Map<String, Map<String, String>> _translations = {
    'en_es': {
      'hello': 'hola',
      'book': 'libro',
      'beautiful': 'hermoso',
      'computer': 'computadora',
      'friend': 'amigo',
      'happiness': 'felicidad',
      'journey': 'viaje',
      'knowledge': 'conocimiento',
      'world': 'mundo',
    },
    'en_fr': {
      'hello': 'bonjour',
      'book': 'livre',
      'beautiful': 'beau',
      'computer': 'ordinateur',
      'friend': 'ami',
      'happiness': 'bonheur',
      'journey': 'voyage',
      'knowledge': 'connaissance',
      'world': 'monde',
    },
    'en_de': {
      'hello': 'hallo',
      'book': 'buch',
      'beautiful': 'schön',
      'computer': 'computer',
      'friend': 'freund',
      'happiness': 'glück',
      'journey': 'reise',
      'knowledge': 'wissen',
      'world': 'welt',
    },
  };

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

    // Simulate processing time
    final latency = _simulateLatency(text);
    await Future.delayed(Duration(milliseconds: latency));

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
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            entries: [
              DictionaryEntry(
                writtenRep: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                sense: 'A ${_getWordType(text)} meaning "${translatedText}" in $targetLanguage',
                transList: translatedText,
                pos: _getWordType(text),
                pronunciation: _generatePronunciation(text),
                examples: 'Example: The word "$text" is commonly used in everyday conversation.',
                sourceDictionary: 'Enhanced Mock Dictionary v2.0',
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
            providerId: source == TranslationSource.mlKit ? 'ml_kit_enhanced' : 'server_translate_api',
            latencyMs: latency,
          ),
        );
      }
    } else {
      response = TranslationResponse.error(
        request: request,
        error: _generateErrorMessage(sourceLanguage, targetLanguage, text),
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
    } else if (text.length < 100) {
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
      return _random.nextInt(40) + 10; // 10-50ms for dictionary
    } else if (text.length < 100) {
      return _random.nextInt(200) + 150; // 150-350ms for ML Kit
    } else {
      return _random.nextInt(800) + 400; // 400-1200ms for server
    }
  }

  bool _shouldSucceed(String text, String source, String target) {
    if (source.startsWith('unsupported') || target.startsWith('unsupported')) {
      return false;
    }
    if (text.trim().isEmpty) {
      return false;
    }
    return true; // 100% success for demonstration
  }

  String _mockTranslate(String text, String source, String target, TranslationSource provider) {
    final langKey = '${source}_$target';
    
    // For single words, try to use realistic translations
    if (_isSingleWord(text) && _translations.containsKey(langKey)) {
      final translation = _translations[langKey]![text.toLowerCase()];
      if (translation != null) {
        return translation;
      }
    }
    
    // For sentences and unknown words, generate mock translations
    if (provider == TranslationSource.dictionary) {
      return _translations[langKey]?[text.toLowerCase()] ?? '${target.toUpperCase()}: $text';
    } else {
      return _generateSentenceTranslation(text, target, provider);
    }
  }

  String _generateSentenceTranslation(String text, String target, TranslationSource provider) {
    final providerPrefix = provider == TranslationSource.mlKit ? 'MLKit' : 'GoogleTranslate';
    
    // Simulate more realistic sentence translations
    final words = text.split(' ');
    final translatedWords = words.map((word) {
      // Remove punctuation for lookup
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final langKey = 'en_$target';
      
      if (_translations.containsKey(langKey) && _translations[langKey]!.containsKey(cleanWord)) {
        final translation = _translations[langKey]![cleanWord]!;
        // Preserve original capitalization and punctuation
        if (word != cleanWord) {
          return word.replaceFirst(cleanWord, translation);
        }
        return translation;
      }
      return '${target.toUpperCase()}($word)';
    }).join(' ');
    
    return '[$providerPrefix-$target] $translatedWords';
  }

  String _getWordType(String word) {
    final verbs = ['translate', 'learn', 'read', 'study', 'communicate'];
    final nouns = ['book', 'computer', 'friend', 'journey', 'knowledge', 'world'];
    final adjectives = ['beautiful', 'happy', 'smart', 'quick'];
    
    if (verbs.contains(word.toLowerCase())) return 'verb';
    if (nouns.contains(word.toLowerCase())) return 'noun';
    if (adjectives.contains(word.toLowerCase())) return 'adjective';
    return 'noun'; // default
  }

  String _generatePronunciation(String word) {
    // Simple mock pronunciation
    return '/${word.toLowerCase().replaceAll(RegExp(r'[aeiou]'), 'ə')}/';
  }

  String _generateErrorMessage(String source, String target, String text) {
    if (source.startsWith('unsupported')) {
      return 'Unsupported source language: $source. Available languages: en, es, fr, de, it';
    }
    if (target.startsWith('unsupported')) {
      return 'Unsupported target language: $target. Available languages: en, es, fr, de, it';
    }
    if (text.trim().isEmpty) {
      return 'Cannot translate empty text. Please provide valid input text.';
    }
    if (text.length > 2000) {
      return 'Text too long (${text.length} characters). Maximum supported length is 2000 characters.';
    }
    return 'Translation failed due to unknown error';
  }
}