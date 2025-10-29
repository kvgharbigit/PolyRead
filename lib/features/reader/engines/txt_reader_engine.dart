// TXT Reader Engine
// Renders plain text files with interactive word-level selection

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/widgets/interactive_text.dart';
import 'package:polyread/features/reader/services/reader_settings_service.dart';
import 'package:polyread/features/reader/models/reader_settings.dart';

class TxtReaderEngine implements ReaderEngine {
  String? _filePath;
  String? _textContent;
  List<String> _lines = [];
  List<String> _pages = [];
  int _currentPage = 0;
  int _totalPages = 0;
  double _progress = 0.0;
  String? _selectedText;
  ReaderEngineSettings? _settings;
  
  // Reading configuration (can be overridden by settings)
  int _linesPerPage = 30;
  double _fontSize = 16.0;
  double _lineHeight = 1.5;
  
  // Text selection tracking
  final ValueNotifier<String?> selectedTextNotifier = ValueNotifier<String?>(null);
  Function(String, Offset, TextSelection)? _textSelectionHandler;
  
  // Scroll controller for page content
  final ScrollController _scrollController = ScrollController();

  @override
  Future<void> initialize(String filePath) async {
    _filePath = filePath;
    
    // Read text content
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Text file not found: $filePath');
    }
    
    _textContent = await file.readAsString();
    
    // Process content into lines and pages
    _processContent();
    
    // Set up scroll listener for progress tracking
    _scrollController.addListener(_updateProgress);
  }

  @override
  Future<void> dispose() async {
    selectedTextNotifier.dispose();
    _scrollController.dispose();
  }

  @override
  int get totalPages => _totalPages;

  @override
  ReaderPosition get currentPosition => ReaderPosition.pdf(_currentPage + 1);

  @override
  Future<void> goToPosition(ReaderPosition position) async {
    if (position.pageNumber != null) {
      final page = (position.pageNumber! - 1).clamp(0, _totalPages - 1);
      _currentPage = page;
      _progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
    }
    
    if (position.scrollOffset != null) {
      // Scroll to specific offset within current page
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetScroll = maxScroll * position.scrollOffset!;
      await _scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Future<bool> goToNext() async {
    if (_currentPage < _totalPages - 1) {
      _currentPage++;
      _progress = _currentPage / _totalPages;
      return true;
    }
    return false;
  }

  @override
  Future<bool> goToPrevious() async {
    if (_currentPage > 0) {
      _currentPage--;
      _progress = _currentPage / _totalPages;
      return true;
    }
    return false;
  }

  @override
  String? getSelectedText() => _selectedText;

  @override
  double get progress => _progress;

  @override
  Widget buildReader(BuildContext context) {
    if (_pages.isEmpty) {
      return const Center(
        child: Text('No content to display'),
      );
    }
    
    // Get current text style based on settings
    final textStyle = _getTextStyle();
    final backgroundColor = _getBackgroundColor();
    final margins = _settings?.pageMargins ?? 16.0;
    
    // Return just the content area to match other readers
    return Container(
      color: backgroundColor,
      padding: EdgeInsets.all(margins),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: InteractiveTextWidget(
          text: _getCurrentPageText(),
          onWordTap: _handleWordTap,
          onSentenceTap: _handleSentenceTap,
          style: textStyle,
          textAlign: _settings?.textAlign ?? TextAlign.left,
        ),
      ),
    );
  }
  
  /// Get current page info for external display
  String get currentPageInfo => 'Page ${_currentPage + 1} of $_totalPages';
  
  /// Get current progress percentage for external display  
  String get progressPercentage => '${(_progress * 100).toStringAsFixed(1)}%';


  @override
  Future<List<SearchResult>> search(String query) async {
    final results = <SearchResult>[];
    
    if (_textContent == null) return results;
    
    final text = _textContent!.toLowerCase();
    final searchQuery = query.toLowerCase();
    int index = 0;
    
    while ((index = text.indexOf(searchQuery, index)) != -1) {
      // Find which page this result is on
      final pageIndex = _findPageForCharacterIndex(index);
      
      // Extract context around the match
      final start = (index - 100).clamp(0, text.length);
      final end = (index + searchQuery.length + 100).clamp(0, text.length);
      final context = _textContent!.substring(start, end);
      
      results.add(SearchResult(
        text: query,
        position: ReaderPosition.pdf(pageIndex + 1),
        context: context.replaceAll('\n', ' ').trim(),
      ));
      
      index += searchQuery.length;
    }
    
    return results;
  }

  void _processContent() {
    if (_textContent == null) return;
    
    // Split into lines
    _lines = _textContent!.split('\n');
    
    // Group lines into pages
    _pages.clear();
    final currentPage = StringBuffer();
    int linesInCurrentPage = 0;
    
    for (final line in _lines) {
      // Calculate how many lines this text will take (considering word wrap)
      final estimatedLines = max(1, (line.length / 80).ceil());
      
      if (linesInCurrentPage + estimatedLines > _linesPerPage && currentPage.isNotEmpty) {
        // Start new page
        _pages.add(currentPage.toString());
        currentPage.clear();
        linesInCurrentPage = 0;
      }
      
      currentPage.writeln(line);
      linesInCurrentPage += estimatedLines;
    }
    
    // Add the last page if it has content
    if (currentPage.isNotEmpty) {
      _pages.add(currentPage.toString());
    }
    
    _totalPages = _pages.length;
    _currentPage = 0;
    _progress = 0.0;
  }

  String _getCurrentPageText() {
    if (_pages.isEmpty || _currentPage >= _pages.length) {
      return '';
    }
    return _pages[_currentPage];
  }

  int _findPageForCharacterIndex(int charIndex) {
    int currentIndex = 0;
    
    for (int i = 0; i < _pages.length; i++) {
      final pageLength = _pages[i].length;
      if (charIndex < currentIndex + pageLength) {
        return i;
      }
      currentIndex += pageLength;
    }
    
    return _pages.length - 1;
  }

  @override
  void onTextSelected(String selectedText, Offset position) {
    _selectedText = selectedText;
    selectedTextNotifier.value = selectedText;
    
    // Trigger consistent callback interface (same as PDF/EPUB)
    if (onTextSelectionCallback != null) {
      onTextSelectionCallback!(selectedText, position);
    }
    
    // Keep advanced handler for backward compatibility
    if (_textSelectionHandler != null) {
      final textSelection = TextSelection(
        baseOffset: 0,
        extentOffset: selectedText.length,
      );
      _textSelectionHandler!(selectedText, position, textSelection);
    }
  }

  /// Set a custom text selection handler for advanced functionality
  void setTextSelectionHandler(void Function(String text, Offset position, TextSelection selection)? handler) {
    _textSelectionHandler = handler;
  }

  /// Apply reader settings to the engine
  Future<void> applySettings(ReaderEngineSettings settings) async {
    _settings = settings;
    
    // Update internal configuration based on settings
    _fontSize = settings.fontSize;
    _lineHeight = settings.lineHeight;
    
    // Recalculate pages based on new line height and font size
    _processContent();
  }

  /// Get text style based on current settings
  TextStyle _getTextStyle() {
    if (_settings == null) {
      return TextStyle(
        fontSize: _fontSize,
        height: _lineHeight,
        fontFamily: 'serif',
      );
    }
    
    String? fontFamily;
    switch (_settings!.fontFamily) {
      case 'System Default':
        fontFamily = null;
        break;
      case 'Georgia':
      case 'Times New Roman':
      case 'Arial':
      case 'Helvetica':
      case 'Open Sans':
      case 'Roboto':
        fontFamily = _settings!.fontFamily;
        break;
      default:
        fontFamily = null;
    }
    
    return TextStyle(
      fontSize: _settings!.fontSize,
      height: _settings!.lineHeight,
      fontFamily: fontFamily,
      color: _getTextColor(),
    );
  }

  /// Get background color based on theme
  Color _getBackgroundColor() {
    if (_settings == null) return Colors.white;
    
    if (_settings!.theme == ReaderTheme.light) {
      return const Color(0xFFFFFFFF);
    } else if (_settings!.theme == ReaderTheme.sepia) {
      return const Color(0xFFFDF6E3);
    } else if (_settings!.theme == ReaderTheme.dark) {
      return const Color(0xFF1A1A1A);
    } else if (_settings!.theme == ReaderTheme.custom) {
      final brightness = (_settings!.brightness * 255).round();
      return Color.fromRGBO(brightness, brightness, brightness, 1.0);
    }
    return Colors.white;
  }

  /// Get text color based on theme
  Color _getTextColor() {
    if (_settings == null) return Colors.black;
    
    if (_settings!.theme == ReaderTheme.light) {
      return const Color(0xFF000000);
    } else if (_settings!.theme == ReaderTheme.sepia) {
      return const Color(0xFF5D4E37);
    } else if (_settings!.theme == ReaderTheme.dark) {
      return const Color(0xFFFFFFFF);
    } else if (_settings!.theme == ReaderTheme.custom) {
      return _settings!.brightness > 0.5 
          ? const Color(0xFF000000) 
          : const Color(0xFFFFFFFF);
    }
    return Colors.black;
  }

  void _handleWordTap(String word, Offset position) {
    onTextSelected(word, position);
    
    // Trigger callback for external handling
    if (onTextSelectionCallback != null) {
      onTextSelectionCallback!(word, position);
    }
  }

  void _handleSentenceTap(String sentence, Offset position) {
    onTextSelected(sentence, position);
    
    // Trigger callback for external handling  
    if (onTextSelectionCallback != null) {
      onTextSelectionCallback!(sentence, position);
    }
  }
  
  /// Callback for text selection events
  Function(String text, Offset position)? onTextSelectionCallback;
  
  /// Set text selection callback
  void setTextSelectionCallback(Function(String text, Offset position)? callback) {
    onTextSelectionCallback = callback;
  }

  void _updateProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        final scrollProgress = _scrollController.offset / maxScroll;
        final pageProgress = (_currentPage / _totalPages);
        final perPageProgress = scrollProgress / _totalPages;
        _progress = pageProgress + perPageProgress;
      }
    }
  }
  
  @override
  String? extractContextAroundWord(String word, {int contextWords = 10}) {
    if (_textContent == null) return null;
    
    // Find the word in the current page text
    final currentPageText = _getCurrentPageText();
    final wordIndex = currentPageText.toLowerCase().indexOf(word.toLowerCase());
    
    if (wordIndex == -1) return null;
    
    // Split into words
    final words = currentPageText.split(RegExp(r'\s+'));
    
    // Find the word position in the word array
    int wordPosition = -1;
    int charCount = 0;
    
    for (int i = 0; i < words.length; i++) {
      if (charCount <= wordIndex && charCount + words[i].length > wordIndex) {
        wordPosition = i;
        break;
      }
      charCount += words[i].length + 1; // +1 for space
    }
    
    if (wordPosition == -1) return null;
    
    // Extract context around the word
    final startIndex = (wordPosition - contextWords).clamp(0, words.length);
    final endIndex = (wordPosition + contextWords + 1).clamp(0, words.length);
    
    final contextWords_list = words.sublist(startIndex, endIndex);
    return contextWords_list.join(' ');
  }
}

// Interactive Text Widget for word-level selection
class InteractiveTextWidget extends StatefulWidget {
  final String text;
  final Function(String, Offset) onWordTap;
  final Function(String, Offset) onSentenceTap;
  final TextStyle? style;
  final TextAlign textAlign;

  const InteractiveTextWidget({
    super.key,
    required this.text,
    required this.onWordTap,
    required this.onSentenceTap,
    this.style,
    this.textAlign = TextAlign.left,
  });

  @override
  State<InteractiveTextWidget> createState() => _InteractiveTextWidgetState();
}

class _InteractiveTextWidgetState extends State<InteractiveTextWidget> {
  String? _selectedWord;
  
  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _buildTextSpan(),
      style: widget.style,
      textAlign: widget.textAlign,
      onSelectionChanged: (selection, cause) {
        if (selection != null && selection.textInside(widget.text).isNotEmpty) {
          final selectedText = selection.textInside(widget.text);
          
          // Determine if it's a word or sentence
          if (selectedText.contains(' ') || selectedText.contains('.')) {
            // Sentence selection
            widget.onSentenceTap(selectedText, Offset.zero);
          } else {
            // Word selection
            widget.onWordTap(selectedText, Offset.zero);
          }
        }
      },
    );
  }

  TextSpan _buildTextSpan() {
    final words = widget.text.split(' ');
    final spans = <TextSpan>[];
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isSelected = word == _selectedWord;
      
      spans.add(
        TextSpan(
          text: word + (i < words.length - 1 ? ' ' : ''),
          style: isSelected 
              ? widget.style?.copyWith(backgroundColor: Colors.blue.withOpacity(0.3))
              : widget.style,
        ),
      );
    }
    
    return TextSpan(children: spans);
  }
}