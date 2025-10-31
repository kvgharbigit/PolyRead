// EPUB Reader Engine - Clean with WebView Text Selection
// Precise word-level text selection using WebView + JavaScript

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:epub_view/epub_view.dart';
import 'package:epubx/epubx.dart' as epubx;
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/core/services/error_service.dart';

class EpubReaderEngine implements ReaderEngine {
  EpubController? _controller;
  WebViewController? _webViewController;
  epubx.EpubBook? _book;
  String? _filePath;
  String _currentChapter = '';
  String? _selectedText;
  int _currentChapterIndex = 0;
  
  /// Callback for text selection events
  Function(String text, Offset position)? onTextSelectionCallback;
  
  @override
  Future<void> initialize(String filePath) async {
    try {
      print('EPUB: Starting initialization for $filePath');
      _filePath = filePath;
      final file = File(filePath);
      
      if (!await file.exists()) {
        throw Exception('EPUB file not found: $filePath');
      }
      
      // Parse EPUB file
      print('EPUB: Parsing EPUB file...');
      final bytes = await file.readAsBytes();
      _book = await epubx.EpubReader.readBook(bytes);
      print('EPUB: Book parsed successfully, chapters: ${_book?.Chapters?.length ?? 0}');
      
      // Initialize WebView controller for precise text selection
      print('EPUB: Initializing WebView...');
      await _initializeWebView();
      
      // Set first chapter as current
      final chapters = _book?.Chapters;
      if (chapters != null && chapters.isNotEmpty) {
        _currentChapter = chapters.first.Title ?? '';
        _currentChapterIndex = 0;
        print('EPUB: Set initial chapter: $_currentChapter');
        await _loadCurrentChapterInWebView();
      }
      
      print('EPUB: Initialization complete');
    } catch (e) {
      print('EPUB: Initialization error: $e');
      ErrorService.logParsingError(
        'Failed to initialize EPUB reader',
        details: e.toString(),
        fileName: filePath,
      );
      rethrow;
    }
  }

  Future<void> _initializeWebView() async {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'TextSelection',
        onMessageReceived: (JavaScriptMessage message) {
          _handleWebViewTextSelection(message.message);
        },
      );
  }

  Future<void> _loadCurrentChapterInWebView() async {
    if (_webViewController == null || _book?.Chapters?.isEmpty == true) {
      print('EPUB: Cannot load chapter - missing WebView controller or chapters');
      return;
    }

    final chapters = _book?.Chapters;
    if (chapters == null || _currentChapterIndex >= chapters.length) {
      print('EPUB: Invalid chapter index: $_currentChapterIndex');
      return;
    }
    
    final currentChapter = chapters[_currentChapterIndex];
    final htmlContent = currentChapter.HtmlContent ?? '';
    print('EPUB: Loading chapter $_currentChapterIndex: "${currentChapter.Title}"');
    print('EPUB: Chapter content length: ${htmlContent.length} characters');
    
    // Create HTML with enhanced text selection JavaScript
    final fullHtml = _createInteractiveHtml(htmlContent);
    
    try {
      await _webViewController!.loadHtmlString(fullHtml);
      print('EPUB: Chapter loaded successfully in WebView');
    } catch (e) {
      print('EPUB: Error loading chapter in WebView: $e');
    }
  }

  String _createInteractiveHtml(String chapterContent) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: Georgia, serif;
            font-size: 18px;
            line-height: 1.6;
            margin: 20px;
            padding: 0;
            color: #333;
        }
        p {
            margin-bottom: 1em;
        }
    </style>
</head>
<body>
$chapterContent

<script>
// Word-level tap detection for precise text selection
function handleWordTap(event) {
    const range = document.caretRangeFromPoint(event.clientX, event.clientY);
    if (range) {
        const textNode = range.startContainer;
        if (textNode.nodeType === Node.TEXT_NODE) {
            const text = textNode.textContent;
            let start = range.startOffset;
            let end = range.startOffset;
            
            console.log('Debug: Full text node:', text);
            console.log('Debug: Range start offset:', start);
            
            // Find word boundaries more carefully
            while (start > 0 && /[a-zA-Z0-9]/.test(text[start - 1])) start--;
            while (end < text.length && /[a-zA-Z0-9]/.test(text[end])) end++;
            
            const word = text.substring(start, end).trim();
            console.log('Debug: Extracted word:', word);
            
            // Ensure we only get a single word
            const singleWord = word.split(/\\s+/)[0];
            console.log('Debug: Single word only:', singleWord);
            
            if (singleWord.length > 0 && singleWord.length < 50) {
                // Send word tap to Flutter
                if (window.TextSelection) {
                    window.TextSelection.postMessage(JSON.stringify({
                        type: 'wordTap',
                        text: singleWord,
                        position: { x: event.clientX, y: event.clientY }
                    }));
                }
            }
        }
    }
}

// Add event listener
document.addEventListener('click', handleWordTap);
</script>

</body>
</html>
''';
  }

  void _handleWebViewTextSelection(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      
      if (data['type'] == 'wordTap') {
        final word = data['text'] as String;
        final position = data['position'] as Map<String, dynamic>;
        final offset = Offset(
          (position['x'] as num).toDouble(),
          (position['y'] as num).toDouble(),
        );
        
        print('EPUB WebView: Exact word tapped: "$word" at $offset');
        
        _selectedText = word;
        onTextSelected(word, offset);
      }
    } catch (e) {
      print('Error handling WebView text selection: $e');
    }
  }

  @override
  Future<void> dispose() async {
    print('EPUB: Disposing...');
    _controller?.dispose();
    _controller = null;
    _book = null;
    _webViewController = null;
  }
  
  @override
  int get totalPages => _book?.Chapters?.length ?? 0;
  
  @override
  ReaderPosition get currentPosition => ReaderPosition.epub(_currentChapter);
  
  /// Get chapters for table of contents
  List<epubx.EpubChapter>? get chapters => _book?.Chapters;
  
  @override
  Future<void> goToPosition(ReaderPosition position) async {
    if (position.chapterId != null) {
      final chapters = _book?.Chapters ?? [];
      final chapterIndex = chapters.indexWhere(
        (ch) => ch.Title == position.chapterId,
      );
      
      if (chapterIndex >= 0) {
        print('EPUB: Navigating to chapter $chapterIndex: ${position.chapterId}');
        _currentChapter = position.chapterId!;
        _currentChapterIndex = chapterIndex;
        await _loadCurrentChapterInWebView();
      }
    }
  }
  
  @override
  Future<bool> goToNext() async {
    print('EPUB: goToNext called');
    if (_book?.Chapters != null) {
      final chapters = _book!.Chapters!;
      
      if (_currentChapterIndex < chapters.length - 1) {
        _currentChapterIndex++;
        _currentChapter = chapters[_currentChapterIndex].Title ?? '';
        print('EPUB: Moving to next chapter $_currentChapterIndex: $_currentChapter');
        await _loadCurrentChapterInWebView();
        return true;
      }
    }
    print('EPUB: Already at last chapter');
    return false;
  }
  
  @override
  Future<bool> goToPrevious() async {
    print('EPUB: goToPrevious called');
    if (_book?.Chapters != null) {
      if (_currentChapterIndex > 0) {
        _currentChapterIndex--;
        _currentChapter = _book!.Chapters![_currentChapterIndex].Title ?? '';
        print('EPUB: Moving to previous chapter $_currentChapterIndex: $_currentChapter');
        await _loadCurrentChapterInWebView();
        return true;
      }
    }
    print('EPUB: Already at first chapter');
    return false;
  }
  
  @override
  String? getSelectedText() => _selectedText;
  
  @override
  double get progress {
    if (_book?.Chapters?.isEmpty == true) return 0.0;
    return _currentChapterIndex / (_book?.Chapters?.length ?? 1);
  }
  
  @override
  Widget buildReader(BuildContext context) {
    print('EPUB: buildReader called, WebView controller available: ${_webViewController != null}');
    
    if (_webViewController == null) {
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
    
    final totalChapters = _book?.Chapters?.length ?? 0;
    
    return Column(
      children: [
        // Navigation bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _currentChapterIndex > 0 ? () => goToPrevious() : null,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  'Chapter ${_currentChapterIndex + 1} of $totalChapters: $_currentChapter',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _currentChapterIndex < (totalChapters - 1) ? () => goToNext() : null,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
        // WebView content
        Expanded(
          child: WebViewWidget(controller: _webViewController!),
        ),
      ],
    );
  }
  
  @override
  String? extractContextAroundWord(String word, {int contextWords = 10}) {
    if (_book?.Chapters?.isEmpty == true || _currentChapterIndex >= _book!.Chapters!.length) {
      return null;
    }
    
    final currentChapter = _book!.Chapters![_currentChapterIndex];
    final htmlContent = currentChapter.HtmlContent ?? '';
    
    // Simple text extraction and context building
    final plainText = htmlContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    final words = plainText.split(' ');
    final wordIndex = words.indexWhere(
      (w) => w.toLowerCase().contains(word.toLowerCase()),
    );
    
    if (wordIndex == -1) return null;
    
    final startIndex = (wordIndex - contextWords).clamp(0, words.length);
    final endIndex = (wordIndex + contextWords + 1).clamp(0, words.length);
    
    return words.sublist(startIndex, endIndex).join(' ');
  }
  
  @override
  Future<List<SearchResult>> search(String query) async {
    final results = <SearchResult>[];
    
    if (_book?.Chapters?.isEmpty == true || query.isEmpty) {
      return results;
    }
    
    try {
      final chapters = _book!.Chapters!;
      
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final content = chapter.HtmlContent?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();
        
        if (content.contains(queryLower)) {
          // Extract context around the match
          final index = content.indexOf(queryLower);
          final start = (index - 50).clamp(0, content.length);
          final end = (index + query.length + 50).clamp(0, content.length);
          final context = content.substring(start, end)
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          
          results.add(SearchResult(
            text: query,
            position: ReaderPosition.epub(chapter.Title ?? ''),
            context: context,
          ));
        }
      }
    } catch (e) {
      print('EPUB: Search error: $e');
    }
    
    return results;
  }
  
  @override
  void onTextSelected(String selectedText, Offset position) {
    _selectedText = selectedText;
    print('EPUB: onTextSelected called with: "$selectedText" at $position');
    print('EPUB: Callback available: ${onTextSelectionCallback != null}');
    
    if (onTextSelectionCallback != null) {
      print('EPUB: Triggering callback!');
      onTextSelectionCallback!(selectedText, position);
    } else {
      print('EPUB: No callback set - this is the problem!');
    }
  }
  
  /// Set text selection callback
  void setTextSelectionCallback(Function(String text, Offset position)? callback) {
    print('EPUB: setTextSelectionCallback called with callback: ${callback != null}');
    onTextSelectionCallback = callback;
    print('EPUB: Callback stored, available: ${onTextSelectionCallback != null}');
  }
}