// EPUB Reader Engine
// EPUB viewing and interaction using epub_view package

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import 'package:epubx/epubx.dart' as epubx;
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/core/services/error_service.dart';

class EpubReaderEngine implements ReaderEngine {
  EpubController? _controller;
  epubx.EpubBook? _book;
  String? _filePath;
  String _currentChapter = '';
  String? _selectedText;
  
  @override
  Future<void> initialize(String filePath) async {
    try {
      _filePath = filePath;
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('EPUB file not found: $filePath');
      }
      
      // Parse EPUB file
      final bytes = await file.readAsBytes();
      _book = await epubx.EpubReader.readBook(bytes);
      
      // Initialize controller
      _controller = EpubController(
        document: EpubDocument.openData(bytes),
      );
      
      // Set first chapter as current
      if (_book?.Chapters?.isNotEmpty == true) {
        _currentChapter = _book!.Chapters!.first.Title ?? '';
      }
      
    } catch (e) {
      ErrorService.logParsingError(
        'Failed to initialize EPUB reader',
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
    _book = null;
  }
  
  @override
  int get totalPages {
    // EPUB doesn't have fixed pages, return chapter count
    return _book?.Chapters?.length ?? 0;
  }
  
  @override
  ReaderPosition get currentPosition => ReaderPosition.epub(_currentChapter);
  
  @override
  Future<void> goToPosition(ReaderPosition position) async {
    if (position.chapterId != null && _controller != null) {
      // Find chapter index
      final chapters = _book?.Chapters ?? [];
      final chapterIndex = chapters.indexWhere(
        (ch) => ch.Title == position.chapterId,
      );
      
      if (chapterIndex >= 0) {
        await _controller!.scrollTo(
          index: chapterIndex,
          duration: const Duration(milliseconds: 300),
        );
        _currentChapter = position.chapterId!;
      }
    }
  }
  
  @override
  Future<bool> goToNext() async {
    if (_controller != null && _book?.Chapters != null) {
      final chapters = _book!.Chapters!;
      final currentIndex = chapters.indexWhere(
        (ch) => ch.Title == _currentChapter,
      );
      
      if (currentIndex >= 0 && currentIndex < chapters.length - 1) {
        final nextChapter = chapters[currentIndex + 1];
        await goToPosition(ReaderPosition.epub(nextChapter.Title ?? ''));
        return true;
      }
    }
    return false;
  }
  
  @override
  Future<bool> goToPrevious() async {
    if (_controller != null && _book?.Chapters != null) {
      final chapters = _book!.Chapters!;
      final currentIndex = chapters.indexWhere(
        (ch) => ch.Title == _currentChapter,
      );
      
      if (currentIndex > 0) {
        final prevChapter = chapters[currentIndex - 1];
        await goToPosition(ReaderPosition.epub(prevChapter.Title ?? ''));
        return true;
      }
    }
    return false;
  }
  
  @override
  String? getSelectedText() => _selectedText;
  
  @override
  double get progress {
    if (_book?.Chapters?.isEmpty == true) return 0.0;
    
    final chapters = _book!.Chapters!;
    final currentIndex = chapters.indexWhere(
      (ch) => ch.Title == _currentChapter,
    );
    
    if (currentIndex < 0) return 0.0;
    return currentIndex / chapters.length;
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
            Text('Loading EPUB...'),
          ],
        ),
      );
    }
    
    return GestureDetector(
      onTapDown: (details) => _handleTap(details),
      child: EpubView(
        controller: _controller!,
        onChapterChanged: (chapter) {
          if (chapter?.chapter?.Title != null) {
            _currentChapter = chapter!.chapter!.Title!;
          }
        },
        onDocumentLoaded: (document) {
          // Document loaded successfully
        },
        onDocumentError: (error) {
          ErrorService.logParsingError(
            'EPUB document error',
            details: error.toString(),
            fileName: _filePath,
          );
        },
        // Note: epub_view package doesn't support built-in text selection
        // We handle it through gesture detection
      ),
    );
  }
  
  /// Handle tap for text selection
  Future<void> _handleTap(TapDownDetails details) async {
    final position = details.localPosition;
    
    print('EPUB tap detected at position: $position'); // Debug
    
    // Get word at tap position from current chapter
    final word = await _getWordAtPosition(position);
    
    print('EPUB extracted word: $word'); // Debug
    
    if (word != null && word.isNotEmpty) {
      _selectedText = word;
      print('EPUB calling onTextSelected with: $word'); // Debug
      // Trigger text selection callback
      onTextSelected(word, position);
    } else {
      print('EPUB: No word found at position'); // Debug
    }
  }
  
  /// Extract word from current chapter at tap position
  Future<String?> _getWordAtPosition(Offset position) async {
    final currentChapter = currentChapterInfo;
    if (currentChapter == null) return null;
    
    // Get chapter text content
    final htmlContent = currentChapter.HtmlContent ?? '';
    
    // Strip HTML tags to get plain text
    final plainText = htmlContent.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final words = plainText.split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.replaceAll(RegExp(r'[^\w]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();
    
    // For demonstration, select a word based on position
    // In production, you'd need proper text layout analysis
    if (words.isNotEmpty) {
      final wordIndex = ((position.dx + position.dy) * words.length / 1000).round() % words.length;
      return words[wordIndex];
    }
    
    return null;
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
    
    if (_book?.Chapters?.isEmpty == true || query.isEmpty) {
      return results;
    }
    
    try {
      final chapters = _book!.Chapters!;
      
      for (final chapter in chapters) {
        final content = chapter.HtmlContent?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();
        
        if (content.contains(queryLower)) {
          // Extract context around the match
          final index = content.indexOf(queryLower);
          final start = (index - 50).clamp(0, content.length);
          final end = (index + query.length + 50).clamp(0, content.length);
          final context = content.substring(start, end);
          
          results.add(SearchResult(
            text: query,
            position: ReaderPosition.epub(chapter.Title ?? ''),
            context: context.replaceAll(RegExp(r'<[^>]*>'), ''), // Remove HTML tags
          ));
        }
      }
    } catch (e) {
      ErrorService.logParsingError(
        'EPUB search failed',
        details: e.toString(),
        fileName: _filePath,
      );
    }
    
    return results;
  }
  
  /// Get table of contents for navigation
  List<epubx.EpubChapter> get chapters => _book?.Chapters ?? [];
  
  /// Get current chapter info
  epubx.EpubChapter? get currentChapterInfo {
    if (_book?.Chapters?.isEmpty == true) return null;
    
    return _book!.Chapters!.firstWhere(
      (ch) => ch.Title == _currentChapter,
      orElse: () => _book!.Chapters!.first,
    );
  }
}

/// EPUB chapter info for navigation
class EpubChapter {
  final String title;
  final String? anchor;
  final int index;
  
  const EpubChapter({
    required this.title,
    this.anchor,
    required this.index,
  });
}