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
import 'package:polyread/features/translation/widgets/cycling_translation_popup.dart';
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
      print('EnhancedReader: About to setup text selection callback');
      _setupTextSelectionCallback();
      print('EnhancedReader: Callback setup complete');

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
    
    print('EnhancedReader: Setting up text selection callback for ${readerEngine.runtimeType}');
    
    // All readers now support the consistent callback interface
    if (readerEngine is PdfReaderEngine) {
      print('EnhancedReader: Setting PDF callback');
      readerEngine.setTextSelectionCallback(_handleTextSelection);
    } else if (readerEngine is EpubReaderEngine) {
      print('EnhancedReader: Setting EPUB callback');
      readerEngine.setTextSelectionCallback(_handleTextSelection);
    } else if (readerEngine is HtmlReaderEngine) {
      print('EnhancedReader: Setting HTML callback');
      readerEngine.setTextSelectionCallback(_handleTextSelection);
    } else if (readerEngine is TxtReaderEngine) {
      print('EnhancedReader: Setting TXT callback');
      readerEngine.setTextSelectionCallback(_handleTextSelection);
    }
  }

  void _handleTextSelection(String selectedText, Offset position) {
    print('EnhancedReader: _handleTextSelection called with: $selectedText at $position');
    
    // Validate that we have actual meaningful text
    final trimmedText = selectedText.trim();
    if (trimmedText.isEmpty || trimmedText.length < 1) {
      print('EnhancedReader: No meaningful text selected, ignoring tap');
      return;
    }
    
    // Check if text contains only whitespace or special characters
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmedText)) {
      print('EnhancedReader: Text contains no letters, ignoring tap: "$trimmedText"');
      return;
    }
    
    // Check if text is too long (likely accidental selection)
    if (trimmedText.length > 50) {
      print('EnhancedReader: Text too long, likely accidental selection: ${trimmedText.length} chars');
      return;
    }
    
    final translationService = ref.read(readerTranslationServiceProvider);
    final settings = ref.read(settingsProvider);

    print('EnhancedReader: Setting current book ID: ${widget.bookId}');
    
    // Set current book for vocabulary creation
    translationService.setCurrentBook(widget.bookId);

    print('EnhancedReader: Calling translationService.handleTextSelection');
    
    // Handle text selection with translation (use trimmed text)
    translationService.handleTextSelection(
      selectedText: trimmedText,
      position: position,
      sourceLanguage: settings.defaultSourceLanguage,
      targetLanguage: settings.defaultTargetLanguage,
      context: _getSelectionContext(trimmedText),
    );
  }

  String? _getSelectionContext(String selectedText) {
    // TODO: Extract surrounding text for better translation context
    // For now, return null
    return null;
  }

  Widget _buildModelDownloadPrompt(
    BuildContext context,
    WidgetRef ref,
    dynamic translationService,
  ) {
    final settings = ref.read(settingsProvider);
    
    return Positioned(
      left: translationService.selectionPosition!.dx - 150,
      top: translationService.selectionPosition!.dy - 100,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.download_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Translation Models Needed',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => translationService.clearSelection(),
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Download ${settings.defaultSourceLanguage}→${settings.defaultTargetLanguage} translation models for offline translation.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => translationService.clearSelection(),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await translationService.downloadModelsAndRetry(
                        sourceLanguage: settings.defaultSourceLanguage,
                        targetLanguage: settings.defaultTargetLanguage,
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

            // Show download prompt if models are missing
            if (translationService.needsModelDownload) {
              return _buildModelDownloadPrompt(context, ref, translationService);
            }

            // Show normal translation popup with tap-outside-to-dismiss
            return Stack(
              children: [
                // Full-screen transparent overlay for dismissal
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => translationService.clearSelection(),
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Actual popup positioned normally
                CyclingTranslationPopup(
                  key: ValueKey('translation_${translationService.selectedText}'),
                  selectedText: translationService.selectedText!,
                  sourceLanguage: ref.read(settingsProvider).defaultSourceLanguage,
                  targetLanguage: ref.read(settingsProvider).defaultTargetLanguage, // This will become homeLanguage
                  position: translationService.selectionPosition,
                  onClose: () => translationService.clearSelection(),
                  translationService: ref.read(translationServiceProvider),
                  context: translationService.selectedContext,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}