// Book Reader Widget
// Main reading interface that handles both PDF and EPUB

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/engines/pdf_reader_engine.dart';
import 'package:polyread/features/reader/engines/epub_reader_engine.dart';
import 'package:polyread/features/reader/engines/html_reader_engine.dart';
import 'package:polyread/features/reader/engines/txt_reader_engine.dart';
import 'package:polyread/features/reader/models/text_selection_type.dart';
import 'package:polyread/features/reader/services/reading_progress_service.dart';
import 'package:polyread/features/reader/widgets/table_of_contents_dialog.dart';
import 'package:polyread/features/reader/widgets/reader_settings_dialog.dart';
import 'package:polyread/features/reader/models/reader_settings.dart';
import 'package:polyread/features/reader/services/reader_settings_service.dart';
import 'package:polyread/features/reader/services/auto_scroll_service.dart';
import 'package:polyread/features/translation/widgets/cycling_translation_popup.dart';
import 'package:polyread/features/reader/providers/reader_translation_provider.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/providers/database_provider.dart';
import 'package:polyread/core/providers/settings_provider.dart';
import 'package:polyread/core/providers/immersive_mode_provider.dart';
import 'package:polyread/core/utils/constants.dart';
import '../config/reader_config.dart';

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
  ReaderSettingsService? _settingsService;
  AutoScrollService? _autoScrollService;
  Timer? _progressTimer;
  DateTime? _sessionStartTime;
  bool _isLoading = true;
  String? _error;
  
  // Reading session tracking
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
  
  // Immersive reading mode timer (state managed by provider)
  Timer? _immersiveModeTimer;
  
  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _initializeReader();
  }
  
  @override
  void dispose() {
    _progressTimer?.cancel();
    _immersiveModeTimer?.cancel();
    
    // Reset immersive mode when leaving reader
    ref.read(immersiveModeProvider.notifier).setImmersiveMode(false);
    
    // Restore normal status bar when leaving reader
    _updateStatusBarForImmersiveMode(false);
    
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
      
      // Initialize settings service
      _settingsService = ReaderSettingsService();
      await _settingsService!.initialize();
      _readerSettings = _settingsService!.currentSettings;
      
      // Get language settings
      final appSettings = ref.read(settingsProvider);
      _homeLanguage = appSettings.defaultTargetLanguage;
      _sourceLanguage = appSettings.defaultSourceLanguage == 'auto' ? 'en' : appSettings.defaultSourceLanguage;
      
      print('BookReader: Language settings - Source: $_sourceLanguage, Home: $_homeLanguage');
      
      // DICTIONARY FIX: Our dictionary is es-en (Spanish→English)
      // If user is reading English and wants Spanish translations, we need to use reverse lookup
      // The dictionary expects Spanish source words, so for English books we swap the parameters
      if (_sourceLanguage == 'en' && _homeLanguage == 'es') {
        print('BookReader: NOTICE - Reading English book with Spanish-English dictionary');
        print('BookReader: Will use reverse lookup (English words → Spanish translations)');
      } else if (_homeLanguage != 'en') {
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
      
      // Start auto-enter immersive mode timer
      _startAutoEnterImmersiveTimer();
      
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
      wordsRead: 0, // TODO: Implement word counting
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
      if (!RegExp(ReaderConfig.validTextPattern).hasMatch(trimmedText)) {
        print('BookReader: Text contains no letters, ignoring tap: "$trimmedText"');
        return;
      }
      
      // Check if text is too long (likely accidental selection)
      if (trimmedText.length > ReaderConfig.maxTranslationTextLength) {
        print('BookReader: Text too long, likely accidental selection: ${trimmedText.length} chars');
        return;
      }
      
      if (_translationService == null) {
        print('BookReader: Translation service is null!');
        return;
      }
      
      print('BookReader: Translation service available, processing...');
      
      // Extract context around the selected text
      print('BookReader: 🔍 Extracting context for word: "$trimmedText"');
      final context = _extractContext(text, selection);
      print('BookReader: 📝 Context extracted: "$context"');
      print('BookReader: 📏 Context length: ${context?.length ?? 0} characters');
      
      setState(() {
        _selectedText = trimmedText; // Use trimmed text
        _tapPosition = position;
        _selectedContext = context;
        _selectedTextSelection = selection;
        _showTranslationPopup = true;
      });
      
      print('BookReader: 🎯 About to show translation popup');
      print('BookReader: Selected text: "$trimmedText"');
      print('BookReader: Context being passed: "$context"');
      
      print('BookReader: Translation popup shown, starting translation...');
      
      // Note: Translation will be performed by the CyclingTranslationPopup widget
      // No need to call translation service here as it would duplicate the call
      
      _sessionTranslations++;
    }

    // Handle text selection with pre-extracted context (for EPUB WebView)
    void handleTextSelectionWithContext(String text, Offset position, TextSelection selection, String? context) async {
      print('BookReader: handleTextSelectionWithContext called with "$text" and context: "$context"');
      
      // Validate that we have actual meaningful text
      final trimmedText = text.trim();
      if (trimmedText.isEmpty || trimmedText.length < 1) {
        print('BookReader: No meaningful text selected, ignoring tap');
        return;
      }
      
      // Check if text contains only whitespace or special characters
      if (!RegExp(ReaderConfig.validTextPattern).hasMatch(trimmedText)) {
        print('BookReader: Text contains no letters, ignoring tap: "$trimmedText"');
        return;
      }
      
      // Check if text is too long (likely accidental selection)
      if (trimmedText.length > ReaderConfig.maxTranslationTextLength) {
        print('BookReader: Text too long, likely accidental selection: ${trimmedText.length} chars');
        return;
      }
      
      if (_translationService == null) {
        print('BookReader: Translation service is null!');
        return;
      }
      
      print('BookReader: Translation service available, processing...');
      print('BookReader: 🎯 Using pre-extracted context: "$context"');
      
      setState(() {
        _selectedText = trimmedText; // Use trimmed text
        _tapPosition = position;
        _selectedContext = context; // Use the pre-extracted context
        _selectedTextSelection = selection;
        _showTranslationPopup = true;
      });
      
      print('BookReader: 🎯 Translation popup shown with context: "$context"');
      
      _sessionTranslations++;
    }
    
    // Set up the sentence selection handler for translation
    void handleSentenceSelection(TextSelectionData selectionData) async {
      print('BookReader: handleSentenceSelection called with sentence: "${selectionData.text}"');
      
      // Validate sentence content
      final trimmedText = selectionData.text.trim();
      if (trimmedText.isEmpty || trimmedText.length < 3) {
        print('BookReader: Sentence too short, ignoring selection');
        return;
      }
      
      // Check if sentence is too long (likely accidental selection)
      if (trimmedText.length > 1000) {
        print('BookReader: Sentence too long, likely accidental selection: ${trimmedText.length} chars');
        return;
      }
      
      if (_translationService == null) {
        print('BookReader: Translation service is null!');
        return;
      }
      
      print('BookReader: Processing sentence translation...');
      
      // For sentence translation, extract enhanced context
      final enhancedContext = _extractSentenceContext(trimmedText);
      
      setState(() {
        _selectedText = trimmedText;
        _tapPosition = selectionData.position;
        _selectedContext = enhancedContext; // Use enhanced context with surrounding sentences
        _selectedTextSelection = TextSelection(baseOffset: 0, extentOffset: trimmedText.length);
        _showTranslationPopup = true;
      });
      
      print('BookReader: Sentence translation popup shown');
      
      _sessionTranslations++;
    }
    
    // Connect handler to specific engine types
    if (_readerEngine is HtmlReaderEngine) {
      (_readerEngine as HtmlReaderEngine).setTextSelectionHandler(handleTextSelection);
    } else if (_readerEngine is TxtReaderEngine) {
      (_readerEngine as TxtReaderEngine).setTextSelectionHandler(handleTextSelection);
    } else if (_readerEngine is EpubReaderEngine) {
      // Set up callback for EPUB engine to handle word vs sentence selection
      print('BookReader: Setting EPUB text selection callback');
      (_readerEngine as EpubReaderEngine).setTextSelectionCallback((selectionData) {
        print('BookReader: EPUB callback triggered with ${selectionData.type.name}: "${selectionData.text}"');
        print('BookReader: EPUB context from WebView: "${selectionData.context}"');
        
        // Route to appropriate handler based on selection type
        if (selectionData.isSentence) {
          handleSentenceSelection(selectionData);
        } else {
          // Handle as word selection, but use the context from WebView JavaScript
          handleTextSelectionWithContext(selectionData.text, selectionData.position, 
            TextSelection(baseOffset: 0, extentOffset: selectionData.text.length), selectionData.context);
        }
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
  
  
  String? _extractContext(String word, TextSelection selection) {
    print('BookReader: 🔍 _extractContext() called');
    print('BookReader: Word: "$word"');
    print('BookReader: Selection: baseOffset=${selection.baseOffset}, extentOffset=${selection.extentOffset}');
    print('BookReader: Reader engine type: ${_readerEngine.runtimeType}');
    print('BookReader: Context words count: ${ReaderConfig.contextWordsCount}');
    
    // Use the reader engine to extract context around the word
    if (_readerEngine == null) {
      print('BookReader: ❌ Reader engine is null');
      return null;
    }
    
    try {
      print('BookReader: 📞 Calling reader engine extractContextAroundWord...');
      final context = _readerEngine!.extractContextAroundWord(word, contextWords: ReaderConfig.contextWordsCount);
      print('BookReader: 📄 Engine returned context: "$context"');
      print('BookReader: 📏 Engine context length: ${context?.length ?? 0} characters');
      return context;
    } catch (e) {
      print('BookReader: ❌ Failed to extract context: $e');
      return null;
    }
  }
  
  String? _extractSentenceContext(String sentence) {
    // For sentence translations, extract surrounding sentences for better context
    if (_readerEngine == null) return sentence;
    
    try {
      // Get the full chapter or section content for context extraction
      String? fullContent;
      
      if (_readerEngine is EpubReaderEngine) {
        final epubEngine = _readerEngine as EpubReaderEngine;
        final chapters = epubEngine.chapters;
        if (chapters != null && chapters.isNotEmpty) {
          // Get current chapter content
          final currentChapter = chapters[epubEngine.currentChapterIndex];
          fullContent = currentChapter.HtmlContent;
        }
      } else {
        // For other engines, use the existing context extraction
        fullContent = _readerEngine!.extractContextAroundWord(sentence, contextWords: 50);
      }
      
      if (fullContent == null) return sentence;
      
      // Clean HTML tags and normalize text
      final cleanText = fullContent
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      // Find the sentence in the clean text
      final sentenceIndex = cleanText.toLowerCase().indexOf(sentence.toLowerCase());
      if (sentenceIndex == -1) return sentence;
      
      // Extract surrounding sentences (approximately 2 sentences before and after)
      return _extractSurroundingSentences(cleanText, sentenceIndex, sentence.length);
      
    } catch (e) {
      print('BookReader: Failed to extract sentence context: $e');
      return sentence;
    }
  }
  
  String _extractSurroundingSentences(String text, int targetIndex, int targetLength) {
    // Define sentence boundary patterns (multilingual)
    final sentenceBoundaries = RegExp(r'[.!?।。？！]+[\s]*');
    
    // Find sentences before the target
    final textBefore = text.substring(0, targetIndex);
    final beforeMatches = sentenceBoundaries.allMatches(textBefore).toList();
    
    // Start from 2 sentences before if available
    int contextStart = 0;
    if (beforeMatches.length >= 2) {
      contextStart = beforeMatches[beforeMatches.length - 2].end;
    } else if (beforeMatches.isNotEmpty) {
      contextStart = beforeMatches.last.end;
    }
    
    // Find sentences after the target
    final textAfter = text.substring(targetIndex + targetLength);
    final afterMatches = sentenceBoundaries.allMatches(textAfter).toList();
    
    // End after 2 sentences if available
    int contextEnd = text.length;
    if (afterMatches.length >= 2) {
      contextEnd = targetIndex + targetLength + afterMatches[1].end;
    } else if (afterMatches.isNotEmpty) {
      contextEnd = targetIndex + targetLength + afterMatches.first.end;
    }
    
    // Extract the context and clean it up
    final context = text.substring(contextStart, contextEnd).trim();
    
    // Ensure context doesn't exceed reasonable length
    if (context.length > 1500) {
      // Truncate to reasonable size while preserving sentence boundaries
      final truncated = context.substring(0, 1500);
      final lastSentence = sentenceBoundaries.allMatches(truncated).lastOrNull;
      if (lastSentence != null) {
        return truncated.substring(0, lastSentence.end).trim();
      }
    }
    
    return context;
  }
  
  void _closeTranslationPopup() {
    setState(() {
      _showTranslationPopup = false;
      _selectedText = null;
      _selectedContext = null;
      _selectedTextSelection = null;
    });
  }

  void _toggleImmersiveMode() {
    final immersiveModeNotifier = ref.read(immersiveModeProvider.notifier);
    immersiveModeNotifier.toggle();
    
    final isImmersive = ref.read(immersiveModeProvider);
    
    // Update status bar color to match page background
    _updateStatusBarForImmersiveMode(isImmersive);
    
    // Auto-enter immersive mode after inactivity when not immersive
    if (isImmersive) {
      _immersiveModeTimer?.cancel(); // Cancel auto-enter timer when in immersive mode
    } else {
      _startAutoEnterImmersiveTimer(); // Start timer to auto-enter immersive mode
    }
  }

  void _startAutoEnterImmersiveTimer() {
    _immersiveModeTimer?.cancel();
    _immersiveModeTimer = Timer(ReaderConfig.immersiveModeAutoTimeout, () {
      if (mounted) {
        final immersiveModeNotifier = ref.read(immersiveModeProvider.notifier);
        immersiveModeNotifier.setImmersiveMode(true);
        // Update status bar when auto-entering immersive mode
        _updateStatusBarForImmersiveMode(true);
      }
    });
  }

  void _updateStatusBarForImmersiveMode(bool isImmersive) {
    print('🎨 STATUS BAR: Updating for immersive mode: $isImmersive');
    
    if (isImmersive) {
      // Get unified theme colors for status bar
      final themeData = _readerSettings.getThemeData(context);
      final backgroundColor = themeData.colorScheme.background;
      final isLightBackground = backgroundColor.computeLuminance() > 0.5;
      
      print('🎨 IMMERSIVE: Reader theme: ${_readerSettings.theme}');
      print('🎨 IMMERSIVE: Background color: ${backgroundColor.toString()} (${backgroundColor.value.toRadixString(16)})');
      print('🎨 IMMERSIVE: Luminance: ${backgroundColor.computeLuminance()}');
      print('🎨 IMMERSIVE: Is light background: $isLightBackground');
      
      // Set immersive system UI mode
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [SystemUiOverlay.top], // Keep status bar visible but styled
      );
      
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: backgroundColor, // Try setting the actual color instead of transparent
          statusBarBrightness: isLightBackground ? Brightness.light : Brightness.dark,
          statusBarIconBrightness: isLightBackground ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness: isLightBackground ? Brightness.dark : Brightness.light,
          systemNavigationBarDividerColor: backgroundColor,
        ),
      );
      
      print('🎨 IMMERSIVE: Applied SystemUIMode.immersiveSticky with background color');
    } else {
      // Restore normal system UI mode
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      
      // Restore app-wide theme colors for status bar
      final appTheme = Theme.of(context);
      final backgroundColor = appTheme.colorScheme.surface;
      final isLightBackground = backgroundColor.computeLuminance() > 0.5;
      
      print('🎨 NORMAL: App theme background: ${backgroundColor.toString()} (${backgroundColor.value.toRadixString(16)})');
      print('🎨 NORMAL: Luminance: ${backgroundColor.computeLuminance()}');
      print('🎨 NORMAL: Is light background: $isLightBackground');
      
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, // Keep transparent for normal mode
          statusBarBrightness: isLightBackground ? Brightness.light : Brightness.dark,
          statusBarIconBrightness: isLightBackground ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness: isLightBackground ? Brightness.dark : Brightness.light,
          systemNavigationBarDividerColor: backgroundColor,
        ),
      );
      
      print('🎨 NORMAL: Restored SystemUIMode.edgeToEdge');
    }
  }
  
  void _addToVocabulary(String word) {
    // TODO: Implement vocabulary service integration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$word" to vocabulary')),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    final isImmersive = ref.watch(immersiveModeProvider);
    
    // Debug: Check if we're in the correct route context
    print('BookReader: Building in immersive mode: $isImmersive');
    
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
    
    final readerThemeData = _readerSettings.getThemeData(context);
    
    // NEW: single source of truth for the page bg used by the WebView/CSS
    final pageBg = _readerSettings.getPageBackgroundColor(context);
    
    // In immersive, paint Scaffold with the **page** color (not theme color).
    final scaffoldColor = isImmersive ? pageBg : null;
    
    // This was previously readerThemeData.colorScheme.background (cream)
    final statusBarFillColor = isImmersive ? pageBg : readerThemeData.colorScheme.background;
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    
    print('🎨 BUILD: Immersive mode: $isImmersive');
    print('🎨 BUILD: Reader theme: ${_readerSettings.theme}');
    print('🎨 PAGE BG: ${pageBg.toString()} (${pageBg.value.toRadixString(16)})');
    print('🎨 BUILD: Scaffold color: ${scaffoldColor?.toString()} (${scaffoldColor?.value.toRadixString(16)})');
    print('🎨 BUILD: Status bar fill color: ${statusBarFillColor.toString()} (${statusBarFillColor.value.toRadixString(16)})');
    print('🎨 BUILD: Status bar height: $statusBarHeight');
    
    return Theme(
      data: readerThemeData,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (pageBg.computeLuminance() > 0.5)
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: scaffoldColor, // <- now white in immersive
          extendBodyBehindAppBar: true,   // ensures bg shows behind island
          appBar: isImmersive ? null : _buildAppBar(),
          body: isImmersive
              ? Column(
                  children: [
                    // Top filler exactly the same white as the page - tappable to exit immersive mode
                    GestureDetector(
                      onTap: () {
                        print('🎯 STATUS BAR TAP: Exiting immersive mode');
                        final immersiveModeNotifier = ref.read(immersiveModeProvider.notifier);
                        immersiveModeNotifier.setImmersiveMode(false);
                        _updateStatusBarForImmersiveMode(false);
                        _startAutoEnterImmersiveTimer(); // Restart auto-enter timer
                      },
                      onTapDown: (_) {
                        // Provide subtle visual feedback on tap
                        HapticFeedback.lightImpact();
                      },
                      behavior: HitTestBehavior.opaque, // Ensure taps are captured across the entire area
                      child: Container(
                        height: statusBarHeight,
                        color: statusBarFillColor,
                        width: double.infinity, // Ensure full width coverage
                        // Add a subtle hint that this area is interactive
                        child: statusBarHeight > 0 ? Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: statusBarFillColor.computeLuminance() > 0.5 
                                    ? Colors.black.withOpacity(0.05)
                                    : Colors.white.withOpacity(0.05),
                                width: 0.5,
                              ),
                            ),
                          ),
                        ) : null,
                      ),
                    ),
                    Expanded(child: _buildReaderBody(pageBg: pageBg)),
                  ],
                )
              : SafeArea(
                  top: true, // Respect the app bar in non-immersive mode
                  child: _buildReaderBody(pageBg: null),
                ),
        ),
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
  
  
  Widget _buildReaderBody({Color? pageBg}) {
    if (_readerEngine == null) {
      return const Center(child: Text(ReaderConfig.readerNotInitialized));
    }
    
    // Wrap entire reader body with double-tap gesture for immersive mode
    return GestureDetector(
      onDoubleTap: _toggleImmersiveMode,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Main reader content with optional background color
          Container(
            color: pageBg, // fallback behind WebView
            child: _buildReaderContent(),
          ),
        
          // Reading progress indicator (hidden in immersive mode)  
          if (!ref.watch(immersiveModeProvider))
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: ReaderConfig.progressIndicatorHeight,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: ReaderConfig.progressIndicatorOpacity),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _readerEngine!.progress,
                  child: Container(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: ReaderConfig.progressBarOpacity),
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
      ),
    );
  }

  Widget _buildReaderContent() {
    return _readerEngine!.buildReader(context);
  }

  String _toCssColor(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  
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
    
    // Update status bar to match new theme
    final isImmersive = ref.read(immersiveModeProvider);
    _updateStatusBarForImmersiveMode(isImmersive);
    
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