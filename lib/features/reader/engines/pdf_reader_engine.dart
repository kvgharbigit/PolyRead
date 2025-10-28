// PDF Reader Engine
// PDF viewing and interaction using pdfx package

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/core/services/error_service.dart';

class PdfReaderEngine implements ReaderEngine {
  PdfController? _controller;
  String? _filePath;
  int _currentPage = 1;
  String? _selectedText;
  
  @override
  Future<void> initialize(String filePath) async {
    try {
      _filePath = filePath;
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('PDF file not found: $filePath');
      }
      
      _controller = PdfController(document: PdfDocument.openFile(filePath));
      
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
    
    return PdfView(
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
      // Enable text selection
      scrollDirection: Axis.vertical,
      pageSnapping: false,
      physics: const BouncingScrollPhysics(),
    );
  }
  
  @override
  void onTextSelected(String selectedText, Offset position) {
    _selectedText = selectedText;
    // TODO: Integrate with translation service
    // This will be connected to Worker 2's translation UI
  }
  
  @override
  Future<List<SearchResult>> search(String query) async {
    final results = <SearchResult>[];
    
    if (_controller == null || query.isEmpty) {
      return results;
    }
    
    try {
      // Search through pages - simplified implementation
      // In production, you'd use proper text extraction libraries
      for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
        // This is a placeholder search implementation
        if (query.toLowerCase().contains('sample')) {
          results.add(SearchResult(
            text: query,
            position: ReaderPosition.pdf(pageNum),
            context: 'Sample context containing $query',
          ));
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
}