// Dictionary Entry model for SQLite storage
// Represents a single word definition with metadata

class DictionaryEntry {
  final int? id;
  final String word;
  final String language;
  final String definition;
  final String? pronunciation;
  final String? partOfSpeech;
  final String? exampleSentence;
  final String sourceDictionary;
  final DateTime createdAt;
  
  const DictionaryEntry({
    this.id,
    required this.word,
    required this.language,
    required this.definition,
    this.pronunciation,
    this.partOfSpeech,
    this.exampleSentence,
    required this.sourceDictionary,
    required this.createdAt,
  });
  
  /// Create DictionaryEntry from database map
  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      id: map['id'] as int?,
      word: map['word'] as String,
      language: map['language'] as String,
      definition: map['definition'] as String,
      pronunciation: map['pronunciation'] as String?,
      partOfSpeech: map['part_of_speech'] as String?,
      exampleSentence: map['example_sentence'] as String?,
      sourceDictionary: map['source_dictionary'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
  
  /// Convert DictionaryEntry to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word.toLowerCase(),
      'language': language,
      'definition': definition,
      'pronunciation': pronunciation,
      'part_of_speech': partOfSpeech,
      'example_sentence': exampleSentence,
      'source_dictionary': sourceDictionary,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
  
  /// Create a copy with updated fields
  DictionaryEntry copyWith({
    int? id,
    String? word,
    String? language,
    String? definition,
    String? pronunciation,
    String? partOfSpeech,
    String? exampleSentence,
    String? sourceDictionary,
    DateTime? createdAt,
  }) {
    return DictionaryEntry(
      id: id ?? this.id,
      word: word ?? this.word,
      language: language ?? this.language,
      definition: definition ?? this.definition,
      pronunciation: pronunciation ?? this.pronunciation,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      sourceDictionary: sourceDictionary ?? this.sourceDictionary,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DictionaryEntry &&
        other.word == word &&
        other.language == language &&
        other.definition == definition &&
        other.sourceDictionary == sourceDictionary;
  }
  
  @override
  int get hashCode {
    return word.hashCode ^ 
           language.hashCode ^ 
           definition.hashCode ^ 
           sourceDictionary.hashCode;
  }
  
  @override
  String toString() {
    return 'DictionaryEntry(word: $word, language: $language, definition: $definition, source: $sourceDictionary)';
  }
}

/// Represents the result of a dictionary lookup
class DictionaryLookupResult {
  final String query;
  final String language;
  final List<DictionaryEntry> entries;
  final int latencyMs;
  final bool fromCache;
  
  const DictionaryLookupResult({
    required this.query,
    required this.language,
    required this.entries,
    required this.latencyMs,
    this.fromCache = false,
  });
  
  bool get hasResults => entries.isNotEmpty;
  int get resultCount => entries.length;
  
  /// Get the best (first) result
  DictionaryEntry? get bestResult => entries.isNotEmpty ? entries.first : null;
}