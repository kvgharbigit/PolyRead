// Vocabulary Item - Represents a word/phrase saved for learning
// Includes SRS data, translation context, and learning statistics

class VocabularyItem {
  final int? id;
  final String word;
  final String sourceLanguage;
  final String targetLanguage;
  final String translation;
  final String? definition;
  final String? context;
  final String? bookTitle;
  final String? bookLocation;
  final DateTime createdAt;
  final DateTime lastReviewed;
  final SRSData srsData;
  final List<String> tags;
  final VocabularyStatus status;
  
  const VocabularyItem({
    this.id,
    required this.word,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translation,
    this.definition,
    this.context,
    this.bookTitle,
    this.bookLocation,
    required this.createdAt,
    required this.lastReviewed,
    required this.srsData,
    this.tags = const [],
    this.status = VocabularyStatus.learning,
  });
  
  /// Create from translation result
  factory VocabularyItem.fromTranslation({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
    required String translation,
    String? definition,
    String? context,
    String? bookTitle,
    String? bookLocation,
    List<String> tags = const [],
  }) {
    final now = DateTime.now();
    return VocabularyItem(
      word: word,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      translation: translation,
      definition: definition,
      context: context,
      bookTitle: bookTitle,
      bookLocation: bookLocation,
      createdAt: now,
      lastReviewed: now,
      srsData: SRSData.initial(),
      tags: tags,
      status: VocabularyStatus.learning,
    );
  }
  
  /// Create from database map
  factory VocabularyItem.fromMap(Map<String, dynamic> map) {
    return VocabularyItem(
      id: map['id'] as int?,
      word: map['word'] as String,
      sourceLanguage: map['source_language'] as String,
      targetLanguage: map['target_language'] as String,
      translation: map['translation'] as String,
      definition: map['definition'] as String?,
      context: map['context'] as String?,
      bookTitle: map['book_title'] as String?,
      bookLocation: map['book_location'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastReviewed: DateTime.fromMillisecondsSinceEpoch(map['last_reviewed'] as int),
      srsData: SRSData.fromMap(map),
      tags: (map['tags'] as String?)?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
      status: VocabularyStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => VocabularyStatus.learning,
      ),
    );
  }
  
  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'translation': translation,
      'definition': definition,
      'context': context,
      'book_title': bookTitle,
      'book_location': bookLocation,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_reviewed': lastReviewed.millisecondsSinceEpoch,
      'tags': tags.join(','),
      'status': status.name,
      ...srsData.toMap(),
    };
  }
  
  /// Create copy with updated fields
  VocabularyItem copyWith({
    int? id,
    String? word,
    String? sourceLanguage,
    String? targetLanguage,
    String? translation,
    String? definition,
    String? context,
    String? bookTitle,
    String? bookLocation,
    DateTime? createdAt,
    DateTime? lastReviewed,
    SRSData? srsData,
    List<String>? tags,
    VocabularyStatus? status,
  }) {
    return VocabularyItem(
      id: id ?? this.id,
      word: word ?? this.word,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      translation: translation ?? this.translation,
      definition: definition ?? this.definition,
      context: context ?? this.context,
      bookTitle: bookTitle ?? this.bookTitle,
      bookLocation: bookLocation ?? this.bookLocation,
      createdAt: createdAt ?? this.createdAt,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      srsData: srsData ?? this.srsData,
      tags: tags ?? this.tags,
      status: status ?? this.status,
    );
  }
  
  /// Check if due for review
  bool get isDueForReview {
    return DateTime.now().isAfter(srsData.nextReviewDate);
  }
  
  /// Get difficulty level based on SRS data
  DifficultyLevel get difficultyLevel {
    if (srsData.lapses >= 3) return DifficultyLevel.hard;
    if (srsData.interval >= 30) return DifficultyLevel.easy;
    if (srsData.interval >= 7) return DifficultyLevel.medium;
    return DifficultyLevel.learning;
  }
  
  /// Get mastery percentage (0-100)
  double get masteryPercentage {
    // Simple mastery calculation based on interval and success rate
    final maxInterval = 365; // 1 year
    final intervalScore = (srsData.interval / maxInterval).clamp(0.0, 1.0);
    final successScore = srsData.successRate;
    return ((intervalScore * 0.6 + successScore * 0.4) * 100).clamp(0.0, 100.0);
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VocabularyItem &&
        other.word == word &&
        other.sourceLanguage == sourceLanguage &&
        other.targetLanguage == targetLanguage;
  }
  
  @override
  int get hashCode {
    return word.hashCode ^ sourceLanguage.hashCode ^ targetLanguage.hashCode;
  }
}

/// SRS (Spaced Repetition System) data for a vocabulary item
class SRSData {
  final int repetitions;
  final double easinessFactor;
  final int interval;
  final int lapses;
  final DateTime nextReviewDate;
  final int totalReviews;
  final int correctReviews;
  
  const SRSData({
    required this.repetitions,
    required this.easinessFactor,
    required this.interval,
    required this.lapses,
    required this.nextReviewDate,
    required this.totalReviews,
    required this.correctReviews,
  });
  
  /// Create initial SRS data for new item
  factory SRSData.initial() {
    return SRSData(
      repetitions: 0,
      easinessFactor: 2.5,
      interval: 1,
      lapses: 0,
      nextReviewDate: DateTime.now(),
      totalReviews: 0,
      correctReviews: 0,
    );
  }
  
  /// Create from database map
  factory SRSData.fromMap(Map<String, dynamic> map) {
    return SRSData(
      repetitions: map['srs_repetitions'] as int? ?? 0,
      easinessFactor: (map['srs_easiness_factor'] as num?)?.toDouble() ?? 2.5,
      interval: map['srs_interval'] as int? ?? 1,
      lapses: map['srs_lapses'] as int? ?? 0,
      nextReviewDate: DateTime.fromMillisecondsSinceEpoch(
        map['srs_next_review'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      totalReviews: map['srs_total_reviews'] as int? ?? 0,
      correctReviews: map['srs_correct_reviews'] as int? ?? 0,
    );
  }
  
  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'srs_repetitions': repetitions,
      'srs_easiness_factor': easinessFactor,
      'srs_interval': interval,
      'srs_lapses': lapses,
      'srs_next_review': nextReviewDate.millisecondsSinceEpoch,
      'srs_total_reviews': totalReviews,
      'srs_correct_reviews': correctReviews,
    };
  }
  
  /// Calculate next SRS data based on review result
  SRSData updateFromReview(ReviewResult result) {
    final newTotalReviews = totalReviews + 1;
    final newCorrectReviews = correctReviews + (result.correct ? 1 : 0);
    
    // SM-2 Algorithm implementation
    double newEasinessFactor = easinessFactor;
    int newInterval = interval;
    int newRepetitions = repetitions;
    int newLapses = lapses;
    
    if (result.correct) {
      if (repetitions == 0) {
        newInterval = 1;
      } else if (repetitions == 1) {
        newInterval = 6;
      } else {
        newInterval = (interval * easinessFactor).round();
      }
      newRepetitions++;
    } else {
      newRepetitions = 0;
      newInterval = 1;
      newLapses++;
    }
    
    // Update easiness factor based on quality (0-5 scale)
    final quality = result.quality ?? (result.correct ? 4 : 2);
    newEasinessFactor = easinessFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    newEasinessFactor = newEasinessFactor.clamp(1.3, 2.5);
    
    final nextReview = DateTime.now().add(Duration(days: newInterval));
    
    return SRSData(
      repetitions: newRepetitions,
      easinessFactor: newEasinessFactor,
      interval: newInterval,
      lapses: newLapses,
      nextReviewDate: nextReview,
      totalReviews: newTotalReviews,
      correctReviews: newCorrectReviews,
    );
  }
  
  /// Get success rate (0.0 - 1.0)
  double get successRate {
    return totalReviews > 0 ? correctReviews / totalReviews : 0.0;
  }
  
  /// Check if item is mature (reviewed multiple times successfully)
  bool get isMature {
    return repetitions >= 3 && interval >= 21;
  }
}

/// Review result for SRS calculation
class ReviewResult {
  final bool correct;
  final int? quality; // 0-5 scale (optional, for more precise SRS)
  final Duration? responseTime;
  final DateTime timestamp;
  
  const ReviewResult({
    required this.correct,
    this.quality,
    this.responseTime,
    required this.timestamp,
  });
  
  factory ReviewResult.correct({int? quality, Duration? responseTime}) {
    return ReviewResult(
      correct: true,
      quality: quality,
      responseTime: responseTime,
      timestamp: DateTime.now(),
    );
  }
  
  factory ReviewResult.incorrect({int? quality, Duration? responseTime}) {
    return ReviewResult(
      correct: false,
      quality: quality,
      responseTime: responseTime,
      timestamp: DateTime.now(),
    );
  }
}

enum VocabularyStatus {
  learning,
  mastered,
  suspended,
  buried,
}

enum DifficultyLevel {
  learning,
  easy,
  medium,
  hard,
}