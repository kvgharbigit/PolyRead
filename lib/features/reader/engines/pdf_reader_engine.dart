// PDF Reader Engine
// PDF viewing and interaction using pdfx package

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/core/services/error_service.dart';

class PdfReaderEngine implements ReaderEngine {
  PdfController? _controller;
  PdfDocument? _pdfDocument;
  String? _filePath;
  int _currentPage = 1;
  String? _selectedText;
  
  // Cache for extracted text
  final Map<int, String> _pageTextCache = {};
  
  @override
  Future<void> initialize(String filePath) async {
    try {
      _filePath = filePath;
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('PDF file not found: $filePath');
      }
      
      // Initialize PDF document and controller  
      _controller = PdfController(document: PdfDocument.openFile(filePath));
      _pdfDocument = await PdfDocument.openFile(filePath);
      
    } catch (e) {
      ErrorService.logParsingError(
        'Failed to initialize PDF reader',
        details: e.toString(),
        fileName: filePath,
      );
      rethrow;
    }
  }
  
  @override
  Future<void> dispose() async {
    _controller?.dispose();
    _controller = null;
    await _pdfDocument?.close();
    _pdfDocument = null;
    _pageTextCache.clear();
  }
  
  @override
  int get totalPages => _controller?.pagesCount ?? 0;
  
  @override
  ReaderPosition get currentPosition => ReaderPosition.pdf(_currentPage);
  
  @override
  Future<void> goToPosition(ReaderPosition position) async {
    if (position.pageNumber != null && _controller != null) {
      await _controller!.animateToPage(
        position.pageNumber!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _currentPage = position.pageNumber!;
    }
  }
  
  @override
  Future<bool> goToNext() async {
    if (_controller != null && _currentPage < totalPages) {
      await _controller!.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _currentPage++;
      return true;
    }
    return false;
  }
  
  @override
  Future<bool> goToPrevious() async {
    if (_controller != null && _currentPage > 1) {
      await _controller!.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _currentPage--;
      return true;
    }
    return false;
  }
  
  @override
  String? getSelectedText() => _selectedText;
  
  @override
  double get progress {
    if (totalPages == 0) return 0.0;
    return (_currentPage - 1) / totalPages;
  }
  
  @override
  Widget buildReader(BuildContext context) {
    if (_controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading PDF...'),
          ],
        ),
      );
    }
    
    return GestureDetector(
      onTapDown: (details) => _handleTap(details),
      child: PdfView(
        controller: _controller!,
        onPageChanged: (page) {
          _currentPage = page;
        },
        onDocumentLoaded: (document) {
          // Document loaded successfully
        },
        onDocumentError: (error) {
          ErrorService.logParsingError(
            'PDF document error',
            details: error.toString(),
            fileName: _filePath,
          );
        },
        // Enable scrolling
        scrollDirection: Axis.vertical,
        pageSnapping: false,
        physics: const BouncingScrollPhysics(),
      ),
    );
  }
  
  /// Handle tap for text selection
  Future<void> _handleTap(TapDownDetails details) async {
    final position = details.localPosition;
    
    // Get word at tap position
    final word = await getTextAtPosition(_currentPage, position.dx, position.dy);
    
    if (word != null && word.isNotEmpty) {
      _selectedText = word;
      // Trigger text selection callback
      onTextSelected(word, position);
    }
  }
  
  @override
  void onTextSelected(String selectedText, Offset position) {
    _selectedText = selectedText;
    
    // Trigger callback for external handling (will be connected to translation service)
    if (onTextSelectionCallback != null) {
      onTextSelectionCallback!(selectedText, position);
    }
  }
  
  /// Callback for text selection events
  Function(String text, Offset position)? onTextSelectionCallback;
  
  /// Set text selection callback
  void setTextSelectionCallback(Function(String text, Offset position)? callback) {
    onTextSelectionCallback = callback;
  }
  
  @override
  Future<List<SearchResult>> search(String query) async {
    final results = <SearchResult>[];
    
    if (_controller == null || query.isEmpty) {
      return results;
    }
    
    try {
      final queryLower = query.toLowerCase();
      
      // Extract and search text from each page
      for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
        final pageText = await _extractTextFromPage(pageNum);
        if (pageText.toLowerCase().contains(queryLower)) {
          // Find all occurrences on this page
          final lines = pageText.split('\n');
          for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
            final line = lines[lineIndex];
            if (line.toLowerCase().contains(queryLower)) {
              // Extract context around the match
              final contextStart = (lineIndex - 1).clamp(0, lines.length - 1);
              final contextEnd = (lineIndex + 1).clamp(0, lines.length - 1);
              final context = lines.sublist(contextStart, contextEnd + 1).join(' ');
              
              results.add(SearchResult(
                text: query,
                position: ReaderPosition.pdf(pageNum),
                context: context.length > 200 ? '${context.substring(0, 200)}...' : context,
              ));
            }
          }
        }
      }
    } catch (e) {
      ErrorService.logParsingError(
        'PDF search failed',
        details: e.toString(),
        fileName: _filePath,
      );
    }
    
    return results;
  }
  
  /// Extract text from a specific page using pdfx
  Future<String> _extractTextFromPage(int pageNum) async {
    if (_pdfDocument == null) return '';
    
    // Check cache first
    if (_pageTextCache.containsKey(pageNum)) {
      return _pageTextCache[pageNum]!;
    }
    
    try {
      final page = await _pdfDocument!.getPage(pageNum);
      
      // Note: pdfx has limited text extraction capabilities
      // For demonstration, we'll create a mock text extraction
      // In production, you'd need a dedicated text extraction library
      
      // Mock text extraction based on page content
      final mockText = '''This is sample text from page $pageNum of the PDF document.
      
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor 
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis 
nostrud exercitation ullamco laboris.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore 
eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt 
in culpa qui officia deserunt mollit anim id est laborum.

Sample words for translation: hello, world, book, reading, language, learning.''';
      
      // Cache the extracted text
      _pageTextCache[pageNum] = mockText;
      await page.close();
      
      return mockText;
    } catch (e) {
      ErrorService.logParsingError(
        'PDF text extraction failed for page $pageNum',
        details: e.toString(),
        fileName: _filePath,
      );
      return '';
    }
  }
  
  @override
  String? extractContextAroundWord(String word, {int contextWords = 10}) {
    // Extract context from current page text
    final pageText = _pageTextCache[_currentPage];
    if (pageText == null) return null;
    
    final words = pageText.split(RegExp(r'\s+'));
    final wordIndex = words.indexWhere((w) => w.toLowerCase().contains(word.toLowerCase()));
    
    if (wordIndex == -1) return null;
    
    // Extract context around the word
    final startIndex = (wordIndex - contextWords).clamp(0, words.length);
    final endIndex = (wordIndex + contextWords + 1).clamp(0, words.length);
    
    return words.sublist(startIndex, endIndex).join(' ');
  }

  /// Get text at a specific position for word selection
  Future<String?> getTextAtPosition(int page, double x, double y) async {
    final pageText = await _extractTextFromPage(page);
    if (pageText.isEmpty) return null;
    
    // Split into words and find the most likely word based on position
    final words = pageText.split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .map((word) => word.replaceAll(RegExp(r'[^\w]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();
    
    if (words.isEmpty) return null;
    
    // Use position to select word - this is a simplified approach
    // In production, you'd use proper PDF text layout analysis
    final normalizedX = (x / 400).clamp(0.0, 1.0); // Assume 400px width
    final normalizedY = (y / 600).clamp(0.0, 1.0); // Assume 600px height
    
    // Use a combination of x and y to pick a reasonable word
    final wordIndex = ((normalizedX + normalizedY * 0.3) * words.length).floor() % words.length;
    
    final selectedWord = words[wordIndex];
    print('PDF: Selected word "$selectedWord" at position ($x, $y)');
    
    return selectedWord;
  }
}