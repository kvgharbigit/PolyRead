// HTML Reader Engine
// Renders HTML files with interactive text selection and translation

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/services/reader_settings_service.dart';
import 'package:polyread/features/reader/models/reader_settings.dart';

class HtmlReaderEngine implements ReaderEngine {
  late WebViewController _webViewController;
  String? _filePath;
  String? _htmlContent;
  int _currentPage = 1;
  final int _totalPages = 1; // HTML is treated as single page
  double _progress = 0.0;
  String? _selectedText;
  ReaderEngineSettings? _settings;
  
  // Text selection tracking
  final ValueNotifier<String?> selectedTextNotifier = ValueNotifier<String?>(null);
  
  // Text selection callback - store reference to external handler
  void Function(String text, Offset position, TextSelection selection)? _textSelectionHandler;

  @override
  Future<void> initialize(String filePath) async {
    _filePath = filePath;
    
    // Read HTML content
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('HTML file not found: $filePath');
    }
    
    _htmlContent = await file.readAsString();
    
    // Apply settings styles if available
    if (_settings != null) {
      _htmlContent = _applySettingsToHtml(_htmlContent!);
    }
    
    // Inject JavaScript for text selection and translation
    _htmlContent = _injectInteractiveScript(_htmlContent!);
    
    // Initialize WebView controller
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _setupTextSelectionHandlers();
          },
        ),
      )
      ..addJavaScriptChannel(
        'TextSelection',
        onMessageReceived: (JavaScriptMessage message) {
          _handleTextSelection(message.message);
        },
      );
    
    // Load HTML content
    await _webViewController.loadHtmlString(_htmlContent!);
  }

  @override
  Future<void> dispose() async {
    selectedTextNotifier.dispose();
  }

  @override
  int get totalPages => _totalPages;

  @override
  ReaderPosition get currentPosition => ReaderPosition(
    pageNumber: _currentPage,
    scrollOffset: _progress,
  );

  @override
  Future<void> goToPosition(ReaderPosition position) async {
    if (position.pageNumber != null) {
      _currentPage = position.pageNumber!;
    }
    
    if (position.scrollOffset != null) {
      _progress = position.scrollOffset!;
      // Scroll to position in WebView
      await _webViewController.runJavaScript('''
        var maxScroll = document.body.scrollHeight - window.innerHeight;
        window.scrollTo(0, ${position.scrollOffset!} * maxScroll);
      ''');
    }
  }

  @override
  Future<bool> goToNext() async {
    // Scroll down by one screen height
    await _webViewController.runJavaScript('''
      window.scrollBy(0, window.innerHeight * 0.8);
      _updateProgress();
    ''');
    return true;
  }

  @override
  Future<bool> goToPrevious() async {
    // Scroll up by one screen height
    await _webViewController.runJavaScript('''
      window.scrollBy(0, -window.innerHeight * 0.8);
      _updateProgress();
    ''');
    return true;
  }

  @override
  String? getSelectedText() => _selectedText;

  @override
  double get progress => _progress;

  @override
  Widget buildReader(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }


  @override
  void onTextSelected(String selectedText, Offset position) {
    // Simple interface implementation - stores selection and notifies via simple callback
    _selectedText = selectedText;
    selectedTextNotifier.value = selectedText;
    
    // Trigger simple callback for external handling (consistent with PDF/EPUB)
    if (onTextSelectionCallback != null) {
      onTextSelectionCallback!(selectedText, position);
    }
    
    // For more complex handling, use the _textSelectionHandler
    if (_textSelectionHandler != null) {
      final textSelection = TextSelection(
        baseOffset: 0,
        extentOffset: selectedText.length,
      );
      _textSelectionHandler!(selectedText, position, textSelection);
    }
  }
  
  /// Callback for text selection events (consistent interface)
  Function(String text, Offset position)? onTextSelectionCallback;
  
  /// Set text selection callback (consistent interface)
  void setTextSelectionCallback(Function(String text, Offset position)? callback) {
    onTextSelectionCallback = callback;
  }

  /// Set a custom text selection handler for advanced functionality
  void setTextSelectionHandler(void Function(String text, Offset position, TextSelection selection)? handler) {
    _textSelectionHandler = handler;
  }

  /// Apply reader settings to the engine
  Future<void> applySettings(ReaderEngineSettings settings) async {
    _settings = settings;
    
    if (_htmlContent != null) {
      // Re-apply settings to HTML content
      final updatedContent = _applySettingsToHtml(_htmlContent!);
      await _webViewController.loadHtmlString(updatedContent);
    }
  }

  /// Apply settings styles to HTML content
  String _applySettingsToHtml(String htmlContent) {
    if (_settings == null) return htmlContent;
    
    final cssStyles = _settings!.getCssStyles();
    
    // Inject CSS styles
    final styleTag = '<style type="text/css">$cssStyles</style>';
    
    if (htmlContent.contains('</head>')) {
      return htmlContent.replaceFirst('</head>', '$styleTag</head>');
    } else if (htmlContent.contains('<body')) {
      return htmlContent.replaceFirst('<body', '$styleTag<body');
    } else {
      return '$styleTag$htmlContent';
    }
  }

  @override
  Future<List<SearchResult>> search(String query) async {
    final results = <SearchResult>[];
    
    if (_htmlContent == null) return results;
    
    // Simple text search implementation
    final text = _htmlContent!.toLowerCase();
    final searchQuery = query.toLowerCase();
    int index = 0;
    
    while ((index = text.indexOf(searchQuery, index)) != -1) {
      // Extract context around the match
      final start = (index - 50).clamp(0, text.length);
      final end = (index + searchQuery.length + 50).clamp(0, text.length);
      final context = _htmlContent!.substring(start, end);
      
      results.add(SearchResult(
        text: query,
        position: ReaderPosition(pageNumber: 1, scrollOffset: index / text.length),
        context: context,
      ));
      
      index += searchQuery.length;
    }
    
    return results;
  }

  String _injectInteractiveScript(String htmlContent) {
    const script = '''
<script>
let selectedText = '';
let selectionStartPos = null;

// Update reading progress
function _updateProgress() {
  const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
  const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
  const progress = scrollHeight > 0 ? scrollTop / scrollHeight : 0;
  
  // Send progress to Flutter
  if (window.TextSelection) {
    window.TextSelection.postMessage(JSON.stringify({
      type: 'progress',
      value: progress
    }));
  }
}

// Handle text selection
function handleTextSelection() {
  const selection = window.getSelection();
  if (selection.rangeCount > 0) {
    const range = selection.getRangeAt(0);
    const text = selection.toString().trim();
    
    if (text.length > 0) {
      selectedText = text;
      
      // Get selection position
      const rect = range.getBoundingClientRect();
      const position = {
        x: rect.left + rect.width / 2,
        y: rect.top - 10
      };
      
      // Send selection to Flutter
      if (window.TextSelection) {
        window.TextSelection.postMessage(JSON.stringify({
          type: 'selection',
          text: text,
          position: position,
          startOffset: range.startOffset,
          endOffset: range.endOffset
        }));
      }
    }
  }
}

// Word-level tap detection
function handleWordTap(event) {
  const range = document.caretRangeFromPoint(event.clientX, event.clientY);
  if (range) {
    // Expand range to word boundaries
    const textNode = range.startContainer;
    if (textNode.nodeType === Node.TEXT_NODE) {
      const text = textNode.textContent;
      let start = range.startOffset;
      let end = range.startOffset;
      
      // Find word boundaries
      while (start > 0 && /\\w/.test(text[start - 1])) start--;
      while (end < text.length && /\\w/.test(text[end])) end++;
      
      const word = text.substring(start, end).trim();
      if (word.length > 0) {
        // Send word tap to Flutter
        if (window.TextSelection) {
          window.TextSelection.postMessage(JSON.stringify({
            type: 'wordTap',
            text: word,
            position: { x: event.clientX, y: event.clientY },
            startOffset: start,
            endOffset: end
          }));
        }
      }
    }
  }
}

// Event listeners
document.addEventListener('mouseup', handleTextSelection);
document.addEventListener('touchend', handleTextSelection);
document.addEventListener('click', handleWordTap);
document.addEventListener('scroll', _updateProgress);

// Initialize progress
window.addEventListener('load', _updateProgress);
</script>
''';

    // Inject script before closing head tag or at the end of body
    if (htmlContent.contains('</head>')) {
      return htmlContent.replaceFirst('</head>', '$script</head>');
    } else if (htmlContent.contains('</body>')) {
      return htmlContent.replaceFirst('</body>', '$script</body>');
    } else {
      return htmlContent + script;
    }
  }

  Future<void> _setupTextSelectionHandlers() async {
    // Additional setup if needed
    await _webViewController.runJavaScript('_updateProgress();');
  }

  void _handleTextSelection(String message) {
    try {
      final data = Map<String, dynamic>.from(
        // Simple JSON parsing - in production, use a proper JSON parser
        _parseSimpleJson(message)
      );
      
      switch (data['type']) {
        case 'progress':
          _progress = (data['value'] as num).toDouble();
          break;
          
        case 'selection':
          _selectedText = data['text'] as String?;
          selectedTextNotifier.value = _selectedText;
          
          if (_selectedText != null) {
            final position = data['position'] as Map<String, dynamic>?;
            final offset = position != null 
                ? Offset(
                    (position['x'] as num).toDouble(),
                    (position['y'] as num).toDouble(),
                  )
                : Offset.zero;
            
            // Trigger consistent callback interface (same as PDF/EPUB/TXT)
            if (onTextSelectionCallback != null) {
              onTextSelectionCallback!(_selectedText!, offset);
            }
            
            // Also trigger advanced handler if available
            if (_textSelectionHandler != null) {
              final textSelection = TextSelection(
                baseOffset: (data['startOffset'] as num?)?.toInt() ?? 0,
                extentOffset: (data['endOffset'] as num?)?.toInt() ?? 0,
              );
              
              _textSelectionHandler!(_selectedText!, offset, textSelection);
            }
          }
          break;
          
        case 'wordTap':
          _selectedText = data['text'] as String?;
          selectedTextNotifier.value = _selectedText;
          
          if (_selectedText != null) {
            final position = data['position'] as Map<String, dynamic>?;
            final offset = position != null 
                ? Offset(
                    (position['x'] as num).toDouble(),
                    (position['y'] as num).toDouble(),
                  )
                : Offset.zero;
            
            // Trigger consistent callback interface (same as PDF/EPUB/TXT)
            if (onTextSelectionCallback != null) {
              onTextSelectionCallback!(_selectedText!, offset);
            }
            
            // Also trigger advanced handler if available
            if (_textSelectionHandler != null) {
              final textSelection = TextSelection(
                baseOffset: (data['startOffset'] as num?)?.toInt() ?? 0,
                extentOffset: (data['endOffset'] as num?)?.toInt() ?? 0,
              );
              
              _textSelectionHandler!(_selectedText!, offset, textSelection);
            }
          }
          break;
      }
    } catch (e) {
      print('Error handling text selection: $e');
    }
  }

  @override
  String? extractContextAroundWord(String word, {int contextWords = 10}) {
    // Extract context from HTML content
    if (_htmlContent == null) return null;
    
    // Remove HTML tags and extract text
    final text = _htmlContent!.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final words = text.split(RegExp(r'\s+'));
    
    final wordIndex = words.indexWhere((w) => w.toLowerCase().contains(word.toLowerCase()));
    if (wordIndex == -1) return null;
    
    // Extract context around the word
    final startIndex = (wordIndex - contextWords).clamp(0, words.length);
    final endIndex = (wordIndex + contextWords + 1).clamp(0, words.length);
    
    return words.sublist(startIndex, endIndex).join(' ');
  }

  // Simple JSON parser for basic cases
  Map<String, dynamic> _parseSimpleJson(String json) {
    // This is a simplified parser - in production, use dart:convert
    final map = <String, dynamic>{};
    
    // Remove braces and split by commas
    final content = json.replaceAll(RegExp(r'[{}]'), '');
    final pairs = content.split(',');
    
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0].trim().replaceAll('"', '');
        var value = parts[1].trim().replaceAll('"', '');
        
        // Try to parse as number
        if (double.tryParse(value) != null) {
          map[key] = double.parse(value);
        } else {
          map[key] = value;
        }
      }
    }
    
    return map;
  }
}