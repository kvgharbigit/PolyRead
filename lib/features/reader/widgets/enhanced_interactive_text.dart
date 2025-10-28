// Enhanced Interactive Text Widget
// Advanced word-level touch detection with morpheme and sub-word analysis

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

typedef WordTapCallback = void Function(String word, Offset position, TextSelection selection, WordContext context);
typedef SentenceTapCallback = void Function(String sentence, Offset position, TextSelection selection);
typedef MorphemeTapCallback = void Function(String morpheme, String fullWord, Offset position);

class EnhancedInteractiveText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final WordTapCallback? onWordTap;
  final SentenceTapCallback? onSentenceTap;
  final MorphemeTapCallback? onMorphemeTap;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool enableWordBoundaryDetection;
  final bool enableMorphemeAnalysis;
  final bool enableContextExtraction;
  final bool enablePrecisionTapping;
  final Duration tapTimeout;
  final double tapSensitivity;

  const EnhancedInteractiveText({
    super.key,
    required this.text,
    this.style,
    this.onWordTap,
    this.onSentenceTap,
    this.onMorphemeTap,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.enableWordBoundaryDetection = true,
    this.enableMorphemeAnalysis = true,
    this.enableContextExtraction = true,
    this.enablePrecisionTapping = true,
    this.tapTimeout = const Duration(milliseconds: 200),
    this.tapSensitivity = 8.0, // pixels
  });

  @override
  State<EnhancedInteractiveText> createState() => _EnhancedInteractiveTextState();
}

class _EnhancedInteractiveTextState extends State<EnhancedInteractiveText> {
  final GlobalKey _textKey = GlobalKey();
  TextPainter? _textPainter;
  List<EnhancedWordSpan> _wordSpans = [];
  List<MorphemeSpan> _morphemeSpans = [];
  String? _highlightedWord;
  String? _highlightedMorpheme;
  int? _tapCount;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _buildWordSpans();
    });
  }

  @override
  void didUpdateWidget(EnhancedInteractiveText oldWidget) {
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

    _wordSpans = _extractEnhancedWordSpans(widget.text);
    
    if (widget.enableMorphemeAnalysis) {
      _morphemeSpans = _extractMorphemeSpans();
    }
    
    setState(() {});
  }

  List<EnhancedWordSpan> _extractEnhancedWordSpans(String text) {
    final List<EnhancedWordSpan> spans = [];
    
    // Enhanced regex for better word boundary detection
    final RegExp wordRegex = RegExp(r"\b[\w''\-]+\b");
    final matches = wordRegex.allMatches(text);

    for (final match in matches) {
      final word = match.group(0)!;
      final start = match.start;
      final end = match.end;
      
      final selection = TextSelection(baseOffset: start, extentOffset: end);
      
      if (_textPainter != null) {
        final wordBounds = _getWordBounds(start, end);
        final context = _extractWordContext(start, end, text);
        
        spans.add(EnhancedWordSpan(
          word: word,
          start: start,
          end: end,
          bounds: wordBounds,
          selection: selection,
          context: context,
          wordType: _classifyWord(word),
        ));
      }
    }

    return spans;
  }

  List<MorphemeSpan> _extractMorphemeSpans() {
    final List<MorphemeSpan> spans = [];
    
    for (final wordSpan in _wordSpans) {
      final morphemes = _analyzeWordMorphemes(wordSpan.word);
      int currentOffset = wordSpan.start;
      
      for (final morpheme in morphemes) {
        final morphemeStart = wordSpan.word.indexOf(morpheme, currentOffset - wordSpan.start);
        if (morphemeStart != -1) {
          final absoluteStart = wordSpan.start + morphemeStart;
          final absoluteEnd = absoluteStart + morpheme.length;
          
          spans.add(MorphemeSpan(
            morpheme: morpheme,
            fullWord: wordSpan.word,
            start: absoluteStart,
            end: absoluteEnd,
            bounds: _getMorphemeBounds(absoluteStart, absoluteEnd),
            type: _classifyMorpheme(morpheme),
          ));
          
          currentOffset = absoluteEnd;
        }
      }
    }
    
    return spans;
  }

  Rect _getWordBounds(int start, int end) {
    if (_textPainter == null) return Rect.zero;

    final startOffset = _textPainter!.getOffsetForCaret(TextPosition(offset: start), Rect.zero);
    final endOffset = _textPainter!.getOffsetForCaret(TextPosition(offset: end), Rect.zero);
    
    // Get more precise bounds by measuring the word height
    final textHeight = _textPainter!.preferredLineHeight;
    
    return Rect.fromPoints(
      Offset(startOffset.dx, startOffset.dy),
      Offset(endOffset.dx, startOffset.dy + textHeight),
    );
  }

  Rect _getMorphemeBounds(int start, int end) {
    if (_textPainter == null) return Rect.zero;

    final startOffset = _textPainter!.getOffsetForCaret(TextPosition(offset: start), Rect.zero);
    final endOffset = _textPainter!.getOffsetForCaret(TextPosition(offset: end), Rect.zero);
    final textHeight = _textPainter!.preferredLineHeight;
    
    return Rect.fromPoints(
      Offset(startOffset.dx, startOffset.dy),
      Offset(endOffset.dx, startOffset.dy + textHeight),
    );
  }

  WordContext _extractWordContext(int start, int end, String text) {
    // Extract surrounding sentence
    final sentence = _getSentenceContaining(start, text);
    
    // Extract surrounding words (window of 5 words before and after)
    final words = text.split(RegExp(r'\s+'));
    final wordIndex = _findWordIndex(start, words, text);
    
    final contextWindow = <String>[];
    final windowSize = 5;
    
    for (int i = (wordIndex - windowSize).clamp(0, words.length); 
         i < (wordIndex + windowSize + 1).clamp(0, words.length); 
         i++) {
      if (i < words.length) {
        contextWindow.add(words[i]);
      }
    }
    
    return WordContext(
      sentence: sentence,
      surroundingWords: contextWindow,
      wordPosition: wordIndex,
      totalWords: words.length,
    );
  }

  String _getSentenceContaining(int position, String text) {
    int sentenceStart = 0;
    int sentenceEnd = text.length;

    // More sophisticated sentence boundary detection
    for (int i = position; i >= 0; i--) {
      if (RegExp(r'[.!?]\s+[A-Z]').hasMatch(text.substring(i, (i + 4).clamp(0, text.length)))) {
        sentenceStart = i + 2;
        break;
      }
    }

    for (int i = position; i < text.length - 3; i++) {
      if (RegExp(r'[.!?]\s+[A-Z]').hasMatch(text.substring(i, i + 4))) {
        sentenceEnd = i + 1;
        break;
      }
    }

    return text.substring(sentenceStart, sentenceEnd).trim();
  }

  int _findWordIndex(int charPosition, List<String> words, String text) {
    int currentPos = 0;
    for (int i = 0; i < words.length; i++) {
      final wordStart = text.indexOf(words[i], currentPos);
      final wordEnd = wordStart + words[i].length;
      
      if (charPosition >= wordStart && charPosition <= wordEnd) {
        return i;
      }
      
      currentPos = wordEnd;
    }
    return 0;
  }

  List<String> _analyzeWordMorphemes(String word) {
    // Simplified morpheme analysis - in production, use a proper morphological analyzer
    final morphemes = <String>[];
    
    // Handle common prefixes
    final prefixes = ['un', 're', 'pre', 'dis', 'mis', 'over', 'under', 'out'];
    String remaining = word.toLowerCase();
    
    for (final prefix in prefixes) {
      if (remaining.startsWith(prefix) && remaining.length > prefix.length + 2) {
        morphemes.add(prefix);
        remaining = remaining.substring(prefix.length);
        break;
      }
    }
    
    // Handle common suffixes
    final suffixes = ['ing', 'ed', 'er', 'est', 'ly', 'tion', 'sion', 'ness', 'ment'];
    for (final suffix in suffixes) {
      if (remaining.endsWith(suffix) && remaining.length > suffix.length + 2) {
        morphemes.add(remaining.substring(0, remaining.length - suffix.length));
        morphemes.add(suffix);
        return morphemes;
      }
    }
    
    // If no morphemes found, return the whole word
    if (morphemes.isEmpty) {
      morphemes.add(remaining);
    } else {
      morphemes.add(remaining);
    }
    
    return morphemes;
  }

  WordType _classifyWord(String word) {
    // Basic word classification
    if (RegExp(r'^[A-Z]').hasMatch(word)) {
      return WordType.properNoun;
    } else if (RegExp(r'\d').hasMatch(word)) {
      return WordType.number;
    } else if (word.length <= 3) {
      return WordType.function;
    } else {
      return WordType.content;
    }
  }

  MorphemeType _classifyMorpheme(String morpheme) {
    final prefixes = ['un', 're', 'pre', 'dis', 'mis', 'over', 'under', 'out'];
    final suffixes = ['ing', 'ed', 'er', 'est', 'ly', 'tion', 'sion', 'ness', 'ment'];
    
    if (prefixes.contains(morpheme.toLowerCase())) {
      return MorphemeType.prefix;
    } else if (suffixes.contains(morpheme.toLowerCase())) {
      return MorphemeType.suffix;
    } else {
      return MorphemeType.root;
    }
  }

  void _handleTap(TapUpDetails details) {
    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _textPainter == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final globalPosition = details.globalPosition;
    
    // Find the most precise target (morpheme or word)
    EnhancedWordSpan? targetWord;
    MorphemeSpan? targetMorpheme;
    
    if (widget.enableMorphemeAnalysis) {
      targetMorpheme = _findMorphemeAtPosition(localPosition);
    }
    
    if (targetMorpheme == null || !widget.enableMorphemeAnalysis) {
      targetWord = _findWordAtPosition(localPosition);
    }

    if (targetWord == null && targetMorpheme == null) return;

    final now = DateTime.now();
    
    // Improved tap detection with position sensitivity
    bool isSameTap = false;
    if (_lastTapTime != null && _lastTapPosition != null) {
      final timeDiff = now.difference(_lastTapTime!);
      final positionDiff = (globalPosition - _lastTapPosition!).distance;
      
      isSameTap = timeDiff < widget.tapTimeout && 
                  positionDiff < widget.tapSensitivity;
    }

    if (isSameTap) {
      _tapCount = (_tapCount ?? 0) + 1;
    } else {
      _tapCount = 1;
      _highlightedWord = targetWord?.word;
      _highlightedMorpheme = targetMorpheme?.morpheme;
    }

    _lastTapTime = now;
    _lastTapPosition = globalPosition;

    // Process the tap after timeout to check for multi-taps
    Future.delayed(widget.tapTimeout, () {
      if (!mounted) return;

      if (_tapCount == 1) {
        // Single tap
        if (targetMorpheme != null && widget.onMorphemeTap != null) {
          widget.onMorphemeTap!(
            targetMorpheme.morpheme,
            targetMorpheme.fullWord,
            globalPosition,
          );
        } else if (targetWord != null && widget.onWordTap != null) {
          widget.onWordTap!(
            targetWord.word,
            globalPosition,
            targetWord.selection,
            targetWord.context,
          );
        }
      } else if (_tapCount == 2) {
        // Double tap - sentence
        if (widget.onSentenceTap != null) {
          final textPosition = _textPainter!.getPositionForOffset(localPosition);
          final sentence = _getSentenceContaining(textPosition.offset, widget.text);
          final sentenceSelection = _getSentenceSelection(textPosition.offset);
          widget.onSentenceTap!(sentence, globalPosition, sentenceSelection);
        }
      }

      // Reset tap state
      _tapCount = 0;
      _highlightedWord = null;
      _highlightedMorpheme = null;
      setState(() {});
    });

    // Provide immediate visual feedback
    setState(() {});
  }

  EnhancedWordSpan? _findWordAtPosition(Offset position) {
    for (final span in _wordSpans) {
      if (span.bounds.contains(position)) {
        return span;
      }
    }
    return null;
  }

  MorphemeSpan? _findMorphemeAtPosition(Offset position) {
    for (final span in _morphemeSpans) {
      if (span.bounds.contains(position)) {
        return span;
      }
    }
    return null;
  }

  TextSelection _getSentenceSelection(int position) {
    final text = widget.text;
    int sentenceStart = 0;
    int sentenceEnd = text.length;

    for (int i = position; i >= 0; i--) {
      if (RegExp(r'[.!?]\s+[A-Z]').hasMatch(text.substring(i, (i + 4).clamp(0, text.length)))) {
        sentenceStart = i + 2;
        break;
      }
    }

    for (int i = position; i < text.length - 3; i++) {
      if (RegExp(r'[.!?]\s+[A-Z]').hasMatch(text.substring(i, i + 4))) {
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
    if (_wordSpans.isEmpty) {
      return TextSpan(text: widget.text, style: widget.style);
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

      // Add the word with appropriate highlighting
      final isWordHighlighted = wordSpan.word == _highlightedWord;
      final wordColor = isWordHighlighted 
          ? Theme.of(context).primaryColor.withOpacity(0.3)
          : null;

      // Check if any morphemes in this word are highlighted
      Color? morphemeColor;
      if (widget.enableMorphemeAnalysis) {
        for (final morpheme in _morphemeSpans) {
          if (morpheme.fullWord == wordSpan.word && 
              morpheme.morpheme == _highlightedMorpheme) {
            morphemeColor = Theme.of(context).secondaryHeaderColor.withOpacity(0.3);
            break;
          }
        }
      }

      spans.add(TextSpan(
        text: wordSpan.word,
        style: (widget.style ?? const TextStyle()).copyWith(
          backgroundColor: morphemeColor ?? wordColor,
          fontWeight: isWordHighlighted ? FontWeight.bold : null,
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

// Enhanced data classes
class EnhancedWordSpan {
  final String word;
  final int start;
  final int end;
  final Rect bounds;
  final TextSelection selection;
  final WordContext context;
  final WordType wordType;

  EnhancedWordSpan({
    required this.word,
    required this.start,
    required this.end,
    required this.bounds,
    required this.selection,
    required this.context,
    required this.wordType,
  });
}

class MorphemeSpan {
  final String morpheme;
  final String fullWord;
  final int start;
  final int end;
  final Rect bounds;
  final MorphemeType type;

  MorphemeSpan({
    required this.morpheme,
    required this.fullWord,
    required this.start,
    required this.end,
    required this.bounds,
    required this.type,
  });
}

class WordContext {
  final String sentence;
  final List<String> surroundingWords;
  final int wordPosition;
  final int totalWords;

  WordContext({
    required this.sentence,
    required this.surroundingWords,
    required this.wordPosition,
    required this.totalWords,
  });
}

enum WordType {
  content,
  function,
  properNoun,
  number,
}

enum MorphemeType {
  root,
  prefix,
  suffix,
}