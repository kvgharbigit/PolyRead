// EPUB Reader Engine
// EPUB viewing and interaction using epub_view package

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
  bool _useWebView = true; // Use WebView for better text selection
  
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
      
      // Initialize controllers
      if (_useWebView) {
        await _initializeWebView();
      } else {
        _controller = EpubController(
          document: EpubDocument.openData(bytes),
        );
      }
      
      // Set first chapter as current
      final chapters = _book?.Chapters;
      if (chapters != null && chapters.isNotEmpty) {
        _currentChapter = chapters.first.Title ?? '';
        _currentChapterIndex = 0;
        
        if (_useWebView) {
          await _loadCurrentChapterInWebView();
        }
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
    if (_webViewController == null || _book?.Chapters?.isEmpty == true) return;

    final chapters = _book?.Chapters;
    final webViewController = _webViewController;
    
    if (chapters == null || _currentChapterIndex >= chapters.length || webViewController == null) {
      throw Exception('Invalid EPUB state: missing chapters or webview controller');
    }
    
    final currentChapter = chapters[_currentChapterIndex];
    final htmlContent = currentChapter.HtmlContent ?? '';
    
    // Create full HTML document with text selection JavaScript
    final fullHtml = _createChapterHtml(htmlContent);
    
    await webViewController.loadHtmlString(fullHtml);
  }

  String _createChapterHtml(String chapterContent) {
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
    _controller?.dispose();
    _controller = null;
    _webViewController = null;
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
    if (_book?.Chapters != null) {
      final chapters = _book!.Chapters!;
      
      if (_currentChapterIndex < chapters.length - 1) {
        _currentChapterIndex++;
        _currentChapter = chapters[_currentChapterIndex].Title ?? '';
        
        if (_useWebView) {
          await _loadCurrentChapterInWebView();
        } else if (_controller != null) {
          await _controller!.scrollTo(
            index: _currentChapterIndex,
            duration: const Duration(milliseconds: 300),
          );
        }
        return true;
      }
    }
    return false;
  }
  
  @override
  Future<bool> goToPrevious() async {
    if (_book?.Chapters != null) {
      if (_currentChapterIndex > 0) {
        _currentChapterIndex--;
        _currentChapter = _book!.Chapters![_currentChapterIndex].Title ?? '';
        
        if (_useWebView) {
          await _loadCurrentChapterInWebView();
        } else if (_controller != null) {
          await _controller!.scrollTo(
            index: _currentChapterIndex,
            duration: const Duration(milliseconds: 300),
          );
        }
        return true;
      }
    }
    return false;
  }
  
  @override
  String? getSelectedText() => _selectedText;
  
  @override
  String? extractContextAroundWord(String word, {int contextWords = 10}) {
    // For EPUB, we need to extract context from the currently loaded chapter
    if (_book?.Chapters?.isEmpty == true) return null;
    
    final currentChapter = _book!.Chapters![_currentChapterIndex];
    final htmlContent = currentChapter.HtmlContent ?? '';
    
    if (htmlContent.isEmpty) return null;
    
    // Simple text extraction from HTML (removes tags)
    final text = htmlContent.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final words = text.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
    
    // Find word position
    final wordIndex = words.indexWhere((w) => w.toLowerCase().contains(word.toLowerCase()));
    if (wordIndex == -1) return null;
    
    // Extract context
    final startIndex = (wordIndex - contextWords).clamp(0, words.length);
    final endIndex = (wordIndex + contextWords + 1).clamp(0, words.length);
    
    return words.sublist(startIndex, endIndex).join(' ');
  }
  
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
    if (_useWebView) {
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
      
      return Column(
        children: [
          // Navigation controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _currentChapterIndex > 0 ? () => goToPrevious() : null,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    _currentChapter,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: _currentChapterIndex < (totalPages - 1) ? () => goToNext() : null,
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
    } else {
      // Fallback to epub_view
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
      
      return Stack(
        children: [
          EpubView(
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
          ),
          // Overlay gesture detector for text selection
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) => _handleTap(details),
              behavior: HitTestBehavior.translucent,
            ),
          ),
        ],
      );
    }
  }
  
  /// Handle tap for text selection (fallback for non-WebView mode)
  Future<void> _handleTap(TapDownDetails details) async {
    final position = details.localPosition;
    
    print('EPUB tap detected at position: $position (fallback mode)'); // Debug
    
    // This is only used when WebView mode is disabled
    // WebView mode handles text selection via JavaScript
    if (!_useWebView) {
      final word = await _getWordAtPosition(position);
      
      print('EPUB extracted word: $word'); // Debug
      
      if (word != null && word.isNotEmpty) {
        _selectedText = word;
        print('EPUB calling onTextSelected with: $word'); // Debug
        onTextSelected(word, position);
      } else {
        print('EPUB: No word found at position'); // Debug
      }
    }
  }
  
  /// Extract word from current chapter at tap position
  Future<String?> _getWordAtPosition(Offset position) async {
    final currentChapter = currentChapterInfo;
    if (currentChapter == null) return null;
    
    // Get chapter text content
    final htmlContent = currentChapter.HtmlContent ?? '';
    
    // More sophisticated text processing to preserve structure
    String processedText = htmlContent;
    
    // Replace paragraph and line breaks with markers to preserve text flow
    processedText = processedText.replaceAll(RegExp(r'<p[^>]*>'), '\n¶ ');
    processedText = processedText.replaceAll(RegExp(r'</p>'), ' ¶\n');
    processedText = processedText.replaceAll(RegExp(r'<br[^>]*>'), '\n');
    
    // Remove other HTML tags but preserve the text structure
    processedText = processedText.replaceAll(RegExp(r'<[^>]*>'), ' ');
    
    // Split into lines and then words, preserving line structure
    final lines = processedText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final wordsWithLineInfo = <({String word, int lineIndex, int wordIndex})>[];
    
    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final lineWords = lines[lineIndex].split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .map((word) => word.replaceAll(RegExp(r'[^\w]'), ''))
          .where((word) => word.isNotEmpty)
          .toList();
      
      for (int wordIndex = 0; wordIndex < lineWords.length; wordIndex++) {
        wordsWithLineInfo.add((
          word: lineWords[wordIndex], 
          lineIndex: lineIndex, 
          wordIndex: wordIndex
        ));
      }
    }
    
    if (wordsWithLineInfo.isEmpty) return null;
    
    // Estimate text layout based on typical reading dimensions
    const double estimatedLineHeight = 24.0; // Typical line height
    const double estimatedCharWidth = 8.0; // Typical character width
    const double leftMargin = 20.0; // Typical left margin
    
    // Find the line that the tap position falls on
    final tappedLineIndex = ((position.dy - 50) / estimatedLineHeight).floor().clamp(0, lines.length - 1);
    
    // Find words on or near the tapped line
    final candidateWords = wordsWithLineInfo.where((wordInfo) {
      final lineDiff = (wordInfo.lineIndex - tappedLineIndex).abs();
      return lineDiff <= 2; // Allow ±2 lines tolerance
    }).toList();
    
    if (candidateWords.isEmpty) {
      // Fallback to any word if no candidates found
      final fallbackIndex = ((position.dx + position.dy) / 100).round() % wordsWithLineInfo.length;
      return wordsWithLineInfo[fallbackIndex].word;
    }
    
    // Estimate horizontal position within the line
    final estimatedCharPosition = ((position.dx - leftMargin) / estimatedCharWidth).floor();
    
    // Find the word closest to the estimated character position
    String bestWord = candidateWords.first.word;
    int bestScore = 1000000;
    
    for (final wordInfo in candidateWords) {
      final lineWords = lines[wordInfo.lineIndex].split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty).toList();
      
      // Calculate approximate character position of this word in the line
      int charPosition = 0;
      for (int i = 0; i < wordInfo.wordIndex && i < lineWords.length; i++) {
        charPosition += lineWords[i].length + 1; // +1 for space
      }
      
      final distance = (charPosition - estimatedCharPosition).abs();
      if (distance < bestScore) {
        bestScore = distance;
        bestWord = wordInfo.word;
      }
    }
    
    print('EPUB: Tap at (${position.dx.toInt()}, ${position.dy.toInt()}) → line $tappedLineIndex, char ~$estimatedCharPosition → "$bestWord"');
    
    return bestWord;
  }
  
  @override
  void onTextSelected(String selectedText, Offset position) {
    _selectedText = selectedText;
    
    print('EPUB onTextSelected called with: $selectedText at $position');
    print('EPUB callback is null: ${onTextSelectionCallback == null}');
    
    // Trigger callback for external handling (will be connected to translation service)
    if (onTextSelectionCallback != null) {
      print('EPUB triggering callback!');
      onTextSelectionCallback!(selectedText, position);
    } else {
      print('EPUB callback is null, not triggering');
    }
  }
  
  /// Callback for text selection events
  Function(String text, Offset position)? onTextSelectionCallback;
  
  /// Set text selection callback
  void setTextSelectionCallback(Function(String text, Offset position)? callback) {
    print('EPUB: setTextSelectionCallback called with callback: ${callback != null}');
    onTextSelectionCallback = callback;
    print('EPUB: callback stored, is null: ${onTextSelectionCallback == null}');
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