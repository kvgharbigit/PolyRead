// Dictionary Link Service
// Provides bidirectional dictionary URLs for any source→home language pair

class DictionaryLinkService {
  // Language code mapping for dictionary services
  static const Map<String, String> _languageCodes = {
    'english': 'en',
    'spanish': 'es', 
    'french': 'fr',
    'german': 'de',
    'italian': 'it',
    'portuguese': 'pt',
    'russian': 'ru',
    'arabic': 'ar',
    'japanese': 'ja',
    'korean': 'ko',
    'chinese': 'zh',
    'dutch': 'nl',
    'polish': 'pl',
    'turkish': 'tr',
    'hindi': 'hi',
    'swedish': 'sv',
    'norwegian': 'no',
    'danish': 'da',
    'finnish': 'fi',
    'greek': 'el',
    'hebrew': 'he',
    'thai': 'th',
    'vietnamese': 'vi',
    'czech': 'cs',
    'hungarian': 'hu',
    'romanian': 'ro',
    'bulgarian': 'bg',
    'croatian': 'hr',
    'slovak': 'sk',
    'slovenian': 'sl',
    'estonian': 'et',
    'latvian': 'lv',
    'lithuanian': 'lt',
    'ukrainian': 'uk',
  };

  /// Get the best dictionary URL for a word from source language to home language
  static String getDictionaryUrl(String word, String sourceLanguage, String homeLanguage) {
    final encodedWord = Uri.encodeComponent(word.trim());
    final source = _normalizeLanguageCode(sourceLanguage);
    final target = _normalizeLanguageCode(homeLanguage);
    
    // WordReference - best quality for supported pairs
    if (_isWordReferenceSupported(source, target)) {
      return 'https://www.wordreference.com/$source$target/translation.asp?spen=$encodedWord';
    }
    
    // Reverso Context - excellent for European languages with context
    if (_isReversoSupported(source, target)) {
      return 'https://context.reverso.net/translation/$source-$target/$encodedWord';
    }
    
    // Google Translate - universal fallback
    return 'https://translate.google.com/?sl=$source&tl=$target&text=$encodedWord&op=translate';
  }

  /// Check if WordReference supports the language pair
  static bool _isWordReferenceSupported(String source, String target) {
    // WordReference's most comprehensive language pair coverage
    final supportedPairs = <String, List<String>>{
      'en': ['es', 'fr', 'it', 'de', 'pt', 'ru', 'ja', 'ko', 'ar', 'zh', 'nl', 'pl', 'ro', 'cs', 'gr', 'tr'],
      'es': ['en', 'fr', 'it', 'pt', 'ca', 'gl', 'eu'],
      'fr': ['en', 'es', 'it', 'de', 'pt', 'nl', 'pl', 'ro', 'cs'],
      'it': ['en', 'es', 'fr', 'de', 'pt', 'ro'],
      'de': ['en', 'es', 'fr', 'it', 'pt', 'pl', 'ru'],
      'pt': ['en', 'es', 'fr', 'it', 'de'],
      'ru': ['en', 'de', 'fr', 'it', 'es'],
      'ja': ['en'],
      'ko': ['en'],
      'ar': ['en'],
      'zh': ['en'],
      'nl': ['en', 'fr', 'de'],
      'pl': ['en', 'de', 'fr'],
    };
    
    return supportedPairs[source]?.contains(target) ?? false;
  }

  /// Check if Reverso Context supports the language pair
  static bool _isReversoSupported(String source, String target) {
    // Reverso's supported languages (strong European coverage)
    final supportedLanguages = {
      'en', 'es', 'fr', 'it', 'de', 'pt', 'ru', 'ar', 'ja', 'ko', 'zh',
      'nl', 'pl', 'tr', 'he', 'ro', 'cs', 'hu', 'bg', 'sv', 'da', 'no',
      'fi', 'el', 'uk'
    };
    
    return supportedLanguages.contains(source) && 
           supportedLanguages.contains(target) &&
           source != target;
  }

  /// Normalize language code to ISO 639-1 format
  static String _normalizeLanguageCode(String language) {
    final normalized = language.toLowerCase().trim();
    
    // Direct ISO code
    if (normalized.length == 2) {
      return normalized;
    }
    
    // Full language name lookup
    return _languageCodes[normalized] ?? normalized;
  }

  /// Get dictionary service name for the given language pair
  static String getDictionaryServiceName(String sourceLanguage, String homeLanguage) {
    final source = _normalizeLanguageCode(sourceLanguage);
    final target = _normalizeLanguageCode(homeLanguage);
    
    if (_isWordReferenceSupported(source, target)) {
      return 'WordReference';
    } else if (_isReversoSupported(source, target)) {
      return 'Reverso Context';
    } else {
      return 'Google Translate';
    }
  }

  /// Check if dictionary link is available for the language pair
  static bool isDictionaryAvailable(String sourceLanguage, String homeLanguage) {
    final source = _normalizeLanguageCode(sourceLanguage);
    final target = _normalizeLanguageCode(homeLanguage);
    
    // Always available via Google Translate fallback
    return source.isNotEmpty && target.isNotEmpty && source != target;
  }

  /// Get all supported language codes
  static Set<String> getSupportedLanguageCodes() {
    return _languageCodes.values.toSet();
  }

  /// Get language name from code
  static String getLanguageName(String languageCode) {
    final code = _normalizeLanguageCode(languageCode);
    
    const codeToName = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French', 
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ar': 'Arabic',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'nl': 'Dutch',
      'pl': 'Polish',
      'tr': 'Turkish',
      'hi': 'Hindi',
      'sv': 'Swedish',
      'no': 'Norwegian',
      'da': 'Danish',
      'fi': 'Finnish',
      'el': 'Greek',
      'he': 'Hebrew',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'cs': 'Czech',
      'hu': 'Hungarian',
      'ro': 'Romanian',
      'bg': 'Bulgarian',
      'hr': 'Croatian',
      'sk': 'Slovak',
      'sl': 'Slovenian',
      'et': 'Estonian',
      'lv': 'Latvian',
      'lt': 'Lithuanian',
      'uk': 'Ukrainian',
    };
    
    return codeToName[code] ?? code.toUpperCase();
  }
}