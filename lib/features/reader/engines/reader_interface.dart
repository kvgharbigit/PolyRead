// Reader Interface
// Common interface for PDF and EPUB readers

import 'dart:convert';
import 'package:flutter/material.dart';

abstract class ReaderEngine {
  /// Initialize the reader with a book file
  Future<void> initialize(String filePath);
  
  /// Dispose of resources
  Future<void> dispose();
  
  /// Get the total number of pages/chapters
  int get totalPages;
  
  /// Get current reading position
  ReaderPosition get currentPosition;
  
  /// Navigate to a specific position
  Future<void> goToPosition(ReaderPosition position);
  
  /// Navigate to next page/chapter
  Future<bool> goToNext();
  
  /// Navigate to previous page/chapter  
  Future<bool> goToPrevious();
  
  /// Get text at current position for translation
  String? getSelectedText();
  
  /// Get reading progress as percentage (0.0 - 1.0)
  double get progress;
  
  /// Build the reader widget
  Widget buildReader(BuildContext context);
  
  /// Handle text selection
  void onTextSelected(String selectedText, Offset position);
  
  /// Search for text in the document
  Future<List<SearchResult>> search(String query);
}

/// Reading position that works for both PDF and EPUB
class ReaderPosition {
  final int? pageNumber;      // For PDFs
  final String? chapterId;    // For EPUBs
  final String? anchor;       // For EPUB anchors
  final double? scrollOffset; // For precise positioning
  
  const ReaderPosition({
    this.pageNumber,
    this.chapterId,
    this.anchor,
    this.scrollOffset,
  });
  
  /// Create position for PDF
  ReaderPosition.pdf(int page) : 
    pageNumber = page,
    chapterId = null,
    anchor = null,
    scrollOffset = null;
  
  /// Create position for EPUB
  ReaderPosition.epub(String chapter, {String? anchor, double? offset}) :
    pageNumber = null,
    chapterId = chapter,
    anchor = anchor,
    scrollOffset = offset;
  
  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'chapterId': chapterId,
      'anchor': anchor,
      'scrollOffset': scrollOffset,
    };
  }
  
  /// Create from JSON
  factory ReaderPosition.fromJson(Map<String, dynamic> json) {
    return ReaderPosition(
      pageNumber: json['pageNumber'],
      chapterId: json['chapterId'],
      anchor: json['anchor'],
      scrollOffset: json['scrollOffset'],
    );
  }
  
  /// Create from JSON string
  factory ReaderPosition.fromJsonString(String jsonString) {
    final json = Map<String, dynamic>.from(
      jsonDecode(jsonString) as Map<String, dynamic>
    );
    return ReaderPosition.fromJson(json);
  }
  
  @override
  String toString() {
    if (pageNumber != null) {
      return 'Page $pageNumber';
    } else if (chapterId != null) {
      return 'Chapter $chapterId${anchor != null ? ' #$anchor' : ''}';
    }
    return 'Unknown position';
  }
}

/// Search result in document
class SearchResult {
  final String text;
  final ReaderPosition position;
  final String context; // Surrounding text
  
  const SearchResult({
    required this.text,
    required this.position,
    required this.context,
  });
}

/// Text selection data for translation
class ReaderTextSelection {
  final String text;
  final ReaderPosition position;
  final Rect bounds;
  final DateTime timestamp;
  
  const ReaderTextSelection({
    required this.text,
    required this.position,
    required this.bounds,
    required this.timestamp,
  });
}