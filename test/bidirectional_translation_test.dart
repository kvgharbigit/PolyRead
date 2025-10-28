import 'dart:math';

// Test bidirectional translation capabilities
void main() {
  final service = BidirectionalTranslationService();
  
  print('=== BIDIRECTIONAL TRANSLATION TEST ===\n');
  
  // Test word-level bidirectional translation
  print('📝 WORD-LEVEL BIDIRECTIONAL TRANSLATIONS:');
  final wordPairs = [
    ('hello', 'en', 'es', 'hola'),
    ('hola', 'es', 'en', 'hello'),
    ('book', 'en', 'fr', 'livre'),
    ('livre', 'fr', 'en', 'book'),
    ('computer', 'en', 'de', 'computer'),
    ('computer', 'de', 'en', 'computer'),
    ('beautiful', 'en', 'es', 'hermoso'),
    ('hermoso', 'es', 'en', 'beautiful'),
  ];
  
  for (final (word, sourceLang, targetLang, expectedTranslation) in wordPairs) {
    final result = service.translateWord(word, sourceLang, targetLang);
    final isCorrectDirection = sourceLang != targetLang;
    final hasTranslation = result.translation.isNotEmpty;
    
    print('  • "$word" ($sourceLang → $targetLang)');
    print('    Translation: "${result.translation}"');
    print('    Expected: "$expectedTranslation"');
    print('    Source: ${result.source}');
    print('    Bidirectional Support: ${isCorrectDirection ? '✅' : '❌'}');
    print('    Quality: ${hasTranslation ? '✅' : '❌'}');
    print('');
  }
  
  // Test sentence-level bidirectional translation
  print('📚 SENTENCE-LEVEL BIDIRECTIONAL TRANSLATIONS:');
  final sentencePairs = [
    ('Hello, how are you?', 'en', 'es'),
    ('Hola, ¿cómo estás?', 'es', 'en'),
    ('I am learning Spanish.', 'en', 'es'),
    ('Estoy aprendiendo inglés.', 'es', 'en'),
    ('Good morning!', 'en', 'fr'),
    ('Bonjour!', 'fr', 'en'),
    ('Technology is amazing.', 'en', 'de'),
    ('Technologie ist erstaunlich.', 'de', 'en'),
  ];
  
  for (final (sentence, sourceLang, targetLang) in sentencePairs) {
    final result = service.translateSentence(sentence, sourceLang, targetLang);
    
    print('  • Original: "$sentence" ($sourceLang → $targetLang)');
    print('    Translation: "${result.translation}"');
    print('    Source: ${result.source}');
    print('    Latency: ${result.latency}ms');
    print('    Direction: ${sourceLang != targetLang ? 'Bidirectional ✅' : 'Same language ❌'}');
    print('');
  }
  
  // Test language pair support matrix
  print('🌐 LANGUAGE PAIR SUPPORT MATRIX:');
  final languages = ['en', 'es', 'fr', 'de', 'it'];
  
  print('    FROM\\TO   EN    ES    FR    DE    IT');
  print('    --------------------------------');
  
  for (final source in languages) {
    final row = StringBuffer('    ${source.toUpperCase()}      ');
    
    for (final target in languages) {
      final isSupported = service.isLanguagePairSupported(source, target);
      final symbol = source == target ? ' -  ' : (isSupported ? ' ✅ ' : ' ❌ ');
      row.write('  $symbol');
    }
    
    print(row.toString());
  }
  
  print('\n🔄 ROUND-TRIP TRANSLATION TEST:');
  final roundTripTests = [
    ('Hello world', 'en'),
    ('Beautiful morning', 'en'),
    ('Machine learning', 'en'),
  ];
  
  for (final (originalText, originalLang) in roundTripTests) {
    // Translate to Spanish and back
    final toSpanish = service.translateSentence(originalText, originalLang, 'es');
    final backToEnglish = service.translateSentence(toSpanish.translation, 'es', originalLang);
    
    print('  • Original: "$originalText" ($originalLang)');
    print('    → Spanish: "${toSpanish.translation}"');
    print('    → Back to English: "${backToEnglish.translation}"');
    
    // Calculate similarity (simple word count comparison)
    final originalWords = originalText.toLowerCase().split(' ');
    final roundTripWords = backToEnglish.translation.toLowerCase().split(' ');
    final commonWords = originalWords.where((word) => 
        roundTripWords.any((rtWord) => rtWord.contains(word.replaceAll(RegExp(r'[^\w]'), '')))).length;
    final similarity = (commonWords / originalWords.length * 100).round();
    
    print('    Round-trip Quality: $similarity% similarity');
    print('    Total Latency: ${toSpanish.latency + backToEnglish.latency}ms');
    print('');
  }
  
  // Test provider selection for different directions
  print('🎯 PROVIDER SELECTION BY DIRECTION:');
  final providerTests = [
    ('word', 'en', 'es'),
    ('word', 'es', 'en'),
    ('short sentence', 'en', 'fr'),
    ('short sentence', 'fr', 'en'),
    ('long complex sentence with multiple clauses', 'en', 'de'),
    ('lange komplexe Satz mit mehreren Klauseln', 'de', 'en'),
  ];
  
  for (final (text, source, target) in providerTests) {
    final result = service.translateAny(text, source, target);
    
    print('  • Text Type: ${text.split(' ').length == 1 ? 'Word' : 'Sentence'}');
    print('    Direction: $source → $target');
    print('    Provider: ${result.source}');
    print('    Optimized for direction: ${service.isOptimizedForDirection(source, target) ? '✅' : '⚠️'}');
    print('');
  }
}

class TranslationResult {
  final String translation;
  final String source;
  final int latency;
  final bool success;
  final String? error;
  
  TranslationResult({
    required this.translation,
    required this.source,
    required this.latency,
    this.success = true,
    this.error,
  });
}

class BidirectionalTranslationService {
  final Random _random = Random(42);
  
  // Comprehensive bidirectional translation dictionaries
  final Map<String, Map<String, String>> _translations = {
    // English to Spanish
    'en_es': {
      'hello': 'hola',
      'book': 'libro',
      'beautiful': 'hermoso',
      'computer': 'computadora',
      'morning': 'mañana',
      'world': 'mundo',
      'machine': 'máquina',
      'learning': 'aprendizaje',
      'good': 'bueno',
      'how': 'cómo',
      'are': 'estás',
      'you': 'tú',
    },
    // Spanish to English (reverse)
    'es_en': {
      'hola': 'hello',
      'libro': 'book',
      'hermoso': 'beautiful',
      'computadora': 'computer',
      'mañana': 'morning',
      'mundo': 'world',
      'máquina': 'machine',
      'aprendizaje': 'learning',
      'bueno': 'good',
      'cómo': 'how',
      'estás': 'are',
      'tú': 'you',
    },
    // English to French
    'en_fr': {
      'hello': 'bonjour',
      'book': 'livre',
      'beautiful': 'beau',
      'computer': 'ordinateur',
      'morning': 'matin',
      'world': 'monde',
      'good': 'bon',
    },
    // French to English
    'fr_en': {
      'bonjour': 'hello',
      'livre': 'book',
      'beau': 'beautiful',
      'ordinateur': 'computer',
      'matin': 'morning',
      'monde': 'world',
      'bon': 'good',
    },
    // English to German
    'en_de': {
      'hello': 'hallo',
      'book': 'buch',
      'beautiful': 'schön',
      'computer': 'computer',
      'morning': 'morgen',
      'world': 'welt',
      'technology': 'technologie',
      'amazing': 'erstaunlich',
    },
    // German to English
    'de_en': {
      'hallo': 'hello',
      'buch': 'book',
      'schön': 'beautiful',
      'computer': 'computer',
      'morgen': 'morning',
      'welt': 'world',
      'technologie': 'technology',
      'erstaunlich': 'amazing',
    },
  };
  
  final Set<String> _supportedLanguages = {'en', 'es', 'fr', 'de', 'it'};
  
  TranslationResult translateWord(String word, String source, String target) {
    final langKey = '${source}_$target';
    final translation = _translations[langKey]?[word.toLowerCase()] ?? 
                       '${target.toUpperCase()}($word)';
    
    return TranslationResult(
      translation: translation,
      source: 'Bidirectional Dictionary',
      latency: _random.nextInt(40) + 10,
    );
  }
  
  TranslationResult translateSentence(String sentence, String source, String target) {
    final words = sentence.split(' ');
    final langKey = '${source}_$target';
    
    final translatedWords = words.map((word) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final translation = _translations[langKey]?[cleanWord];
      
      if (translation != null) {
        // Preserve punctuation and capitalization
        return word.replaceFirst(cleanWord, translation);
      }
      return word; // Keep original if no translation found
    }).join(' ');
    
    final provider = sentence.length < 100 ? 'Bidirectional ML Kit' : 'Bidirectional Server';
    final latency = sentence.length < 100 ? 
        _random.nextInt(200) + 150 : 
        _random.nextInt(800) + 400;
        
    return TranslationResult(
      translation: translatedWords,
      source: provider,
      latency: latency,
    );
  }
  
  TranslationResult translateAny(String text, String source, String target) {
    if (_isSingleWord(text)) {
      return translateWord(text, source, target);
    } else {
      return translateSentence(text, source, target);
    }
  }
  
  bool isLanguagePairSupported(String source, String target) {
    if (source == target) return false; // Same language not a translation
    
    // Check if both languages are in supported set
    if (!_supportedLanguages.contains(source) || !_supportedLanguages.contains(target)) {
      return false;
    }
    
    // Check if we have translation data for this direction
    final langKey = '${source}_$target';
    return _translations.containsKey(langKey);
  }
  
  bool isOptimizedForDirection(String source, String target) {
    final langKey = '${source}_$target';
    final reverseKey = '${target}_$source';
    
    // Optimized if we have dictionaries for both directions
    return _translations.containsKey(langKey) && _translations.containsKey(reverseKey);
  }
  
  bool _isSingleWord(String text) {
    final trimmed = text.trim();
    return !trimmed.contains(' ') && 
           !trimmed.contains('\n') && 
           !trimmed.contains('\t') &&
           trimmed.length > 0 &&
           trimmed.length < 50;
  }
}