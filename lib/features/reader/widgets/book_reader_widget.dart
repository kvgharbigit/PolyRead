// Book Reader Widget
// Main reading interface that handles both PDF and EPUB

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/engines/pdf_reader_engine.dart';
import 'package:polyread/features/reader/engines/epub_reader_engine.dart';
import 'package:polyread/features/reader/services/reading_progress_service.dart';
import 'package:polyread/features/reader/widgets/interactive_text.dart';
import 'package:polyread/features/translation/widgets/translation_popup.dart';
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/dictionary_service.dart';
import 'package:polyread/features/translation/services/translation_cache_service.dart';
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
  TranslationService? _translationService;
  Timer? _progressTimer;
  DateTime? _sessionStartTime;
  bool _isLoading = true;
  String? _error;
  
  // Reading session tracking
  int _sessionWordsRead = 0;
  int _sessionTranslations = 0;
  
  // Translation popup state
  bool _showTranslationPopup = false;
  String? _selectedText;
  Offset _tapPosition = Offset.zero;
  String _sourceLanguage = 'en';
  String _targetLanguage = 'es';
  
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
      
      // Initialize translation service
      final dictionaryService = DictionaryService(database);
      final cacheService = TranslationCacheService(database);
      _translationService = TranslationService(
        dictionaryService: dictionaryService,
        cacheService: cacheService,
      );
      await _translationService!.initialize();
      
      // Create appropriate reader engine
      if (widget.book.fileType == 'pdf') {
        _readerEngine = PdfReaderEngine();
      } else if (widget.book.fileType == 'epub') {
        _readerEngine = EpubReaderEngine();
      } else {
        throw Exception('Unsupported file type: ${widget.book.fileType}');
      }
      
      // Initialize the engine
      await _readerEngine!.initialize(widget.book.filePath);
      
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
  
  // Translation event handlers
  void _handleWordTap(String word, Offset position, TextSelection selection) {
    if (_translationService == null) return;
    
    setState(() {
      _selectedText = word;
      _tapPosition = position;
      _showTranslationPopup = true;
    });
    
    _sessionTranslations++;
  }
  
  void _handleSentenceTap(String sentence, Offset position, TextSelection selection) {
    if (_translationService == null) return;
    
    setState(() {
      _selectedText = sentence;
      _tapPosition = position;
      _showTranslationPopup = true;
    });
    
    _sessionTranslations++;
  }
  
  void _closeTranslationPopup() {
    setState(() {
      _showTranslationPopup = false;
      _selectedText = null;
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
    
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildReaderBody(),
      bottomNavigationBar: _buildBottomControls(),
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
            // TODO: Add bookmark functionality
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
    // TODO: Implement table of contents
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Table of contents coming soon')),
    );
  }
  
  void _showReaderSettings() {
    // TODO: Implement reader settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reader settings coming soon')),
    );
  }
}