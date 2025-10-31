// Meaning-based dictionary models for cycling + expansion UI
// Supports generalized language pairs with one-level meaning cycling

class MeaningWordGroup {
  final int id;
  final String baseWord;
  final String wordForms;  // pipe-separated: "agua|agüita|aguas"
  final String? partOfSpeech;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime createdAt;

  const MeaningWordGroup({
    required this.id,
    required this.baseWord,
    required this.wordForms,
    this.partOfSpeech,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
  });

  factory MeaningWordGroup.fromMap(Map<String, dynamic> map) {
    return MeaningWordGroup(
      id: map['id'] as int,
      baseWord: map['base_word'] as String,
      wordForms: map['word_forms'] as String,
      partOfSpeech: map['part_of_speech'] as String?,
      sourceLanguage: map['source_language'] as String,
      targetLanguage: map['target_language'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  List<String> get allForms => wordForms.split('|');
}

class MeaningEntry {
  final int id;
  final int wordGroupId;
  final int meaningOrder;
  final String targetMeaning;
  final String? context;
  final String? partOfSpeech;
  final bool isPrimary;
  final DateTime createdAt;

  const MeaningEntry({
    required this.id,
    required this.wordGroupId,
    required this.meaningOrder,
    required this.targetMeaning,
    this.context,
    this.partOfSpeech,
    required this.isPrimary,
    required this.createdAt,
  });

  factory MeaningEntry.fromMap(Map<String, dynamic> map) {
    return MeaningEntry(
      id: map['id'] as int,
      wordGroupId: map['word_group_id'] as int,
      meaningOrder: map['meaning_order'] as int,
      targetMeaning: map['target_meaning'] as String,
      context: map['context'] as String?,
      partOfSpeech: map['part_of_speech'] as String?,
      isPrimary: (map['is_primary'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Get display meaning for UI (short for cycling)
  String get displayMeaning => targetMeaning;

  /// Get expanded meaning for UI (with context)
  String get expandedMeaning {
    if (context != null && context!.isNotEmpty) {
      return '$targetMeaning $context';
    }
    return targetMeaning;
  }

  /// Get part of speech for UI formatting
  String? get posTag => partOfSpeech != null ? '[$partOfSpeech]' : null;
}

class TargetReverseLookupEntry {
  final int id;
  final String targetWord;
  final int sourceWordGroupId;
  final int sourceMeaningId;
  final int lookupOrder;
  final int qualityScore;
  final DateTime createdAt;

  const TargetReverseLookupEntry({
    required this.id,
    required this.targetWord,
    required this.sourceWordGroupId,
    required this.sourceMeaningId,
    required this.lookupOrder,
    required this.qualityScore,
    required this.createdAt,
  });

  factory TargetReverseLookupEntry.fromMap(Map<String, dynamic> map) {
    return TargetReverseLookupEntry(
      id: map['id'] as int,
      targetWord: map['target_word'] as String,
      sourceWordGroupId: map['source_word_group_id'] as int,
      sourceMeaningId: map['source_meaning_id'] as int,
      lookupOrder: map['lookup_order'] as int,
      qualityScore: map['quality_score'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

/// Complete meaning with cycling info for UI
class CyclableMeaning {
  final MeaningWordGroup wordGroup;
  final MeaningEntry meaning;
  final int currentIndex;
  final int totalMeanings;

  const CyclableMeaning({
    required this.wordGroup,
    required this.meaning,
    required this.currentIndex,
    required this.totalMeanings,
  });

  /// Source word (Spanish, French, etc.)
  String get sourceWord => wordGroup.baseWord;

  /// Target translation for cycling display
  String get displayTranslation => meaning.displayMeaning;

  /// Expanded translation with context
  String get expandedTranslation => meaning.expandedMeaning;

  /// Part of speech tag for UI
  String? get partOfSpeechTag => meaning.posTag;

  /// Is this the primary (most common) meaning?
  bool get isPrimary => meaning.isPrimary;

  /// Has next meaning for cycling?
  bool get hasNext => currentIndex < totalMeanings;

  /// Has previous meaning for cycling?
  bool get hasPrevious => currentIndex > 1;

  /// Source → Target language pair
  String get languagePair => '${wordGroup.sourceLanguage}→${wordGroup.targetLanguage}';
}

/// Complete reverse lookup with cycling info for UI
class CyclableReverseLookup {
  final String targetWord;
  final String sourceWord;
  final String sourceMeaning;
  final String? context;
  final String? partOfSpeech;
  final int qualityScore;
  final int currentIndex;
  final int totalTranslations;

  const CyclableReverseLookup({
    required this.targetWord,
    required this.sourceWord,
    required this.sourceMeaning,
    this.context,
    this.partOfSpeech,
    required this.qualityScore,
    required this.currentIndex,
    required this.totalTranslations,
  });

  /// Source word for cycling display
  String get displayTranslation => sourceWord;

  /// Expanded with meaning context
  String get expandedTranslation => '$sourceWord ($sourceMeaning)';

  /// Part of speech tag for UI
  String? get partOfSpeechTag => partOfSpeech != null ? '[$partOfSpeech]' : null;

  /// Quality indicator for UI
  String get qualityIndicator {
    if (qualityScore >= 150) return '★★★';
    if (qualityScore >= 120) return '★★';
    if (qualityScore >= 100) return '★';
    return '';
  }

  /// Has next translation for cycling?
  bool get hasNext => currentIndex < totalTranslations;

  /// Has previous translation for cycling?
  bool get hasPrevious => currentIndex > 1;
}

/// Dictionary lookup result for meaning-based cycling
class MeaningLookupResult {
  final String query;
  final String sourceLanguage;
  final String targetLanguage;
  final List<CyclableMeaning> meanings;
  final int latencyMs;
  final bool fromCache;

  const MeaningLookupResult({
    required this.query,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.meanings,
    required this.latencyMs,
    this.fromCache = false,
  });

  bool get hasResults => meanings.isNotEmpty;
  int get resultCount => meanings.length;
  CyclableMeaning? get primaryMeaning => meanings.isNotEmpty ? meanings.first : null;
}

/// Reverse lookup result for target→source cycling
class ReverseLookupResult {
  final String query;
  final String sourceLanguage;
  final String targetLanguage;
  final List<CyclableReverseLookup> translations;
  final int latencyMs;
  final bool fromCache;

  const ReverseLookupResult({
    required this.query,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translations,
    required this.latencyMs,
    this.fromCache = false,
  });

  bool get hasResults => translations.isNotEmpty;
  int get resultCount => translations.length;
  CyclableReverseLookup? get primaryTranslation => translations.isNotEmpty ? translations.first : null;
}