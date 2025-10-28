// Interactive Text Widget
// Handles word segmentation and tap detection for translation

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

typedef WordTapCallback = void Function(String word, Offset position, TextSelection selection);
typedef SentenceTapCallback = void Function(String sentence, Offset position, TextSelection selection);

class InteractiveText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final WordTapCallback? onWordTap;
  final SentenceTapCallback? onSentenceTap;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool enableSingleTap;
  final bool enableDoubleTap;
  final bool enableLongPress;
  final Duration tapTimeout;

  const InteractiveText({
    super.key,
    required this.text,
    this.style,
    this.onWordTap,
    this.onSentenceTap,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.enableSingleTap = true,
    this.enableDoubleTap = true,
    this.enableLongPress = true,
    this.tapTimeout = const Duration(milliseconds: 300),
  });

  @override
  State<InteractiveText> createState() => _InteractiveTextState();
}

class _InteractiveTextState extends State<InteractiveText> {
  final GlobalKey _textKey = GlobalKey();
  TextPainter? _textPainter;
  List<WordSpan> _wordSpans = [];
  String? _highlightedWord;
  int? _tapCount;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildWordSpans();
    });
  }

  @override
  void didUpdateWidget(InteractiveText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _buildWordSpans();
      });
    }
  }

  void _buildWordSpans() {
    if (!mounted) return;

    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final style = widget.style ?? DefaultTextStyle.of(context).style;
    _textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: widget.maxLines,
    );

    _textPainter!.layout(maxWidth: renderBox.size.width);

    _wordSpans = _extractWordSpans(widget.text);
    setState(() {});
  }

  List<WordSpan> _extractWordSpans(String text) {
    final List<WordSpan> spans = [];
    final RegExp wordRegex = RegExp(r"\b[\w']+\b");
    final matches = wordRegex.allMatches(text);

    for (final match in matches) {
      final word = match.group(0)!;
      final start = match.start;
      final end = match.end;
      
      // Get text selection for the word
      final selection = TextSelection(baseOffset: start, extentOffset: end);
      
      // Calculate word position using text painter
      if (_textPainter != null) {
        final wordPosition = _getWordPosition(start, end);
        spans.add(WordSpan(
          word: word,
          start: start,
          end: end,
          position: wordPosition,
          selection: selection,
        ));
      }
    }

    return spans;
  }

  Offset _getWordPosition(int start, int end) {
    if (_textPainter == null) return Offset.zero;

    final startOffset = _textPainter!.getOffsetForCaret(TextPosition(offset: start), Rect.zero);
    final endOffset = _textPainter!.getOffsetForCaret(TextPosition(offset: end), Rect.zero);

    // Return the center point of the word
    return Offset(
      (startOffset.dx + endOffset.dx) / 2,
      (startOffset.dy + endOffset.dy) / 2,
    );
  }

  String _getSentenceAtPosition(int position) {
    final text = widget.text;
    
    // Find sentence boundaries
    int sentenceStart = 0;
    int sentenceEnd = text.length;

    // Look backwards for sentence start
    for (int i = position; i >= 0; i--) {
      if (RegExp(r'[.!?]\s').hasMatch(text.substring(i, i + 2))) {
        sentenceStart = i + 2;
        break;
      }
    }

    // Look forwards for sentence end
    for (int i = position; i < text.length - 1; i++) {
      if (RegExp(r'[.!?]\s').hasMatch(text.substring(i, i + 2))) {
        sentenceEnd = i + 1;
        break;
      }
    }

    return text.substring(sentenceStart, sentenceEnd).trim();
  }

  void _handleTap(TapUpDetails details) {
    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _textPainter == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final textPosition = _textPainter!.getPositionForOffset(localPosition);
    
    // Find the word at this position
    final WordSpan? wordSpan = _findWordAtPosition(textPosition.offset);
    if (wordSpan == null) return;

    final now = DateTime.now();
    final globalPosition = details.globalPosition;

    // Handle tap timing for single vs double tap
    if (_lastTapTime != null && 
        now.difference(_lastTapTime!) < widget.tapTimeout &&
        _highlightedWord == wordSpan.word) {
      _tapCount = (_tapCount ?? 0) + 1;
    } else {
      _tapCount = 1;
      _highlightedWord = wordSpan.word;
    }
    _lastTapTime = now;

    // Delay to check for double tap
    Future.delayed(widget.tapTimeout, () {
      if (!mounted || _highlightedWord != wordSpan.word) return;

      if (_tapCount == 1 && widget.enableSingleTap && widget.onWordTap != null) {
        // Single tap - word translation
        widget.onWordTap!(wordSpan.word, globalPosition, wordSpan.selection);
      } else if (_tapCount == 2 && widget.enableDoubleTap && widget.onSentenceTap != null) {
        // Double tap - sentence translation
        final sentence = _getSentenceAtPosition(textPosition.offset);
        final sentenceSelection = _getSentenceSelection(textPosition.offset);
        widget.onSentenceTap!(sentence, globalPosition, sentenceSelection);
      }

      // Reset tap state
      _tapCount = 0;
      _highlightedWord = null;
    });

    // Provide immediate visual feedback
    setState(() {
      _highlightedWord = wordSpan.word;
    });
  }

  void _handleLongPress(LongPressStartDetails details) {
    if (!widget.enableLongPress) return;

    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _textPainter == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final textPosition = _textPainter!.getPositionForOffset(localPosition);
    
    // Long press - sentence translation
    if (widget.onSentenceTap != null) {
      final sentence = _getSentenceAtPosition(textPosition.offset);
      final sentenceSelection = _getSentenceSelection(textPosition.offset);
      widget.onSentenceTap!(sentence, details.globalPosition, sentenceSelection);
    }
  }

  WordSpan? _findWordAtPosition(int offset) {
    for (final span in _wordSpans) {
      if (offset >= span.start && offset <= span.end) {
        return span;
      }
    }
    return null;
  }

  TextSelection _getSentenceSelection(int position) {
    final text = widget.text;
    
    int sentenceStart = 0;
    int sentenceEnd = text.length;

    // Find sentence boundaries
    for (int i = position; i >= 0; i--) {
      if (RegExp(r'[.!?]\s').hasMatch(text.substring(i, i + 2))) {
        sentenceStart = i + 2;
        break;
      }
    }

    for (int i = position; i < text.length - 1; i++) {
      if (RegExp(r'[.!?]\s').hasMatch(text.substring(i, i + 2))) {
        sentenceEnd = i + 1;
        break;
      }
    }

    return TextSelection(baseOffset: sentenceStart, extentOffset: sentenceEnd);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _handleTap,
      onLongPressStart: _handleLongPress,
      child: RichText(
        key: _textKey,
        text: _buildTextSpan(),
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      ),
    );
  }

  TextSpan _buildTextSpan() {
    if (_wordSpans.isEmpty || _highlightedWord == null) {
      return TextSpan(
        text: widget.text,
        style: widget.style,
      );
    }

    final List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final wordSpan in _wordSpans) {
      // Add text before the word
      if (wordSpan.start > currentIndex) {
        spans.add(TextSpan(
          text: widget.text.substring(currentIndex, wordSpan.start),
          style: widget.style,
        ));
      }

      // Add the word (highlighted if selected)
      final isHighlighted = wordSpan.word == _highlightedWord;
      spans.add(TextSpan(
        text: wordSpan.word,
        style: (widget.style ?? const TextStyle()).copyWith(
          backgroundColor: isHighlighted 
              ? Theme.of(context).primaryColor.withOpacity(0.3)
              : null,
        ),
      ));

      currentIndex = wordSpan.end;
    }

    // Add remaining text
    if (currentIndex < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(currentIndex),
        style: widget.style,
      ));
    }

    return TextSpan(children: spans);
  }
}

class WordSpan {
  final String word;
  final int start;
  final int end;
  final Offset position;
  final TextSelection selection;

  WordSpan({
    required this.word,
    required this.start,
    required this.end,
    required this.position,
    required this.selection,
  });
}