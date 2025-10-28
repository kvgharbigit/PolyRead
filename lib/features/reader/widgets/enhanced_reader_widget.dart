// Enhanced Reader Widget
// Integrates reader engines with translation service and UI

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/engines/pdf_reader_engine.dart';
import 'package:polyread/features/reader/engines/epub_reader_engine.dart';
import 'package:polyread/features/reader/engines/html_reader_engine.dart';
import 'package:polyread/features/reader/engines/txt_reader_engine.dart';
import 'package:polyread/features/reader/providers/reader_translation_provider.dart';
import 'package:polyread/features/translation/widgets/enhanced_translation_popup.dart';
import 'package:polyread/core/providers/settings_provider.dart';

class EnhancedReaderWidget extends ConsumerStatefulWidget {
  final String filePath;
  final String fileType;
  final int bookId;

  const EnhancedReaderWidget({
    super.key,
    required this.filePath,
    required this.fileType,
    required this.bookId,
  });

  @override
  ConsumerState<EnhancedReaderWidget> createState() => _EnhancedReaderWidgetState();
}

class _EnhancedReaderWidgetState extends ConsumerState<EnhancedReaderWidget> {
  ReaderEngine? _readerEngine;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeReader();
  }

  @override
  void dispose() {
    _readerEngine?.dispose();
    super.dispose();
  }

  Future<void> _initializeReader() async {
    try {
      // Create appropriate reader engine based on file type
      switch (widget.fileType.toLowerCase()) {
        case 'pdf':
          _readerEngine = PdfReaderEngine();
          break;
        case 'epub':
          _readerEngine = EpubReaderEngine();
          break;
        case 'html':
        case 'htm':
          _readerEngine = HtmlReaderEngine();
          break;
        case 'txt':
          _readerEngine = TxtReaderEngine();
          break;
        default:
          throw Exception('Unsupported file type: ${widget.fileType}');
      }

      // Initialize the reader engine
      await _readerEngine!.initialize(widget.filePath);

      // Set up text selection callback for translation
      _setupTextSelectionCallback();

      setState(() {
        _isInitialized = true;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _setupTextSelectionCallback() {
    final readerEngine = _readerEngine;
    
    // All readers now support the consistent callback interface
    if (readerEngine is PdfReaderEngine) {
      readerEngine.setTextSelectionCallback(_handleTextSelection);
    } else if (readerEngine is EpubReaderEngine) {
      readerEngine.setTextSelectionCallback(_handleTextSelection);
    } else if (readerEngine is HtmlReaderEngine) {
      readerEngine.setTextSelectionCallback(_handleTextSelection);
    } else if (readerEngine is TxtReaderEngine) {
      readerEngine.setTextSelectionCallback(_handleTextSelection);
    }
  }

  void _handleTextSelection(String selectedText, Offset position) {
    final translationService = ref.read(readerTranslationServiceProvider);
    final settings = ref.read(settingsProvider);

    // Set current book for vocabulary creation
    translationService.setCurrentBook(widget.bookId);

    // Handle text selection with translation
    translationService.handleTextSelection(
      selectedText: selectedText,
      position: position,
      sourceLanguage: settings.defaultSourceLanguage,
      targetLanguage: settings.defaultTargetLanguage,
      context: _getSelectionContext(selectedText),
    );
  }

  String? _getSelectionContext(String selectedText) {
    // TODO: Extract surrounding text for better translation context
    // For now, return null
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load file',
              style: Theme.of(context).textTheme.titleLarge,
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
      );
    }

    if (!_isInitialized || _readerEngine == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading book...'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Main reader content
        _readerEngine!.buildReader(context),
        
        // Translation popup overlay
        Consumer(
          builder: (context, ref, child) {
            final translationService = ref.watch(readerTranslationServiceProvider);
            
            if (!translationService.hasSelection || 
                translationService.selectionPosition == null) {
              return const SizedBox.shrink();
            }

            return EnhancedTranslationPopup(
              selectedText: translationService.selectedText!,
              sourceLanguage: ref.read(settingsProvider).defaultSourceLanguage,
              targetLanguage: ref.read(settingsProvider).defaultTargetLanguage,
              position: translationService.selectionPosition!,
              onClose: () => translationService.clearSelection(),
              onAddToVocabulary: (word) => translationService.addToVocabulary(),
              translationService: ref.read(translationServiceProvider),
              enableSynonymCycling: true,
              enableMorphemeAnalysis: true,
            );
          },
        ),
      ],
    );
  }
}