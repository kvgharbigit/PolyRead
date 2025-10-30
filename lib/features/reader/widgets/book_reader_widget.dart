// Book Reader Widget
// Main reading interface that handles both PDF and EPUB

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/engines/pdf_reader_engine.dart';
import 'package:polyread/features/reader/engines/epub_reader_engine.dart';
import 'package:polyread/features/reader/engines/html_reader_engine.dart';
import 'package:polyread/features/reader/engines/txt_reader_engine.dart';
import 'package:polyread/features/reader/services/reading_progress_service.dart';
import 'package:polyread/features/reader/widgets/table_of_contents_dialog.dart';
import 'package:polyread/features/reader/widgets/reader_settings_dialog.dart';
import 'package:polyread/features/reader/models/reader_settings.dart';
import 'package:polyread/features/reader/services/reader_settings_service.dart';
import 'package:polyread/features/reader/services/auto_scroll_service.dart';
import 'package:polyread/features/reader/widgets/bookmarks_dialog.dart';
import 'package:polyread/features/reader/services/bookmark_service.dart';
import 'package:polyread/features/translation/widgets/cycling_translation_popup.dart';
import 'package:polyread/features/reader/providers/reader_translation_provider.dart';
import 'package:polyread/features/vocabulary/services/drift_vocabulary_service.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/providers/database_provider.dart';
import 'package:polyread/core/providers/settings_provider.dart';
import 'package:polyread/core/utils/constants.dart';

class BookReaderWidget extends ConsumerStatefulWidget {
  final Book book;
  final ReaderPosition? initialPosition;
  
  const BookReaderWidget({
    super.key,
    required this.book,
    this.initialPosition,
  });

  @override
  ConsumerState<BookReaderWidget> createState() => _BookReaderWidgetState();
}

class _BookReaderWidgetState extends ConsumerState<BookReaderWidget> {
  ReaderEngine? _readerEngine;
  ReadingProgressService? _progressService;
  dynamic _translationService;
  // DriftVocabularyService? _vocabularyService;
  BookmarkService? _bookmarkService;
  ReaderSettingsService? _settingsService;
  AutoScrollService? _autoScrollService;
  Timer? _progressTimer;
  DateTime? _sessionStartTime;
  bool _isLoading = true;
  String? _error;
  
  // Reading session tracking
  final int _sessionWordsRead = 0; // TODO: Implement word counting
  int _sessionTranslations = 0;
  
  // Translation popup state
  bool _showTranslationPopup = false;
  String? _selectedText;
  String? _selectedContext;
  TextSelection? _selectedTextSelection;
  Offset _tapPosition = Offset.zero;
  String _sourceLanguage = 'en'; // Will be set from book/settings
  String _homeLanguage = 'en'; // User's home language from settings
  
  // Reader settings
  ReaderSettings _readerSettings = ReaderSettings.defaultSettings();
  
  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _initializeReader();
  }
  
  @override
  void dispose() {
    _progressTimer?.cancel();
    _readerEngine?.dispose();
    // Don't dispose translation service here - it's managed by Riverpod
    _settingsService?.dispose();
    _autoScrollService?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeReader() async {
    try {
      final database = ref.read(databaseProvider);
      _progressService = ReadingProgressService(database);
      _bookmarkService = BookmarkService(database);
      
      // Initialize settings service
      _settingsService = ReaderSettingsService();
      await _settingsService!.initialize();
      _readerSettings = _settingsService!.currentSettings;
      
      // Get language settings
      final appSettings = ref.read(settingsProvider);
      _homeLanguage = appSettings.defaultTargetLanguage;
      _sourceLanguage = appSettings.defaultSourceLanguage == 'auto' ? 'en' : appSettings.defaultSourceLanguage;
      
      print('BookReader: Language settings - Source: $_sourceLanguage, Home: $_homeLanguage');
      
      // Alert user if target language is not English
      if (_homeLanguage != 'en') {
        print('BookReader: WARNING - Target language is set to "$_homeLanguage" instead of "en" (English)');
        print('BookReader: This will translate TO $_homeLanguage instead of TO English');
        print('BookReader: Change your target language to "en" in settings if you want translations to English');
      }
      
      // Initialize auto-scroll service
      _autoScrollService = AutoScrollService();
      
      // Initialize reader translation service with book context
      _translationService = ref.read(readerTranslationServiceProvider);
      await _translationService!.initialize();
      
      // Set current book context for vocabulary
      _translationService!.setCurrentBook(
        widget.book.id,
        bookTitle: widget.book.title,
      );
      
      // Initialize vocabulary service
      // _vocabularyService = DriftVocabularyService(database);
      
      // Create appropriate reader engine
      if (widget.book.fileType == 'pdf') {
        _readerEngine = PdfReaderEngine();
      } else if (widget.book.fileType == 'epub') {
        _readerEngine = EpubReaderEngine();
      } else if (widget.book.fileType == 'html' || widget.book.fileType == 'htm') {
        _readerEngine = HtmlReaderEngine();
      } else if (widget.book.fileType == 'txt') {
        _readerEngine = TxtReaderEngine();
      } else {
        throw Exception('Unsupported file type: ${widget.book.fileType}');
      }
      
      // Initialize the engine
      await _readerEngine!.initialize(widget.book.filePath);
      
      // Apply current settings to the engine
      await _applySettingsToEngine();
      
      // Set up text selection handlers for translation
      _setupTextSelectionHandlers();
      
      // Set initial position if provided
      if (widget.initialPosition != null) {
        await _readerEngine!.goToPosition(widget.initialPosition!);
      }
      
      // Start progress tracking
      _startProgressTracking();
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }
  
  void _startProgressTracking() {
    // Save progress periodically 
    _progressTimer = Timer.periodic(
      Duration(seconds: AppConstants.progressSaveIntervalSeconds), 
      (timer) => _saveProgress(),
    );
  }
  
  Future<void> _saveProgress() async {
    if (_readerEngine == null || _progressService == null) return;
    
    final sessionTime = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!).inMilliseconds
        : 0;
    
    final currentPosition = _readerEngine!.currentPosition;
    
    // Update translation service with current position for vocabulary context
    _translationService?.updateReaderPosition(currentPosition.toString());
    
    await _progressService!.saveProgress(
      bookId: widget.book.id,
      position: currentPosition,
      progressPercentage: _readerEngine!.progress,
      readingTimeMs: sessionTime,
      wordsRead: _sessionWordsRead,
      translationsUsed: _sessionTranslations,
    );
  }
  
  void _setupTextSelectionHandlers() {
    if (_readerEngine == null) return;
    
    // Set up the text selection handler for translation
    void handleTextSelection(String text, Offset position, TextSelection selection) async {
      print('BookReader: handleTextSelection called with "$text"');
      
      // Validate that we have actual meaningful text
      final trimmedText = text.trim();
      if (trimmedText.isEmpty || trimmedText.length < 1) {
        print('BookReader: No meaningful text selected, ignoring tap');
        return;
      }
      
      // Check if text contains only whitespace or special characters
      if (!RegExp(r'[a-zA-Z]').hasMatch(trimmedText)) {
        print('BookReader: Text contains no letters, ignoring tap: "$trimmedText"');
        return;
      }
      
      // Check if text is too long (likely accidental selection)
      if (trimmedText.length > 50) {
        print('BookReader: Text too long, likely accidental selection: ${trimmedText.length} chars');
        return;
      }
      
      if (_translationService == null) {
        print('BookReader: Translation service is null!');
        return;
      }
      
      print('BookReader: Translation service available, processing...');
      
      // Extract context around the selected text
      final context = _extractContext(text, selection);
      
      setState(() {
        _selectedText = trimmedText; // Use trimmed text
        _tapPosition = position;
        _selectedContext = context;
        _selectedTextSelection = selection;
        _showTranslationPopup = true;
      });
      
      print('BookReader: Translation popup shown, starting translation...');
      
      // Note: Translation will be performed by the CyclingTranslationPopup widget
      // No need to call translation service here as it would duplicate the call
      
      _sessionTranslations++;
    }
    
    // Connect handler to specific engine types
    if (_readerEngine is HtmlReaderEngine) {
      (_readerEngine as HtmlReaderEngine).setTextSelectionHandler(handleTextSelection);
    } else if (_readerEngine is TxtReaderEngine) {
      (_readerEngine as TxtReaderEngine).setTextSelectionHandler(handleTextSelection);
    } else if (_readerEngine is EpubReaderEngine) {
      // Set up callback for EPUB engine
      print('BookReader: Setting EPUB text selection callback');
      (_readerEngine as EpubReaderEngine).setTextSelectionCallback((text, position) {
        print('BookReader: EPUB callback triggered with text: "$text"');
        handleTextSelection(text, position, TextSelection(baseOffset: 0, extentOffset: text.length));
      });
    } else if (_readerEngine is PdfReaderEngine) {
      // Set up callback for PDF engine  
      print('BookReader: Setting PDF text selection callback');
      (_readerEngine as PdfReaderEngine).setTextSelectionCallback((text, position) {
        print('BookReader: PDF callback triggered with text: $text');
        handleTextSelection(text, position, TextSelection(baseOffset: 0, extentOffset: text.length));
      });
    }
  }
  
  // Translation event handlers - TODO: Connect to reader engines when needed
  /*
  void _handleWordTap(String word, Offset position, TextSelection selection) {
    if (_translationService == null) return;
    
    // Extract context around the word for sentence translation
    final context = _extractContext(word, selection);
    
    setState(() {
      _selectedText = word;
      _tapPosition = position;
      _selectedContext = context;
      _selectedTextSelection = selection;
      _showTranslationPopup = true;
    });
    
    _sessionTranslations++;
  }
  
  void _handleSentenceTap(String sentence, Offset position, TextSelection selection) {
    if (_translationService == null) return;
    
    setState(() {
      _selectedText = sentence;
      _tapPosition = position;
      _selectedContext = sentence; // For sentence tap, the selected text is the context
      _selectedTextSelection = selection;
      _showTranslationPopup = true;
    });
    
    _sessionTranslations++;
  }
  */
  
  String? _extractContext(String word, TextSelection selection) {
    // Use the reader engine to extract context around the word
    if (_readerEngine == null) return null;
    
    try {
      return _readerEngine!.extractContextAroundWord(word, contextWords: 8);
    } catch (e) {
      print('BookReader: Failed to extract context: $e');
      return null;
    }
  }
  
  void _closeTranslationPopup() {
    setState(() {
      _showTranslationPopup = false;
      _selectedText = null;
      _selectedContext = null;
      _selectedTextSelection = null;
    });
  }
  
  void _addToVocabulary(String word) {
    // TODO: Implement vocabulary service integration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$word" to vocabulary')),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_bookmarkService == null || _readerEngine == null) return;
    
    try {
      final currentPosition = _readerEngine!.currentPosition;
      final result = await _bookmarkService!.toggleBookmark(
        bookId: widget.book.id,
        position: currentPosition,
        title: null, // Will generate default title
        excerpt: _readerEngine!.getSelectedText(), // Use current selection if available
      );
      
      final message = result.wasAdded
          ? 'Bookmark added at ${result.bookmark.displayTitle}'
          : 'Bookmark removed from ${result.bookmark.displayTitle}';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error managing bookmark: $e')),
      );
    }
  }

  void _showBookmarks() {
    if (_bookmarkService == null || _readerEngine == null) return;
    
    showDialog(
      context: context,
      builder: (context) => BookmarksDialog(
        bookId: widget.book.id,
        bookTitle: widget.book.title,
        bookmarkService: _bookmarkService!,
        currentPosition: _readerEngine!.currentPosition,
        onNavigate: (position) async {
          await _readerEngine!.goToPosition(position);
          setState(() {}); // Refresh UI with new position
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Update translation service context for dialog prompts (only if context changed)
    if (_translationService != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _translationService?.setContext(context);
      });
    }
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading book...'),
            ],
          ),
        ),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load book',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Theme(
      data: _readerSettings.getThemeData(context),
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildReaderBody(),
        bottomNavigationBar: _buildBottomControls(),
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.book.title,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.bookmark_outline),
          onPressed: () async {
            if (_bookmarkService != null && _readerEngine != null) {
              await _toggleBookmark();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bookmark service not available')),
              );
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            _showSearchDialog();
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'toc':
                _showTableOfContents();
                break;
              case 'bookmarks':
                _showBookmarks();
                break;
              case 'settings':
                _showReaderSettings();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'toc',
              child: ListTile(
                leading: Icon(Icons.list),
                title: Text('Table of Contents'),
              ),
            ),
            const PopupMenuItem(
              value: 'bookmarks',
              child: ListTile(
                leading: Icon(Icons.bookmarks),
                title: Text('Bookmarks'),
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.tune),
                title: Text('Reading Settings'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildReaderBody() {
    if (_readerEngine == null) {
      return const Center(child: Text('Reader not initialized'));
    }
    
    return Stack(
      children: [
        // Main reader content
        _buildReaderContent(),
        
        // Reading progress indicator
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 4,
            color: Colors.grey.shade300,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _readerEngine!.progress,
              child: Container(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
        
        // Translation popup overlay with tap-outside-to-dismiss
        if (_showTranslationPopup && _selectedText != null)
          Stack(
            children: [
              // Full-screen transparent overlay for dismissal
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeTranslationPopup,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Actual popup positioned normally
              CyclingTranslationPopup(
                key: ValueKey('translation_$_selectedText'),
                selectedText: _selectedText!,
                sourceLanguage: _sourceLanguage,
                targetLanguage: _homeLanguage,
                position: _tapPosition,
                onClose: _closeTranslationPopup,
                translationService: _translationService,
                context: _selectedContext,
              ),
            ],
          ),
      ],
    );
  }
  
  Widget _buildReaderContent() {
    // For now, return the engine's reader wrapped with interactive text
    // This is a simplified version - in reality, we'd need to extract
    // text from PDF/EPUB engines and wrap it with InteractiveText
    return _readerEngine!.buildReader(context);
  }
  
  Widget _buildBottomControls() {
    if (_readerEngine == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () async {
              await _readerEngine!.goToPrevious();
              setState(() {}); // Update progress
            },
          ),
          
          // Position indicator
          Expanded(
            child: Text(
              _readerEngine!.currentPosition.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          
          // Next button
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () async {
              await _readerEngine!.goToNext();
              setState(() {}); // Update progress
            },
          ),
        ],
      ),
    );
  }
  
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter search term...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (query) async {
            Navigator.of(context).pop();
            if (query.isNotEmpty && _readerEngine != null) {
              final results = await _readerEngine!.search(query);
              _showSearchResults(results);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showSearchResults(List<SearchResult> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Results (${results.length})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return ListTile(
                title: Text(result.text),
                subtitle: Text(
                  result.context,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _readerEngine!.goToPosition(result.position);
                  setState(() {});
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showTableOfContents() {
    if (_readerEngine == null) return;
    
    showDialog(
      context: context,
      builder: (context) => TableOfContentsDialog(
        readerEngine: _readerEngine!,
        onNavigate: (position) async {
          await _readerEngine!.goToPosition(position);
          setState(() {}); // Refresh UI with new position
        },
      ),
    );
  }
  
  void _showReaderSettings() {
    showDialog(
      context: context,
      builder: (context) => ReaderSettingsDialog(
        initialSettings: _readerSettings,
        onSettingsChanged: (newSettings) async {
          await _updateSettings(newSettings);
        },
      ),
    );
  }

  /// Apply settings to the current reader engine
  Future<void> _applySettingsToEngine() async {
    if (_readerEngine == null || _settingsService == null) return;
    
    final engineSettings = _settingsService!.getEngineSettings(widget.book.fileType);
    
    // Apply settings based on engine type
    if (_readerEngine is HtmlReaderEngine) {
      await (_readerEngine as HtmlReaderEngine).applySettings(engineSettings);
    } else if (_readerEngine is TxtReaderEngine) {
      await (_readerEngine as TxtReaderEngine).applySettings(engineSettings);
    }
    // PDF and EPUB engines would need similar integration
  }

  /// Update settings and apply them
  Future<void> _updateSettings(ReaderSettings newSettings) async {
    if (_settingsService == null) return;
    
    // Update settings service
    await _settingsService!.updateSettings(newSettings);
    
    // Update local state
    setState(() {
      _readerSettings = newSettings;
    });
    
    // Apply new settings to the current engine
    await _applySettingsToEngine();
    
    // Handle auto-scroll settings
    if (newSettings.autoScroll && _autoScrollService != null && _readerEngine != null) {
      _autoScrollService!.startAutoScroll(
        readerEngine: _readerEngine!,
        speed: newSettings.autoScrollSpeed,
      );
    } else if (!newSettings.autoScroll) {
      _autoScrollService?.stopAutoScroll();
    }
  }
}