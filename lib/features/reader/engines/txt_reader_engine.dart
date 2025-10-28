// TXT Reader Engine
// Renders plain text files with interactive word-level selection

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/widgets/interactive_text.dart';

class TxtReaderEngine implements ReaderEngine {
  String? _filePath;
  String? _textContent;
  List<String> _lines = [];
  List<String> _pages = [];
  int _currentPage = 0;
  int _totalPages = 0;
  double _progress = 0.0;
  String? _selectedText;
  
  // Reading configuration
  static const int linesPerPage = 30;
  static const double fontSize = 16.0;
  static const double lineHeight = 1.5;
  
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
    
    // Return just the content area to match other readers
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: InteractiveTextWidget(
          text: _getCurrentPageText(),
          onWordTap: _handleWordTap,
          onSentenceTap: _handleSentenceTap,
          style: const TextStyle(
            fontSize: fontSize,
            height: lineHeight,
            fontFamily: 'serif',
          ),
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
      
      if (linesInCurrentPage + estimatedLines > linesPerPage && currentPage.isNotEmpty) {
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
}

// Interactive Text Widget for word-level selection
class InteractiveTextWidget extends StatefulWidget {
  final String text;
  final Function(String, Offset) onWordTap;
  final Function(String, Offset) onSentenceTap;
  final TextStyle? style;

  const InteractiveTextWidget({
    super.key,
    required this.text,
    required this.onWordTap,
    required this.onSentenceTap,
    this.style,
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