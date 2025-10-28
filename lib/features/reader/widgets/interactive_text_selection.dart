// Interactive Text Selection Widget
// Enables word-level touch detection for translation

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class InteractiveTextSelection extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final Function(String word, Offset position, TextSelection selection)? onWordTap;
  final Function(String sentence, Offset position, TextSelection selection)? onSentenceTap;
  final Color? highlightColor;
  final bool enableWordSelection;
  final bool enableSentenceSelection;
  
  const InteractiveTextSelection({
    super.key,
    required this.text,
    this.textStyle,
    this.onWordTap,
    this.onSentenceTap,
    this.highlightColor,
    this.enableWordSelection = true,
    this.enableSentenceSelection = true,
  });

  @override
  State<InteractiveTextSelection> createState() => _InteractiveTextSelectionState();
}

class _InteractiveTextSelectionState extends State<InteractiveTextSelection> {
  final GlobalKey _textKey = GlobalKey();
  String? _highlightedWord;
  TextSelection? _currentSelection;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onLongPress: _handleLongPress,
      child: Container(
        key: _textKey,
        child: RichText(
          text: _buildTextSpan(),
        ),
      ),
    );
  }
  
  TextSpan _buildTextSpan() {
    final words = _tokenizeText(widget.text);
    final spans = <TextSpan>[];
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isHighlighted = _highlightedWord == word.text;
      
      spans.add(TextSpan(
        text: word.text,
        style: (widget.textStyle ?? const TextStyle()).copyWith(
          backgroundColor: isHighlighted 
              ? (widget.highlightColor ?? Colors.yellow.withOpacity(0.3))
              : null,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _handleWordTap(word, i),
      ));
    }
    
    return TextSpan(children: spans);
  }
  
  void _handleTapDown(TapDownDetails details) {
    if (!widget.enableWordSelection) return;
    
    final renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final word = _getWordAtPosition(localPosition);
    
    if (word != null) {
      setState(() {
        _highlightedWord = word.text;
      });
      
      // Clear highlight after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _highlightedWord = null;
          });
        }
      });
    }
  }
  
  void _handleLongPress() {
    if (!widget.enableSentenceSelection) return;
    
    // For long press, select the entire sentence or paragraph
    final sentence = _extractSentence(widget.text, 0); // Simplified implementation
    if (sentence.isNotEmpty && widget.onSentenceTap != null) {
      widget.onSentenceTap!(
        sentence,
        Offset.zero, // TODO: Calculate actual position
        TextSelection(baseOffset: 0, extentOffset: sentence.length),
      );
    }
  }
  
  void _handleWordTap(TextToken word, int wordIndex) {
    if (!widget.enableWordSelection || widget.onWordTap == null) return;
    
    // Calculate position and selection
    final position = _calculateWordPosition(word, wordIndex);
    final selection = TextSelection(
      baseOffset: word.startIndex,
      extentOffset: word.endIndex,
    );
    
    widget.onWordTap!(word.text, position, selection);
  }
  
  List<TextToken> _tokenizeText(String text) {
    final tokens = <TextToken>[];
    final words = text.split(RegExp(r'(\s+|[,.!?;:()"\-])+'));
    int currentIndex = 0;
    
    for (final word in words) {
      if (word.trim().isNotEmpty) {
        // Find the actual position in the original text
        final startIndex = text.indexOf(word, currentIndex);
        if (startIndex != -1) {
          tokens.add(TextToken(
            text: word,
            startIndex: startIndex,
            endIndex: startIndex + word.length,
          ));
          currentIndex = startIndex + word.length;
        }
      }
    }
    
    return tokens;
  }
  
  TextToken? _getWordAtPosition(Offset localPosition) {
    // This is a simplified implementation
    // In a real scenario, you'd need to calculate text layout and positioning
    final words = _tokenizeText(widget.text);
    
    // For now, return the first word as a placeholder
    // TODO: Implement proper hit testing based on text layout
    return words.isNotEmpty ? words.first : null;
  }
  
  Offset _calculateWordPosition(TextToken word, int wordIndex) {
    // Simplified position calculation
    // TODO: Implement proper text measurement and positioning
    return Offset(wordIndex * 50.0, 0); // Placeholder calculation
  }
  
  String _extractSentence(String text, int position) {
    // Simple sentence extraction based on punctuation
    final sentences = text.split(RegExp(r'[.!?]+\s*'));
    return sentences.isNotEmpty ? sentences.first.trim() : '';
  }
}

class TextToken {
  final String text;
  final int startIndex;
  final int endIndex;
  
  const TextToken({
    required this.text,
    required this.startIndex,
    required this.endIndex,
  });
  
  bool get isWord => text.trim().isNotEmpty && !RegExp(r'^[^\w]+$').hasMatch(text);
  
  @override
  String toString() => 'TextToken(text: "$text", start: $startIndex, end: $endIndex)';
}

// Enhanced text selection widget for better word detection
class AdvancedInteractiveText extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final Function(String word, Offset position, TextSelection selection)? onWordTap;
  final Function(String sentence, Offset position, TextSelection selection)? onSentenceTap;
  final TextAlign textAlign;
  final int? maxLines;
  
  const AdvancedInteractiveText({
    super.key,
    required this.text,
    this.textStyle,
    this.onWordTap,
    this.onSentenceTap,
    this.textAlign = TextAlign.start,
    this.maxLines,
  });

  @override
  State<AdvancedInteractiveText> createState() => _AdvancedInteractiveTextState();
}

class _AdvancedInteractiveTextState extends State<AdvancedInteractiveText> {
  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _buildSelectableTextSpan(),
      style: widget.textStyle,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      onSelectionChanged: _handleSelectionChanged,
    );
  }
  
  TextSpan _buildSelectableTextSpan() {
    // Split text into words and create tappable spans
    final words = widget.text.split(RegExp(r'(\s+)'));
    final spans = <TextSpan>[];
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      
      if (word.trim().isEmpty) {
        // Whitespace
        spans.add(TextSpan(text: word));
      } else {
        // Word - make it tappable
        spans.add(TextSpan(
          text: word,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleWordTap(word, i),
        ));
      }
    }
    
    return TextSpan(children: spans);
  }
  
  void _handleWordTap(String word, int index) {
    if (widget.onWordTap == null) return;
    
    // Calculate approximate position
    final position = Offset(index * 20.0, 0); // Simplified
    final selection = TextSelection(
      baseOffset: 0,
      extentOffset: word.length,
    );
    
    widget.onWordTap!(word, position, selection);
  }
  
  void _handleSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    if (cause == SelectionChangedCause.longPress && widget.onSentenceTap != null) {
      final selectedText = widget.text.substring(selection.start, selection.end);
      if (selectedText.isNotEmpty) {
        widget.onSentenceTap!(
          selectedText,
          Offset.zero, // TODO: Calculate actual position
          selection,
        );
      }
    }
  }
}