// Bidirectional Dictionary Entry Models
// Supports two-level structure: meanings → synonyms

class BidirectionalDictionaryEntry {
  final String lemma;
  final List<MeaningGroup> meanings;
  final String direction; // 'forward' or 'reverse'
  final String sourceLanguage;
  final String targetLanguage;

  const BidirectionalDictionaryEntry({
    required this.lemma,
    required this.meanings,
    required this.direction,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  factory BidirectionalDictionaryEntry.fromDatabase({
    required String lemma,
    required String definition,
    required String direction,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    final meanings = _parseDefinition(definition);
    return BidirectionalDictionaryEntry(
      lemma: lemma,
      meanings: meanings,
      direction: direction,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  static List<MeaningGroup> _parseDefinition(String definition) {
    List<MeaningGroup> meanings = [];
    
    // Handle different formats
    if (definition.contains('|')) {
      // Pipe-separated format: "context1: syn1, syn2 | context2: syn1, syn2"
      meanings = _parsePipeFormat(definition);
    } else if (definition.contains(';')) {
      // Legacy format: "syn1; syn2; syn3"
      meanings = [MeaningGroup(
        context: 'general',
        synonyms: definition.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      )];
    } else {
      // Single meaning
      meanings = [MeaningGroup(
        context: 'general',
        synonyms: [definition.trim()],
      )];
    }
    
    return meanings;
  }

  static List<MeaningGroup> _parsePipeFormat(String definition) {
    List<MeaningGroup> meanings = [];
    
    // Split by | for different meanings
    List<String> meaningParts = definition.split('|');
    
    for (String part in meaningParts) {
      part = part.trim();
      if (part.isEmpty) continue;
      
      if (part.contains(':')) {
        // Context: synonyms format
        List<String> contextAndSynonyms = part.split(':');
        if (contextAndSynonyms.length >= 2) {
          String context = contextAndSynonyms[0].trim();
          String synonymsStr = contextAndSynonyms.sublist(1).join(':').trim();
          
          List<String> synonyms = synonymsStr
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          
          if (synonyms.isNotEmpty) {
            meanings.add(MeaningGroup(context: context, synonyms: synonyms));
          }
        }
      } else {
        // No context, treat as general synonyms
        List<String> synonyms = part
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        
        if (synonyms.isNotEmpty) {
          meanings.add(MeaningGroup(context: 'general', synonyms: synonyms));
        }
      }
    }
    
    return meanings;
  }

  /// Get all synonyms across all meanings (for simple display)
  List<String> get allSynonyms {
    return meanings.expand((meaning) => meaning.synonyms).toList();
  }

  /// Get formatted display text
  String get displayText {
    if (meanings.length == 1 && meanings[0].context == 'general') {
      // Simple format for single meaning
      return meanings[0].synonyms.join(', ');
    } else {
      // Context-aware format
      return meanings.map((meaning) {
        if (meaning.context == 'general') {
          return meaning.synonyms.join(', ');
        } else {
          return '${meaning.context}: ${meaning.synonyms.join(', ')}';
        }
      }).join(' • ');
    }
  }

  /// Check if this entry matches a search query
  bool matches(String query) {
    query = query.toLowerCase().trim();
    return lemma.toLowerCase().contains(query) ||
           allSynonyms.any((syn) => syn.toLowerCase().contains(query));
  }
}

class MeaningGroup {
  final String context;     // "movement", "operate", "general", etc.
  final List<String> synonyms;

  const MeaningGroup({
    required this.context,
    required this.synonyms,
  });

  @override
  String toString() => '$context: ${synonyms.join(', ')}';
}

/// Dictionary lookup result with both directions
class BidirectionalLookupResult {
  final String query;
  final BidirectionalDictionaryEntry? forwardEntry;  // source → target
  final BidirectionalDictionaryEntry? reverseEntry;  // target → source
  final String sourceLanguage;
  final String targetLanguage;

  const BidirectionalLookupResult({
    required this.query,
    this.forwardEntry,
    this.reverseEntry,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  bool get hasResults => forwardEntry != null || reverseEntry != null;
  
  BidirectionalDictionaryEntry? get primaryEntry => forwardEntry ?? reverseEntry;
  
  /// Get the most relevant entry based on query language
  BidirectionalDictionaryEntry? getRelevantEntry(String queryLanguage) {
    if (queryLanguage == sourceLanguage) {
      return forwardEntry; // Query in source, show target
    } else if (queryLanguage == targetLanguage) {
      return reverseEntry; // Query in target, show source
    } else {
      return primaryEntry; // Fallback to any available
    }
  }
}