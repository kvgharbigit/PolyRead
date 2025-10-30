import 'dart:math';

// Simplified quality check that doesn't depend on Flutter test framework
void main() {
  final service = MockTranslationService();
  
  print('=== TRANSLATION QUALITY EXAMPLES ===\n');
  
  // Word-level examples
  print('📝 WORD-LEVEL TRANSLATIONS:');
  final words = ['hello', 'book', 'beautiful', 'computer', 'café', 'résumé'];
  
  for (final word in words) {
    final result = service.translateWord(word, 'en', 'es');
    print('  • "$word" → "${result.translation}" (${result.source})');
    print('    Sense: ${result.definition}');
    print('    Latency: ${result.latency}ms\n');
  }
  
  // Sentence-level examples
  print('📚 SENTENCE-LEVEL TRANSLATIONS:');
  final sentences = [
    'Hello, how are you today?',
    'I am learning a new language.',
    'Technology is changing the world rapidly.',
    'Can you help me translate this sentence?',
  ];
  
  for (final sentence in sentences) {
    final result = service.translateSentence(sentence, 'en', 'fr');
    print('  • Original: "$sentence"');
    print('    Translation: "${result.translation}" (${result.source})');
    print('    Latency: ${result.latency}ms\n');
  }
  
  // Complex text examples
  print('🔧 COMPLEX TEXT TRANSLATIONS:');
  final complexText = 'Machine translation has revolutionized how we communicate across language barriers. Modern neural networks enable accurate translations.';
  final result = service.translateSentence(complexText, 'en', 'de');
  print('  • Original (${complexText.length} chars): "$complexText"');
  print('    Translation: "${result.translation}" (${result.source})');
  print('    Latency: ${result.latency}ms\n');
  
  // Performance comparison
  print('⚡ PERFORMANCE COMPARISON:');
  final testText = 'This text will demonstrate caching performance.';
  
  final first = service.translateSentence(testText, 'en', 'es');
  print('  • First translation: ${first.latency}ms (not cached)');
  
  final second = service.translateSentenceFromCache(testText, 'en', 'es');
  print('  • Second translation: ${second.latency}ms (cached)');
  print('    Performance improvement: ${((first.latency - second.latency) / first.latency * 100).toStringAsFixed(1)}%\n');
  
  // Error handling examples
  print('🛡️ ERROR HANDLING:');
  final errorCases = [
    ('', 'Empty text'),
    ('   ', 'Whitespace only'),
    ('word ' * 100, 'Very long text'),
  ];
  
  for (final (text, description) in errorCases) {
    final result = service.translateWithErrors(text, 'en', 'es');
    print('  • $description: ${result.success ? "Success" : "Failed"}');
    if (!result.success) {
      print('    Error: ${result.error}');
    }
    print('');
  }
}

class TranslationResult {
  final String translation;
  final String source;
  final int latency;
  final String? definition;
  final bool success;
  final String? error;
  
  TranslationResult({
    required this.translation,
    required this.source,
    required this.latency,
    this.definition,
    this.success = true,
    this.error,
  });
}

class MockTranslationService {
  final Random _random = Random(42);
  final Map<String, String> _cache = {};
  
  final Map<String, Map<String, String>> _translations = {
    'en_es': {
      'hello': 'hola',
      'book': 'libro',
      'beautiful': 'hermoso',
      'computer': 'computadora',
      'café': 'café',
      'résumé': 'currículum',
    },
    'en_fr': {
      'hello': 'bonjour',
      'book': 'livre',
      'beautiful': 'beau',
      'computer': 'ordinateur',
    },
    'en_de': {
      'hello': 'hallo',
      'book': 'buch',
      'beautiful': 'schön',
      'computer': 'computer',
    },
  };
  
  TranslationResult translateWord(String word, String source, String target) {
    final langKey = '${source}_$target';
    final translation = _translations[langKey]?[word.toLowerCase()] ?? '${target.toUpperCase()}($word)';
    
    return TranslationResult(
      translation: translation,
      source: 'Dictionary',
      latency: _random.nextInt(40) + 10,
      definition: 'A ${_getWordType(word)} meaning "$translation" in $target language. Used in everyday conversation and formal writing.',
    );
  }
  
  TranslationResult translateSentence(String sentence, String source, String target) {
    final words = sentence.split(' ');
    final langKey = '${source}_$target';
    
    final translatedWords = words.map((word) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final translation = _translations[langKey]?[cleanWord];
      
      if (translation != null) {
        return word.replaceFirst(cleanWord, translation);
      }
      return '${target.toUpperCase()}($cleanWord)';
    }).join(' ');
    
    final provider = sentence.length < 100 ? 'ML Kit' : 'Google Translate';
    final latency = sentence.length < 100 ? 
        _random.nextInt(200) + 150 : 
        _random.nextInt(800) + 400;
        
    return TranslationResult(
      translation: '[$provider] $translatedWords',
      source: provider,
      latency: latency,
    );
  }
  
  TranslationResult translateSentenceFromCache(String sentence, String source, String target) {
    return TranslationResult(
      translation: _cache['$sentence$source$target'] ?? 'Cached translation of: $sentence',
      source: 'Cache',
      latency: _random.nextInt(5) + 1, // Very fast cache lookup
    );
  }
  
  TranslationResult translateWithErrors(String text, String source, String target) {
    if (text.trim().isEmpty) {
      return TranslationResult(
        translation: '',
        source: 'Error',
        latency: 0,
        success: false,
        error: 'Cannot translate empty text',
      );
    }
    
    if (text.length > 2000) {
      return TranslationResult(
        translation: '',
        source: 'Error',
        latency: 0,
        success: false,
        error: 'Text too long (${text.length} characters). Maximum: 2000',
      );
    }
    
    return translateSentence(text, source, target);
  }
  
  String _getWordType(String word) {
    final verbs = ['translate', 'learn', 'read'];
    final nouns = ['book', 'computer', 'café', 'résumé'];
    final adjectives = ['beautiful', 'hello'];
    
    if (verbs.contains(word.toLowerCase())) return 'verb';
    if (nouns.contains(word.toLowerCase())) return 'noun';
    if (adjectives.contains(word.toLowerCase())) return 'adjective';
    return 'noun';
  }
}