// Part-of-Speech Emoji Mapping
// Visual indicators for different word types in minimal translation popup

class PartOfSpeechEmojis {
  // Core part-of-speech emoji mappings
  static const Map<String, String> _emojiMap = {
    // Nouns - box/container for things and objects
    'noun': '📦',
    'n': '📦',
    
    // Verbs - lightning for actions and movement
    'verb': '⚡',
    'v': '⚡',
    
    // Adjectives - palette for descriptive qualities
    'adjective': '🎨',
    'adj': '🎨',
    'a': '🎨',
    
    // Adverbs - cycle for manner/way/how
    'adverb': '🔄',
    'adv': '🔄',
    
    // Prepositions - link for relationships
    'preposition': '🔗',
    'prep': '🔗',
    
    // Conjunctions - handshake for connections
    'conjunction': '🤝',
    'conj': '🤝',
    
    // Pronouns - person for personal references
    'pronoun': '👤',
    'pron': '👤',
    
    // Interjections - exclamation for emotions
    'interjection': '❗',
    'inter': '❗',
    'interj': '❗',
    
    // Articles - tag for determiners
    'article': '🏷️',
    'art': '🏷️',
    
    // Determiners - tag for specification
    'determiner': '🏷️',
    'det': '🏷️',
    
    // Numbers - hash symbol for numeric values
    'number': '#️⃣',
    'num': '#️⃣',
    'numeral': '#️⃣',
    
    // Auxiliary verbs - gear for helper actions
    'auxiliary': '⚙️',
    'aux': '⚙️',
    
    // Modal verbs - scales for possibility/necessity
    'modal': '⚖️',
    'mod': '⚖️',
    
    // Particles - dot for small function words
    'particle': '🔸',
    'part': '🔸',
    
    // Phrases - bracket for multi-word expressions
    'phrase': '📋',
    'phr': '📋',
    
    // Abbreviations - document for shortened forms
    'abbreviation': '📄',
    'abbr': '📄',
    'abbrev': '📄',
  };
  
  // Language-specific variations
  static const Map<String, Map<String, String>> _languageSpecificMappings = {
    // Spanish specific terms
    'es': {
      'sustantivo': '📦',  // noun
      'verbo': '⚡',       // verb
      'adjetivo': '🎨',    // adjective
      'adverbio': '🔄',    // adverb
      'preposición': '🔗', // preposition
      'conjunción': '🤝',  // conjunction
      'pronombre': '👤',   // pronoun
      'artículo': '🏷️',   // article
      'interjección': '❗', // interjection
    },
    
    // French specific terms
    'fr': {
      'nom': '📦',         // noun
      'verbe': '⚡',       // verb
      'adjectif': '🎨',    // adjective
      'adverbe': '🔄',     // adverb
      'préposition': '🔗', // preposition
      'conjonction': '🤝', // conjunction
      'pronom': '👤',      // pronoun
      'article': '🏷️',    // article
      'interjection': '❗', // interjection
    },
    
    // German specific terms
    'de': {
      'substantiv': '📦',  // noun
      'nomen': '📦',       // noun
      'verb': '⚡',        // verb
      'adjektiv': '🎨',    // adjective
      'adverb': '🔄',      // adverb
      'präposition': '🔗', // preposition
      'konjunktion': '🤝', // conjunction
      'pronomen': '👤',    // pronoun
      'artikel': '🏷️',    // article
      'interjektion': '❗', // interjection
    },
  };
  
  /// Get emoji for a part-of-speech string
  /// Handles multiple formats and languages
  static String getEmojiForPOS(String? partOfSpeech, {String? language}) {
    if (partOfSpeech == null || partOfSpeech.trim().isEmpty) {
      return '💭'; // Default thought bubble for unknown/missing POS
    }
    
    final pos = partOfSpeech.toLowerCase().trim();
    
    // First check language-specific mappings if language is provided
    if (language != null && _languageSpecificMappings.containsKey(language)) {
      final languageMap = _languageSpecificMappings[language]!;
      if (languageMap.containsKey(pos)) {
        return languageMap[pos]!;
      }
    }
    
    // Check main emoji map
    if (_emojiMap.containsKey(pos)) {
      return _emojiMap[pos]!;
    }
    
    // Try partial matches for complex POS tags (e.g., "noun phrase" -> "noun")
    for (final entry in _emojiMap.entries) {
      if (pos.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Try partial matches in language-specific mappings
    if (language != null && _languageSpecificMappings.containsKey(language)) {
      final languageMap = _languageSpecificMappings[language]!;
      for (final entry in languageMap.entries) {
        if (pos.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    
    // Default for unrecognized part-of-speech
    return '💭'; // Thought bubble for unknown
  }
  
  /// Get a description of what the emoji represents
  static String getEmojiDescription(String emoji) {
    switch (emoji) {
      case '📦': return 'Noun (thing/object)';
      case '⚡': return 'Verb (action)';
      case '🎨': return 'Adjective (description)';
      case '🔄': return 'Adverb (manner)';
      case '🔗': return 'Preposition (relationship)';
      case '🤝': return 'Conjunction (connection)';
      case '👤': return 'Pronoun (person reference)';
      case '❗': return 'Interjection (emotion)';
      case '🏷️': return 'Article/Determiner (specification)';
      case '#️⃣': return 'Number (numeric value)';
      case '⚙️': return 'Auxiliary verb (helper)';
      case '⚖️': return 'Modal verb (possibility)';
      case '🔸': return 'Particle (function word)';
      case '📋': return 'Phrase (multi-word expression)';
      case '📄': return 'Abbreviation (shortened form)';
      case '💭': return 'Unknown word type';
      default: return 'Word type indicator';
    }
  }
  
  /// Check if emoji represents a content word (as opposed to function word)
  static bool isContentWord(String emoji) {
    return ['📦', '⚡', '🎨', '🔄', '#️⃣'].contains(emoji);
  }
  
  /// Check if emoji represents a function word
  static bool isFunctionWord(String emoji) {
    return ['🔗', '🤝', '👤', '🏷️', '⚙️', '⚖️', '🔸'].contains(emoji);
  }
  
  /// Get all available emojis for testing/reference
  static Map<String, String> getAllEmojis() {
    return Map.from(_emojiMap);
  }
  
  /// Get language-specific mappings for testing/reference
  static Map<String, Map<String, String>> getLanguageSpecificMappings() {
    return Map.from(_languageSpecificMappings);
  }
}