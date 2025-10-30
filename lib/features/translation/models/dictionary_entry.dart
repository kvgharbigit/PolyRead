// Dictionary Entry model for modern Wiktionary format
// Uses unified schema: written_rep, sense, trans_list, pos

class DictionaryEntry {
  final int? id;
  final String writtenRep;        // Modern: headword/lemma (Wiktionary standard)
  final String sourceLanguage;    // Modern: source language code
  final String targetLanguage;    // Modern: target language code  
  final String? sense;            // Modern: definition/meaning description
  final String transList;         // Modern: pipe-separated translations
  final String? pos;              // Modern: part of speech
  final String? pronunciation;
  final String? examples;         // Modern: JSON array of example sentences
  final String sourceDictionary;
  final DateTime createdAt;
  
  const DictionaryEntry({
    this.id,
    required this.writtenRep,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.sense,
    required this.transList,
    this.pos,
    this.pronunciation,
    this.examples,
    required this.sourceDictionary,
    required this.createdAt,
  });
  
  /// Create DictionaryEntry from modern Wiktionary database map
  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      id: map['id'] as int?,
      writtenRep: map['written_rep'] as String,
      sourceLanguage: map['source_language'] as String,
      targetLanguage: map['target_language'] as String,
      sense: map['sense'] as String?,
      transList: map['trans_list'] as String,
      pos: map['pos'] as String?,
      pronunciation: map['pronunciation'] as String?,
      examples: map['examples'] as String?,
      sourceDictionary: map['source'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
  
  /// Convert DictionaryEntry to modern Wiktionary database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'written_rep': writtenRep.toLowerCase(),
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'sense': sense,
      'trans_list': transList,
      'pos': pos,
      'pronunciation': pronunciation,
      'examples': examples,
      'source': sourceDictionary,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
  
  /// Create a copy with updated fields
  DictionaryEntry copyWith({
    int? id,
    String? writtenRep,
    String? sourceLanguage,
    String? targetLanguage,
    String? sense,
    String? transList,
    String? pos,
    String? pronunciation,
    String? examples,
    String? sourceDictionary,
    DateTime? createdAt,
  }) {
    return DictionaryEntry(
      id: id ?? this.id,
      writtenRep: writtenRep ?? this.writtenRep,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      sense: sense ?? this.sense,
      transList: transList ?? this.transList,
      pos: pos ?? this.pos,
      pronunciation: pronunciation ?? this.pronunciation,
      examples: examples ?? this.examples,
      sourceDictionary: sourceDictionary ?? this.sourceDictionary,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DictionaryEntry &&
        other.writtenRep == writtenRep &&
        other.sourceLanguage == sourceLanguage &&
        other.targetLanguage == targetLanguage &&
        other.transList == transList &&
        other.sourceDictionary == sourceDictionary;
  }
  
  @override
  int get hashCode {
    return writtenRep.hashCode ^ 
           sourceLanguage.hashCode ^ 
           targetLanguage.hashCode ^
           transList.hashCode ^
           sourceDictionary.hashCode;
  }
  
  @override
  String toString() {
    return 'DictionaryEntry(writtenRep: $writtenRep, ${sourceLanguage}→${targetLanguage}, transList: $transList, source: $sourceDictionary)';
  }
}

/// Represents the result of a dictionary lookup
class DictionaryLookupResult {
  final String query;
  final String sourceLanguage;  // Modern: explicit source language
  final String targetLanguage;  // Modern: explicit target language
  final List<DictionaryEntry> entries;
  final int latencyMs;
  final bool fromCache;
  
  const DictionaryLookupResult({
    required this.query,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.entries,
    required this.latencyMs,
    this.fromCache = false,
  });
  
  bool get hasResults => entries.isNotEmpty;
  int get resultCount => entries.length;
  
  /// Get the best (first) result
  DictionaryEntry? get bestResult => entries.isNotEmpty ? entries.first : null;
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'entries': entries.map((e) => e.toMap()).toList(),
      'latencyMs': latencyMs,
      'fromCache': fromCache,
    };
  }
  
  /// Create from JSON
  factory DictionaryLookupResult.fromJson(Map<String, dynamic> json) {
    return DictionaryLookupResult(
      query: json['query'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      entries: (json['entries'] as List<dynamic>)
          .map((e) => DictionaryEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      latencyMs: json['latencyMs'] as int? ?? 0,
      fromCache: json['fromCache'] as bool? ?? false,
    );
  }
}