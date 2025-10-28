// Vocabulary Item Model for Drift integration
// Enhanced model that works with AppDatabase

import 'package:polyread/core/database/app_database.dart';

class VocabularyItemModel {
  final int id;
  final int bookId;
  final String sourceText;
  final String translation;
  final String sourceLanguage;
  final String targetLanguage;
  final String? context;
  final String? bookPosition;
  final int reviewCount;
  final double difficulty;
  final DateTime? nextReview;
  final DateTime? lastReviewed;
  final DateTime createdAt;
  final bool isFavorite;
  
  const VocabularyItemModel({
    required this.id,
    required this.bookId,
    required this.sourceText,
    required this.translation,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.context,
    this.bookPosition,
    required this.reviewCount,
    required this.difficulty,
    this.nextReview,
    this.lastReviewed,
    required this.createdAt,
    required this.isFavorite,
  });
  
  /// Create from Drift database row
  factory VocabularyItemModel.fromDrift(VocabularyItem row) {
    return VocabularyItemModel(
      id: row.id,
      bookId: row.bookId,
      sourceText: row.sourceText,
      translation: row.translation,
      sourceLanguage: row.sourceLanguage,
      targetLanguage: row.targetLanguage,
      context: row.context,
      bookPosition: row.bookPosition,
      reviewCount: row.reviewCount,
      difficulty: row.difficulty,
      nextReview: row.nextReview,
      lastReviewed: row.lastReviewed,
      createdAt: row.createdAt,
      isFavorite: row.isFavorite,
    );
  }
  
  /// Create a copy with modified values
  VocabularyItemModel copyWith({
    int? id,
    int? bookId,
    String? sourceText,
    String? translation,
    String? sourceLanguage,
    String? targetLanguage,
    String? context,
    String? bookPosition,
    int? reviewCount,
    double? difficulty,
    DateTime? nextReview,
    DateTime? lastReviewed,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return VocabularyItemModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      sourceText: sourceText ?? this.sourceText,
      translation: translation ?? this.translation,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      context: context ?? this.context,
      bookPosition: bookPosition ?? this.bookPosition,
      reviewCount: reviewCount ?? this.reviewCount,
      difficulty: difficulty ?? this.difficulty,
      nextReview: nextReview ?? this.nextReview,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
  
  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'sourceText': sourceText,
      'translation': translation,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'context': context,
      'bookPosition': bookPosition,
      'reviewCount': reviewCount,
      'difficulty': difficulty,
      'nextReview': nextReview?.toIso8601String(),
      'lastReviewed': lastReviewed?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }
  
  /// Create from JSON for import
  factory VocabularyItemModel.fromJson(Map<String, dynamic> json) {
    return VocabularyItemModel(
      id: json['id'] as int,
      bookId: json['bookId'] as int,
      sourceText: json['sourceText'] as String,
      translation: json['translation'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      context: json['context'] as String?,
      bookPosition: json['bookPosition'] as String?,
      reviewCount: json['reviewCount'] as int,
      difficulty: (json['difficulty'] as num).toDouble(),
      nextReview: json['nextReview'] != null 
          ? DateTime.parse(json['nextReview'] as String)
          : null,
      lastReviewed: json['lastReviewed'] != null 
          ? DateTime.parse(json['lastReviewed'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isFavorite: json['isFavorite'] as bool,
    );
  }
  
  /// Check if item is due for review
  bool get isDueForReview {
    if (nextReview == null) return true;
    return DateTime.now().isAfter(nextReview!);
  }
  
  /// Check if item is mastered (high difficulty + multiple reviews)
  bool get isMastered {
    return reviewCount >= 5 && difficulty > 2.8;
  }
  
  /// Get mastery level as percentage
  double get masteryPercentage {
    if (reviewCount == 0) return 0.0;
    
    // Base mastery on review count and difficulty
    final reviewProgress = (reviewCount / 10).clamp(0.0, 1.0);
    final difficultyProgress = ((difficulty - 1.3) / (4.0 - 1.3)).clamp(0.0, 1.0);
    
    return ((reviewProgress + difficultyProgress) / 2 * 100).clamp(0.0, 100.0);
  }
  
  /// Get difficulty level description
  String get difficultyDescription {
    if (difficulty < 2.0) return 'Very Hard';
    if (difficulty < 2.5) return 'Hard';
    if (difficulty < 3.0) return 'Medium';
    if (difficulty < 3.5) return 'Easy';
    return 'Very Easy';
  }
  
  /// Get next review description
  String get nextReviewDescription {
    if (nextReview == null) return 'Ready now';
    
    final now = DateTime.now();
    final difference = nextReview!.difference(now);
    
    if (difference.isNegative) {
      final ago = now.difference(nextReview!);
      if (ago.inDays > 0) {
        return '${ago.inDays} day${ago.inDays == 1 ? '' : 's'} overdue';
      } else if (ago.inHours > 0) {
        return '${ago.inHours} hour${ago.inHours == 1 ? '' : 's'} overdue';
      } else {
        return 'Ready now';
      }
    } else {
      if (difference.inDays > 0) {
        return 'In ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
      } else if (difference.inHours > 0) {
        return 'In ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
      } else {
        return 'Ready now';
      }
    }
  }
  
  /// Get formatted creation date
  String get formattedCreatedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is VocabularyItemModel &&
        other.id == id &&
        other.sourceText == sourceText &&
        other.sourceLanguage == sourceLanguage &&
        other.targetLanguage == targetLanguage;
  }
  
  @override
  int get hashCode {
    return Object.hash(id, sourceText, sourceLanguage, targetLanguage);
  }
  
  @override
  String toString() {
    return 'VocabularyItemModel(id: $id, sourceText: $sourceText, translation: $translation)';
  }
}