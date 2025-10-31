// Text Selection Types for Reader Interface
// Distinguishes between different selection modes for appropriate translation handling

import 'package:flutter/material.dart';

enum TextSelectionType {
  /// Single word selection via tap (traditional dictionary lookup)
  word,
  
  /// Sentence selection via long press (full sentence translation)
  sentence,
  
  /// Manual text selection (user-highlighted text)
  manual,
}

/// Text selection data with type information
class TextSelectionData {
  final String text;
  final TextSelectionType type;
  final Offset position;
  final String? context; // Surrounding text for improved translation
  
  const TextSelectionData({
    required this.text,
    required this.type,
    required this.position,
    this.context,
  });
  
  /// Whether this is a single word selection
  bool get isWord => type == TextSelectionType.word;
  
  /// Whether this is a sentence selection
  bool get isSentence => type == TextSelectionType.sentence;
  
  /// Whether this is a manual selection
  bool get isManual => type == TextSelectionType.manual;
}