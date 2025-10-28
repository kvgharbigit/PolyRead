// Book Reader Widget
// Main reading interface that handles both PDF and EPUB

import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show TextSelection; // Provided by material.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/engines/pdf_reader_engine.dart';
import 'package:polyread/features/reader/engines/epub_reader_engine.dart';
import 'package:polyread/features/reader/engines/html_reader_engine.dart';
import 'package:polyread/features/reader/engines/txt_reader_engine.dart';
import 'package:polyread/features/reader/services/reading_progress_service.dart';
// import 'package:polyread/features/reader/widgets/interactive_text.dart'; // Not currently used
import 'package:polyread/features/reader/widgets/table_of_contents_dialog.dart';
import 'package:polyread/features/reader/widgets/reader_settings_dialog.dart';
import 'package:polyread/features/reader/models/reader_settings.dart';
// import 'package:polyread/features/reader/widgets/bookmarks_dialog.dart';
// import 'package:polyread/features/reader/services/bookmark_service.dart';
import 'package:polyread/features/translation/widgets/translation_popup.dart';
import 'package:polyread/features/translation/services/drift_translation_service.dart';
// import 'package:polyread/features/translation/services/dictionary_service.dart'; // Not currently used
// import 'package:polyread/features/translation/services/translation_cache_service.dart'; // Not currently used
import 'package:polyread/features/vocabulary/services/drift_vocabulary_service.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/providers/database_provider.dart';
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
  DriftTranslationService? _translationService;
  // DriftVocabularyService? _vocabularyService;
  // BookmarkService? _bookmarkService;
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
  final String _sourceLanguage = 'en';
  final String _targetLanguage = 'es';
  
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
    _translationService?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeReader() async {
    try {
      final database = ref.read(databaseProvider);
      _progressService = ReadingProgressService(database);
      // _bookmarkService = BookmarkService(database);
      
      // Initialize translation service with Drift integration
      _translationService = DriftTranslationService(database: database);
      await _translationService!.initialize();
      
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
    // Save progress every 30 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _saveProgress();
    });
  }
  
  Future<void> _saveProgress() async {
    if (_readerEngine == null || _progressService == null) return;
    
    final sessionTime = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!).inMilliseconds
        : 0;
    
    await _progressService!.saveProgress(
      bookId: widget.book.id,
      position: _readerEngine!.currentPosition,
      progressPercentage: _readerEngine!.progress,
      readingTimeMs: sessionTime,
      wordsRead: _sessionWordsRead,
      translationsUsed: _sessionTranslations,
    );
  }
  
  void _setupTextSelectionHandlers() {
    if (_readerEngine == null) return;
    
    // Set up the text selection handler for translation
    void handleTextSelection(String text, Offset position, TextSelection selection) {
      if (_translationService == null) return;
      
      // Extract context around the selected text
      final context = _extractContext(text, selection);
      
      setState(() {
        _selectedText = text;
        _tapPosition = position;
        _selectedContext = context;
        _selectedTextSelection = selection;
        _showTranslationPopup = true;
      });
      
      _sessionTranslations++;
    }
    
    // Connect handler to specific engine types
    if (_readerEngine is HtmlReaderEngine) {
      (_readerEngine as HtmlReaderEngine).setTextSelectionHandler(handleTextSelection);
    } else if (_readerEngine is TxtReaderEngine) {
      (_readerEngine as TxtReaderEngine).setTextSelectionHandler(handleTextSelection);
    }
    // PDF and EPUB engines use the default onTextSelected interface method
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
    // For now, return a mock context
    // In a real implementation, this would extract text from the current page/chapter
    return "This is an example sentence containing the word $word for context display.";
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
  
  @override
  Widget build(BuildContext context) {
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
          onPressed: () {
            // TODO: Implement bookmarks after fixing database schema
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bookmarks coming soon')),
            );
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
        // Main reader content wrapped with tap detection
        GestureDetector(
          onTap: () {
            // Close translation popup when tapping outside
            if (_showTranslationPopup) {
              _closeTranslationPopup();
            }
          },
          child: _buildReaderContent(),
        ),
        
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
        
        // Translation popup overlay
        if (_showTranslationPopup && _selectedText != null)
          TranslationPopup(
            selectedText: _selectedText!,
            sourceLanguage: _sourceLanguage,
            targetLanguage: _targetLanguage,
            position: _tapPosition,
            onClose: _closeTranslationPopup,
            onAddToVocabulary: _addToVocabulary,
            translationService: _translationService,
            context: _selectedContext,
            textSelection: _selectedTextSelection,
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
        onSettingsChanged: (newSettings) {
          setState(() {
            _readerSettings = newSettings;
          });
          // TODO: Persist settings to SharedPreferences
        },
      ),
    );
  }
}