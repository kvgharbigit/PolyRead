// Bookmark Model
// Data model for bookmarks with UI support

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';

enum BookmarkColor {
  blue,
  red,
  yellow,
  green,
  purple,
  orange,
  pink,
  gray,
}

enum BookmarkIcon {
  bookmark,
  star,
  flag,
  note,
  highlight,
  pin,
  heart,
  lightbulb,
}

extension BookmarkColorExtension on BookmarkColor {
  Color get color {
    switch (this) {
      case BookmarkColor.blue:
        return Colors.blue;
      case BookmarkColor.red:
        return Colors.red;
      case BookmarkColor.yellow:
        return Colors.amber;
      case BookmarkColor.green:
        return Colors.green;
      case BookmarkColor.purple:
        return Colors.purple;
      case BookmarkColor.orange:
        return Colors.orange;
      case BookmarkColor.pink:
        return Colors.pink;
      case BookmarkColor.gray:
        return Colors.grey;
    }
  }
  
  String get displayName {
    switch (this) {
      case BookmarkColor.blue:
        return 'Blue';
      case BookmarkColor.red:
        return 'Red';
      case BookmarkColor.yellow:
        return 'Yellow';
      case BookmarkColor.green:
        return 'Green';
      case BookmarkColor.purple:
        return 'Purple';
      case BookmarkColor.orange:
        return 'Orange';
      case BookmarkColor.pink:
        return 'Pink';
      case BookmarkColor.gray:
        return 'Gray';
    }
  }
  
  static BookmarkColor fromString(String value) {
    return BookmarkColor.values.firstWhere(
      (color) => color.name == value,
      orElse: () => BookmarkColor.blue,
    );
  }
}

extension BookmarkIconExtension on BookmarkIcon {
  IconData get iconData {
    switch (this) {
      case BookmarkIcon.bookmark:
        return Icons.bookmark;
      case BookmarkIcon.star:
        return Icons.star;
      case BookmarkIcon.flag:
        return Icons.flag;
      case BookmarkIcon.note:
        return Icons.note;
      case BookmarkIcon.highlight:
        return Icons.highlight;
      case BookmarkIcon.pin:
        return Icons.push_pin;
      case BookmarkIcon.heart:
        return Icons.favorite;
      case BookmarkIcon.lightbulb:
        return Icons.lightbulb;
    }
  }
  
  String get displayName {
    switch (this) {
      case BookmarkIcon.bookmark:
        return 'Bookmark';
      case BookmarkIcon.star:
        return 'Star';
      case BookmarkIcon.flag:
        return 'Flag';
      case BookmarkIcon.note:
        return 'Note';
      case BookmarkIcon.highlight:
        return 'Highlight';
      case BookmarkIcon.pin:
        return 'Pin';
      case BookmarkIcon.heart:
        return 'Heart';
      case BookmarkIcon.lightbulb:
        return 'Idea';
    }
  }
  
  static BookmarkIcon fromString(String value) {
    return BookmarkIcon.values.firstWhere(
      (icon) => icon.name == value,
      orElse: () => BookmarkIcon.bookmark,
    );
  }
}

class BookmarkModel {
  final int id;
  final int bookId;
  final ReaderPosition position;
  final String? title;
  final String? note;
  final String? excerpt;
  final BookmarkColor color;
  final BookmarkIcon icon;
  final DateTime createdAt;
  final DateTime? lastAccessedAt;
  final bool isQuickBookmark;
  final int sortOrder;
  
  const BookmarkModel({
    required this.id,
    required this.bookId,
    required this.position,
    this.title,
    this.note,
    this.excerpt,
    required this.color,
    required this.icon,
    required this.createdAt,
    this.lastAccessedAt,
    required this.isQuickBookmark,
    required this.sortOrder,
  });
  
  /// Create from Drift database row
  /// TODO: Implement when Bookmarks table is properly configured in Drift
  /*
  factory BookmarkModel.fromDrift(Bookmark row) {
    return BookmarkModel(
      id: row.id,
      bookId: row.bookId,
      position: ReaderPosition.fromJsonString(row.position),
      title: row.title,
      note: row.note,
      excerpt: row.excerpt,
      color: BookmarkColorExtension.fromString(row.color),
      icon: BookmarkIconExtension.fromString(row.icon),
      createdAt: row.createdAt,
      lastAccessedAt: row.lastAccessedAt,
      isQuickBookmark: row.isQuickBookmark,
      sortOrder: row.sortOrder,
    );
  }
  */
  
  /// Create a copy with modified values
  BookmarkModel copyWith({
    int? id,
    int? bookId,
    ReaderPosition? position,
    String? title,
    String? note,
    String? excerpt,
    BookmarkColor? color,
    BookmarkIcon? icon,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    bool? isQuickBookmark,
    int? sortOrder,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      position: position ?? this.position,
      title: title ?? this.title,
      note: note ?? this.note,
      excerpt: excerpt ?? this.excerpt,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      isQuickBookmark: isQuickBookmark ?? this.isQuickBookmark,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
  
  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'position': position.toJson(),
      'title': title,
      'note': note,
      'excerpt': excerpt,
      'color': color.name,
      'icon': icon.name,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      'isQuickBookmark': isQuickBookmark,
      'sortOrder': sortOrder,
    };
  }
  
  /// Create from JSON for import
  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'] as int,
      bookId: json['bookId'] as int,
      position: ReaderPosition.fromJson(json['position']),
      title: json['title'] as String?,
      note: json['note'] as String?,
      excerpt: json['excerpt'] as String?,
      color: BookmarkColorExtension.fromString(json['color'] as String),
      icon: BookmarkIconExtension.fromString(json['icon'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.parse(json['lastAccessedAt'] as String)
          : null,
      isQuickBookmark: json['isQuickBookmark'] as bool,
      sortOrder: json['sortOrder'] as int,
    );
  }
  
  /// Get display title (with fallback)
  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    
    if (position.pageNumber != null) {
      return 'Page ${position.pageNumber}';
    } else if (position.chapterId != null) {
      return position.chapterId!;
    } else {
      return 'Bookmark';
    }
  }
  
  /// Get position description for UI
  String get positionDescription {
    return position.toString();
  }
  
  /// Get formatted creation date
  String get formattedDate {
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
  
  /// Check if bookmark has note
  bool get hasNote => note != null && note!.isNotEmpty;
  
  /// Check if bookmark has excerpt
  bool get hasExcerpt => excerpt != null && excerpt!.isNotEmpty;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is BookmarkModel &&
        other.id == id &&
        other.bookId == bookId &&
        other.position == position;
  }
  
  @override
  int get hashCode {
    return Object.hash(id, bookId, position);
  }
  
  @override
  String toString() {
    return 'BookmarkModel(id: $id, title: $displayTitle, position: $position)';
  }
}

// Extension for ReaderPosition JSON serialization
extension ReaderPositionExtension on ReaderPosition {
  String toJsonString() {
    return jsonEncode(toJson());
  }
  
  static ReaderPosition fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return ReaderPosition.fromJson(json);
  }
}