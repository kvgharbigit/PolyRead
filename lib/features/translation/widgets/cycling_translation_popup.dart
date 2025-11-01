// Enhanced Cycling Translation Popup
// Reading-optimized translation overlay with PolyRead design integration
// Minimal working version for compilation

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meaning_entry.dart';
import '../services/cycling_dictionary_service.dart';
import '../services/dictionary_link_service.dart';
import '../../reader/providers/reader_translation_provider.dart';
import '../../../core/themes/polyread_spacing.dart';
import '../../../core/themes/polyread_typography.dart';
import '../../../core/themes/polyread_theme.dart';
import '../../../core/utils/constants.dart';
import '../../../core/providers/settings_provider.dart';
import 'translation_requirements_dialog.dart';
import '../models/translation_response.dart';
import '../config/part_of_speech_emojis.dart';

/// Content metrics for intelligent popup sizing
class _ContentMetrics {
  final double estimatedMinHeight;
  final int estimatedLines;
  final bool hasLongContent;
  
  const _ContentMetrics({
    required this.estimatedMinHeight,
    required this.estimatedLines,
    required this.hasLongContent,
  });
}

/// Word prioritization result with scoring details
class _WordPrioritizationResult {
  final double fuzzySimilarity;
  final double positionScore;
  final double finalScore;
  final String bestMatch;
  final int expectedPosition;
  final int actualPosition;
  
  const _WordPrioritizationResult({
    required this.fuzzySimilarity,
    required this.positionScore,
    required this.finalScore,
    required this.bestMatch,
    required this.expectedPosition,
    required this.actualPosition,
  });
}

class CyclingTranslationPopup extends ConsumerStatefulWidget {
  final String selectedText;
  final String sourceLanguage;
  final String targetLanguage;
  final Offset? position;
  final VoidCallback? onClose;
  final String? context;
  final dynamic translationService;

  const CyclingTranslationPopup({
    super.key,
    required this.selectedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.position,
    this.onClose,
    this.context,
    this.translationService,
  });

  @override
  ConsumerState<CyclingTranslationPopup> createState() => _CyclingTranslationPopupState();
}

class _CyclingTranslationPopupState extends ConsumerState<CyclingTranslationPopup>
    with TickerProviderStateMixin {
  CyclingDictionaryService? _dictionaryService;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // State
  bool _isLoading = true;
  String? _error;
  MeaningLookupResult? _sourceLookupResult;
  ReverseLookupResult? _reverseLookupResult;
  int _currentMeaningIndex = 0;
  int _currentReverseIndex = 0;
  bool _isReverseLookup = false;
  String? _mlKitFallbackResult; // Store ML Kit fallback translation
  String? _sentenceTranslation; // Store ML Kit sentence translation
  bool _isSentenceLoading = false; // Loading state for sentence translation
  String? _currentBestMatch; // Store the best matching word from sentence for current translation
  
  // Performance optimization: Cache calculated constraints
  BoxConstraints? _cachedConstraints;
  Size? _lastScreenSize;
  
  // Performance optimization: Cache normalized words and sentence splits
  List<String>? _cachedSentenceWords;
  final Map<String, String> _normalizedWordCache = {};
  final Map<String, _WordPrioritizationResult> _scoringCache = {};
  
  @override
  void initState() {
    super.initState();
    
    print('CyclingPopup: 🚀 initState() called');
    print('CyclingPopup: Selected text: "${widget.selectedText}"');
    print('CyclingPopup: Source language: ${widget.sourceLanguage}');
    print('CyclingPopup: Target language: ${widget.targetLanguage}');
    print('CyclingPopup: Context received: "${widget.context}"');
    print('CyclingPopup: Context length: ${widget.context?.length ?? 0} characters');
    print('CyclingPopup: Translation service available: ${widget.translationService != null}');
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _showPopup();
    _performLookup();
    _performSentenceTranslation();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }
  
  void _showPopup() {
    _fadeController.forward();
    _scaleController.forward();
  }
  
  Future<void> _performLookup() async {
    print('CyclingPopup: Starting lookup for "${widget.selectedText}"');
    print('CyclingPopup: Source language: ${widget.sourceLanguage}');
    print('CyclingPopup: Target language: ${widget.targetLanguage}');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Step 1: Check what translation components are available
    await _checkTranslationComponents();
  }

  
  /// Handle tap for cycling through meanings
  void _handleTap() {
    // Cycle through meanings if available
    if (_isReverseLookup && _reverseLookupResult != null) {
      if (_currentReverseIndex < _reverseLookupResult!.translations.length - 1) {
        setState(() {
          _currentReverseIndex++;
          _updateCurrentBestMatch();
        });
      } else {
        setState(() {
          _currentReverseIndex = 0; // Loop back to first
          _updateCurrentBestMatch();
        });
      }
    } else if (_sourceLookupResult != null) {
      if (_currentMeaningIndex < _sourceLookupResult!.meanings.length - 1) {
        setState(() {
          _currentMeaningIndex++;
          _updateCurrentBestMatch();
        });
      } else {
        setState(() {
          _currentMeaningIndex = 0; // Loop back to first
          _updateCurrentBestMatch();
        });
      }
    }
  }

  /// Check availability of translation components and show prompts if missing
  Future<void> _checkTranslationComponents() async {
    bool dictionaryAvailable = false;
    bool mlKitAvailable = false;
    
    // Check dictionary availability by checking language pairs
    try {
      _dictionaryService ??= ref.read(cyclingDictionaryServiceProvider);
      
      // Use the public method to check available language pairs
      final strategy = await _dictionaryService!.getDictionaryStrategy(
        widget.sourceLanguage,
        widget.targetLanguage,
      );
      
      // If we get here without exception, dictionary is available
      dictionaryAvailable = true;
      print('CyclingPopup: Dictionary available for ${widget.sourceLanguage}-${widget.targetLanguage}');
    } catch (e) {
      print('CyclingPopup: Dictionary NOT available for ${widget.sourceLanguage}-${widget.targetLanguage}: $e');
      dictionaryAvailable = false;
    }
    
    // Check ML Kit availability
    if (widget.translationService != null) {
      try {
        // Access the underlying translation service which has mlKitProvider
        final mlKitProvider = widget.translationService.translationService.mlKitProvider;
        mlKitAvailable = await mlKitProvider.areModelsDownloaded(
          sourceLanguage: widget.sourceLanguage,
          targetLanguage: widget.targetLanguage,
        );
        print('CyclingPopup: ML Kit models available: $mlKitAvailable');
      } catch (e) {
        print('CyclingPopup: ML Kit check failed: $e');
        mlKitAvailable = false;
      }
    }
    
    // Determine what to show based on availability
    if (!dictionaryAvailable && !mlKitAvailable) {
      // Both missing
      _handleMissingComponents(MissingComponent.both);
    } else if (!dictionaryAvailable) {
      // Only dictionary missing
      _handleMissingComponents(MissingComponent.dictionary);
    } else if (!mlKitAvailable) {
      // Only ML Kit missing
      _handleMissingComponents(MissingComponent.mlKitModel);
    } else {
      // Both available, proceed with translation
      await _performActualLookup();
    }
  }

  /// Perform the actual translation lookup when components are available
  Future<void> _performActualLookup() async {
    try {
      print('CyclingPopup: Attempting source lookup for "${widget.selectedText}" (${widget.sourceLanguage} -> ${widget.targetLanguage})...');
      
      // Get ML Kit single word translation upfront to include in prioritization
      final mlKitSingleWord = await _getMlKitSingleWordTranslation();
      
      // Simple lookup - try source meanings first
      final sourceResult = await _dictionaryService!.lookupSourceMeanings(
        widget.selectedText,
        widget.sourceLanguage,
        widget.targetLanguage,
      );

      print('CyclingPopup: Source lookup result - hasResults: ${sourceResult.hasResults}');
      if (sourceResult.hasResults) {
        print('CyclingPopup: Source lookup found ${sourceResult.meanings.length} meanings');
        
        // Apply smart prioritization including ML Kit candidate
        final prioritizedResult = await _applySmartPrioritizationWithMlKit(sourceResult, false, mlKitSingleWord);
        
        setState(() {
          _sourceLookupResult = prioritizedResult;
          _isReverseLookup = false;
          _isLoading = false;
          // Only update best match if we're not using ML Kit fallback
          if (_mlKitFallbackResult == null) {
            _updateCurrentBestMatch();
          }
        });
        return;
      }

      print('CyclingPopup: Attempting reverse lookup for "${widget.selectedText}" (${widget.targetLanguage} -> ${widget.sourceLanguage})...');
      
      // Try reverse lookup
      final reverseResult = await _dictionaryService!.lookupTargetTranslations(
        widget.selectedText,
        widget.sourceLanguage,
        widget.targetLanguage,
      );

      print('CyclingPopup: Reverse lookup result - hasResults: ${reverseResult.hasResults}');
      if (reverseResult.hasResults) {
        print('CyclingPopup: Reverse lookup found ${reverseResult.translations.length} translations');
        
        // Apply smart prioritization including ML Kit candidate
        final prioritizedResult = await _applySmartPrioritizationWithMlKit(reverseResult, true, mlKitSingleWord);
        
        setState(() {
          _reverseLookupResult = prioritizedResult;
          _isReverseLookup = true;
          _isLoading = false;
          // Only update best match if we're not using ML Kit fallback
          if (_mlKitFallbackResult == null) {
            _updateCurrentBestMatch();
          }
        });
        return;
      }

      // No results found in dictionary, try ML Kit as fallback
      print('CyclingPopup: No results found in either direction for "${widget.selectedText}"');
      if (mlKitSingleWord != null && mlKitSingleWord.isNotEmpty) {
        print('CyclingPopup: Using ML Kit single word as sole result');
        // Update best match for highlighting ML Kit result
        _updateCurrentBestMatchForMlKit(mlKitSingleWord);
        setState(() {
          _mlKitFallbackResult = mlKitSingleWord;
          _isLoading = false;
        });
      } else {
        await _tryMlKitFallback();
      }
      
    } catch (e) {
      print('CyclingPopup: Lookup error: $e');
      setState(() {
        _error = 'Lookup error: $e';
        _isLoading = false;
      });
    }
  }

  /// Perform sentence translation using ML Kit
  Future<void> _performSentenceTranslation() async {
    print('CyclingPopup: ==> _performSentenceTranslation() called');
    print('CyclingPopup: Selected word: "${widget.selectedText}"');
    print('CyclingPopup: Context received: "${widget.context}"');
    print('CyclingPopup: Context length: ${widget.context?.length ?? 0} characters');
    print('CyclingPopup: Source language: ${widget.sourceLanguage}');
    print('CyclingPopup: Target language: ${widget.targetLanguage}');
    
    // Show more details about the context
    if (widget.context != null && widget.context!.length > 100) {
      print('CyclingPopup: 📏 Long context detected (${widget.context!.length} chars)');
      print('CyclingPopup: 📄 First 100 chars: "${widget.context!.substring(0, 100)}..."');
      print('CyclingPopup: 📄 Last 100 chars: "...${widget.context!.substring(widget.context!.length - 100)}"');
    }
    
    // Only translate sentence if we have context (the sentence)
    if (widget.context == null || widget.context!.trim().isEmpty) {
      print('CyclingPopup: ❌ No context available for sentence translation');
      print('CyclingPopup: Context is null: ${widget.context == null}');
      if (widget.context != null) {
        print('CyclingPopup: Context length: ${widget.context!.length}');
        print('CyclingPopup: Context trimmed length: ${widget.context!.trim().length}');
      }
      return;
    }
    
    // Only translate if we have a translation service
    if (widget.translationService == null) {
      print('CyclingPopup: ❌ No translation service available for sentence translation');
      return;
    }
    
    print('CyclingPopup: ✅ Starting sentence translation...');
    print('CyclingPopup: Context to translate: "${widget.context}"');
    print('CyclingPopup: Context length: ${widget.context!.length} characters');
    
    setState(() {
      _isSentenceLoading = true;
    });
    
    try {
      print('CyclingPopup: 📡 Calling translation service...');
      
      final translationResponse = await widget.translationService.translateText(
        text: widget.context!,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        useCache: true,
      );
      
      print('CyclingPopup: 📨 Translation response received');
      print('CyclingPopup: Translated text: "${translationResponse.translatedText}"');
      print('CyclingPopup: Translation source: ${translationResponse.source}');
      
      if (translationResponse.translatedText.isNotEmpty) {
        setState(() {
          _sentenceTranslation = translationResponse.translatedText;
          _isSentenceLoading = false;
          _invalidateConstraintsCache(); // Content changed, invalidate cache
          _invalidatePerformanceCache(); // New sentence translation, clear caches
        });
        print('CyclingPopup: ✅ Sentence translation completed successfully');
        print('CyclingPopup: Final sentence translation: "${_sentenceTranslation}"');
      } else {
        setState(() {
          _isSentenceLoading = false;
          _invalidateConstraintsCache(); // Content changed, invalidate cache
        });
        print('CyclingPopup: ❌ Sentence translation returned empty result');
      }
    } catch (e) {
      print('CyclingPopup: ❌ Sentence translation error: $e');
      setState(() {
        _isSentenceLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget wordContent;
    
    if (_isLoading) {
      wordContent = _buildLoadingView();
    } else if (_error != null) {
      wordContent = _buildErrorView();
    } else if (_mlKitFallbackResult != null) {
      wordContent = _buildMlKitFallbackView();
    } else if (_isReverseLookup && _reverseLookupResult != null) {
      wordContent = _buildReverseLookupView();
    } else if (_sourceLookupResult != null) {
      wordContent = _buildSourceMeaningView();
    } else {
      wordContent = _buildErrorView();
    }

    // Combine word content with sentence translation
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Word translation (existing content)
        wordContent,
        
        // Sentence translation (new content)
        if (_sentenceTranslation != null || _isSentenceLoading) ...[
          Padding(
            padding: const EdgeInsets.only(top: PolyReadSpacing.smallSpacing),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(PolyReadSpacing.elementSpacing), // More padding for readability
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08), // Slightly more subtle background
                borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
              ),
              child: _buildSentenceTranslationView(),
            ),
          ),
        ],
      ],
    );

    final position = _calculatePopupPosition();

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Positioned(
          left: position['left'],
          top: position['top'],
          child: Semantics(
            label: 'Translation popup for ${widget.selectedText}',
            explicitChildNodes: true,
            container: true,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
                  color: Colors.transparent,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: IntrinsicWidth(
                        child: ConstrainedBox(
                          constraints: _getPopupConstraints(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Translating...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '❌',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Translation failed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceMeaningView() {
    if (_sourceLookupResult == null || _sourceLookupResult!.meanings.isEmpty) {
      return _buildErrorView();
    }
    
    final cyclableMeaning = _sourceLookupResult!.meanings[_currentMeaningIndex];
    
    return Container(
      padding: const EdgeInsets.all(12),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main translation row: emoji + translation
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Part-of-speech emoji indicator
                Text(
                  PartOfSpeechEmojis.getEmojiForPOS(
                    cyclableMeaning.meaning.partOfSpeech, 
                    language: widget.sourceLanguage,
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                // Translation text with clickable original word
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        _createClickableOriginalWordSpan(),
                        TextSpan(
                          text: ' → ',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        _createClickableTranslatedWordSpan(cyclableMeaning.displayTranslation),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Cycling indicator (if multiple meanings)
            if (cyclableMeaning.totalMeanings > 1) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _handleTap,
                child: Text(
                  '${cyclableMeaning.currentIndex}/${cyclableMeaning.totalMeanings}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReverseLookupView() {
    if (_reverseLookupResult == null || _reverseLookupResult!.translations.isEmpty) {
      return _buildErrorView();
    }
    
    final cyclableReverse = _reverseLookupResult!.translations[_currentReverseIndex];
    
    return Container(
      padding: const EdgeInsets.all(12),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main translation row: emoji + translation
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Part-of-speech emoji indicator
                Text(
                  PartOfSpeechEmojis.getEmojiForPOS(
                    cyclableReverse.partOfSpeech, 
                    language: widget.targetLanguage,
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                // Translation text with clickable original word
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        _createClickableOriginalWordSpan(),
                        TextSpan(
                          text: ' → ',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        _createClickableTranslatedWordSpan(cyclableReverse.displayTranslation),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Cycling indicator (if multiple translations)
            if (cyclableReverse.totalTranslations > 1) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _handleTap,
                child: Text(
                  '${cyclableReverse.currentIndex}/${cyclableReverse.totalTranslations}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMlKitFallbackView() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ultra-minimal: question mark emoji + translation (indicating uncertainty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Uncertainty indicator for ML Kit translations
              const Text(
                '🤔',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              // Translation text with clickable original word
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      _createClickableOriginalWordSpan(),
                      TextSpan(
                        text: ' → ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      _createClickableTranslatedWordSpan(_mlKitFallbackResult!),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Calculate optimal popup constraints based on content and screen
  BoxConstraints _getPopupConstraints() {
    final screenSize = MediaQuery.of(context).size;
    
    // Performance optimization: Only recalculate if screen size changed or content changed
    if (_cachedConstraints != null && 
        _lastScreenSize == screenSize && 
        !_hasContentChanged()) {
      return _cachedConstraints!;
    }
    
    final screenPadding = MediaQuery.of(context).padding;
    
    // Available space considering safe areas and UI chrome
    final availableWidth = screenSize.width - screenPadding.horizontal - 32; // 16px margin each side
    final availableHeight = screenSize.height - screenPadding.vertical - 120; // Space for app bar, etc.
    
    // Content-aware sizing
    final contentMetrics = _analyzeContentRequirements();
    
    // Base constraints adapted to content
    final baseMinWidth = _getBaseMinWidth();
    final contentAdjustedMaxWidth = _getContentAwareMaxWidth(availableWidth, contentMetrics);
    
    final constraints = BoxConstraints(
      minWidth: baseMinWidth,
      maxWidth: contentAdjustedMaxWidth,
      minHeight: contentMetrics.estimatedMinHeight,
      maxHeight: (availableHeight * 0.7).clamp(120, double.infinity), // Max 70% of available height
    );
    
    // Cache the result
    _cachedConstraints = constraints;
    _lastScreenSize = screenSize;
    
    return constraints;
  }
  
  /// Check if content has changed since last calculation
  bool _hasContentChanged() {
    // This is a simple heuristic - in a more sophisticated implementation,
    // we could track specific content change flags
    return _isSentenceLoading || _isLoading;
  }
  
  /// Invalidate cached constraints when content changes
  void _invalidateConstraintsCache() {
    _cachedConstraints = null;
    _lastScreenSize = null;
  }
  
  /// Analyze content requirements for intelligent sizing
  _ContentMetrics _analyzeContentRequirements() {
    double estimatedMinHeight = 60; // Base height for word translation
    int estimatedLines = 1;
    
    // Factor in sentence translation content
    if (_sentenceTranslation != null) {
      final sentenceLength = _sentenceTranslation!.length;
      // Rough estimation: 50 chars per line at average width
      estimatedLines = ((sentenceLength / 45).ceil()).clamp(1, 8);
      estimatedMinHeight += estimatedLines * 22; // ~22px per line
    } else if (_isSentenceLoading) {
      estimatedMinHeight += 30; // Space for loading indicator
    }
    
    
    return _ContentMetrics(
      estimatedMinHeight: estimatedMinHeight,
      estimatedLines: estimatedLines,
      hasLongContent: estimatedLines > 3,
    );
  }
  
  /// Get content-aware maximum width
  double _getContentAwareMaxWidth(double availableWidth, _ContentMetrics metrics) {
    if (metrics.hasLongContent) {
      // Long content needs more width for better line breaks
      return (availableWidth * 0.88).clamp(300, double.infinity);
    } else if (_sentenceTranslation != null || _isSentenceLoading) {
      return (availableWidth * 0.82).clamp(280, double.infinity);
    } else {
      return (availableWidth * 0.6).clamp(200, 300); // Word-only
    }
  }
  
  /// Get base minimum width based on content type
  double _getBaseMinWidth() {
    if (_sentenceTranslation != null || _isSentenceLoading) {
      return 240; // Sentence translation minimum
    } else {
      return 180; // Word-only minimum
    }
  }
  
  /// Get base maximum width based on available space
  double _getBaseMaxWidth(double availableWidth) {
    if (_sentenceTranslation != null || _isSentenceLoading) {
      return (availableWidth * 0.85).clamp(280, double.infinity);
    } else {
      return (availableWidth * 0.6).clamp(200, 300); // Word-only doesn't need much width
    }
  }

  /// Build sentence translation view
  Widget _buildSentenceTranslationView() {
    if (_isSentenceLoading) {
      return Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Translating sentence...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    if (_sentenceTranslation == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Translated sentence with bolded matched words (no heading)
        _buildHighlightedSentenceTranslation(),
      ],
    );
  }

  /// Build sentence translation with the best matching word bolded
  Widget _buildHighlightedSentenceTranslation() {
    final sentenceText = _sentenceTranslation!;
    
    if (_currentBestMatch == null || _currentBestMatch!.isEmpty) {
      // No match found, show plain text using RichText for consistency
      return RichText(
        text: TextSpan(
          text: sentenceText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.4,
            fontSize: 14,
          ),
        ),
        softWrap: true,
      );
    }
    
    print('🎯 Highlighting stored best match: "$_currentBestMatch" in sentence: "$sentenceText"');
    
    // Split sentence into words and spaces separately to preserve formatting
    final pattern = RegExp(r'(\S+)'); // Match non-whitespace sequences
    final matches = pattern.allMatches(sentenceText);
    final spans = <TextSpan>[];
    
    int lastEnd = 0;
    bool hasHighlighted = false;
    final normalizedBestMatch = _getCachedNormalizedWord(_currentBestMatch!);
    
    for (final match in matches) {
      // Add any whitespace before this word
      if (match.start > lastEnd) {
        final whitespace = sentenceText.substring(lastEnd, match.start);
        spans.add(TextSpan(
          text: whitespace,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.4,
            fontSize: 14,
          ),
        ));
      }
      
      final word = match.group(0)!;
      final cleanWord = word.replaceAll(RegExp(r'''[.,!?;:'"]'''), '');
      final normalizedWord = _getCachedNormalizedWord(cleanWord);
      
      // Check if this word matches our stored best match (simple exact match after normalization)
      if (!hasHighlighted && normalizedWord == normalizedBestMatch) {
        
        print('🎯 Found word to highlight: "$word" matches stored best match "$_currentBestMatch"');
        
        // Highlight this word with multiple visual cues for maximum visibility
        spans.add(TextSpan(
          text: word,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary, // White/black text on colored background
            backgroundColor: Theme.of(context).colorScheme.primary, // Colored background
            height: 1.4,
            fontSize: 14,
            fontWeight: FontWeight.w700, // Extra bold
            decoration: TextDecoration.underline, // Underline for extra emphasis
            decorationColor: Theme.of(context).colorScheme.onPrimary,
            decorationThickness: 2.0, // Thick underline
            letterSpacing: 0.5, // Slight letter spacing for emphasis
          ),
        ));
        hasHighlighted = true;
      } else {
        // Regular word
        spans.add(TextSpan(
          text: word,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.4,
            fontSize: 14,
          ),
        ));
      }
      
      lastEnd = match.end;
    }
    
    // Add any remaining whitespace at the end
    if (lastEnd < sentenceText.length) {
      final remainingText = sentenceText.substring(lastEnd);
      spans.add(TextSpan(
        text: remainingText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.4,
          fontSize: 14,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
    );
  }


  /// Handle missing components by showing unified installation prompt
  Future<void> _handleMissingComponents(MissingComponent missingComponent) async {
    // Close the current popup first
    widget.onClose?.call();
    
    // Determine the language pack needed
    String languagePack = '${widget.sourceLanguage}-${widget.targetLanguage}';
    
    // Show the unified translation requirements dialog
    final shouldInstall = await showTranslationRequirementsDialog(
      context: context,
      sourceLanguage: widget.sourceLanguage,
      targetLanguage: widget.targetLanguage,
      missingComponent: missingComponent,
      specificLanguagePack: languagePack,
    );
    
    if (shouldInstall) {
      print('CyclingPopup: User chose to install components: $missingComponent');
    } else {
      print('CyclingPopup: User skipped installation');
    }
  }

  /// Handle missing dictionary by showing installation prompt
  Future<void> _handleMissingDictionary() async {
    await _handleMissingComponents(MissingComponent.dictionary);
  }

  /// Get ML Kit single word translation to include as a candidate
  Future<String?> _getMlKitSingleWordTranslation() async {
    try {
      print('CyclingPopup: Getting ML Kit single word translation for "${widget.selectedText}"...');
      
      final translationResponse = await widget.translationService.translateText(
        text: widget.selectedText,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        useCache: false,
      );
      
      // Check if ML Kit translation was successful
      if (translationResponse.source == TranslationSource.mlKit || 
          translationResponse.source == TranslationSource.server) {
        final mlKitTranslation = translationResponse.translatedText.trim();
        print('CyclingPopup: ML Kit single word translation: "${mlKitTranslation}"');
        return mlKitTranslation;
      }
      
      print('CyclingPopup: ML Kit single word translation failed or models not available');
      return null;
      
    } catch (e) {
      print('CyclingPopup: ML Kit single word translation error: $e');
      return null;
    }
  }

  /// Apply smart prioritization including ML Kit candidate
  Future<dynamic> _applySmartPrioritizationWithMlKit(dynamic lookupResult, bool isReverseLookup, String? mlKitCandidate) async {
    print('🧠 SmartPrioritization: Starting prioritization with ML Kit candidate: "$mlKitCandidate"');
    
    // Wait for sentence translation to complete if it's still loading
    if (_sentenceTranslation == null && _isSentenceLoading) {
      print('🧠 SmartPrioritization: Waiting for sentence translation to complete...');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // If we don't have sentence translation, use original prioritization
    if (_sentenceTranslation == null || _sentenceTranslation!.trim().isEmpty) {
      print('🧠 SmartPrioritization: No sentence translation available, using original order');
      return await _applySmartPrioritization(lookupResult, isReverseLookup);
    }
    
    // Calculate expected position of the word in the source sentence
    final expectedPosition = _calculateExpectedPosition();
    
    // Get ML Kit score if we have a candidate
    double mlKitScore = 0.0;
    if (mlKitCandidate != null && mlKitCandidate.isNotEmpty) {
      final mlKitResult = _calculateWordPriorityScore(mlKitCandidate, expectedPosition);
      mlKitScore = mlKitResult.finalScore;
      print('🧠 SmartPrioritization: ML Kit candidate "$mlKitCandidate" score: ${mlKitScore.toStringAsFixed(3)}');
    }
    
    // Prioritize dictionary results
    dynamic prioritizedResult;
    double bestDictScore = 0.0;
    String? bestDictMatch;
    
    if (isReverseLookup) {
      prioritizedResult = _prioritizeReverseResults(lookupResult as ReverseLookupResult, expectedPosition);
      if ((prioritizedResult as ReverseLookupResult).translations.isNotEmpty) {
        bestDictMatch = prioritizedResult.translations.first.sourceWord;
        bestDictScore = _calculateWordPriorityScore(bestDictMatch, expectedPosition).finalScore;
      }
    } else {
      prioritizedResult = _prioritizeSourceResults(lookupResult as MeaningLookupResult, expectedPosition);
      if ((prioritizedResult as MeaningLookupResult).meanings.isNotEmpty) {
        bestDictMatch = prioritizedResult.meanings.first.meaning.targetMeaning;
        bestDictScore = _calculateWordPriorityScore(bestDictMatch, expectedPosition).finalScore;
      }
    }
    
    print('🧠 SmartPrioritization: Best dictionary score: ${bestDictScore.toStringAsFixed(3)} ("$bestDictMatch")');
    
    // Log the complete comparison
    print('🧠 SmartPrioritization: === DECISION SUMMARY ===');
    print('🧠 SmartPrioritization: Word: "${widget.selectedText}"');
    print('🧠 SmartPrioritization: Context: "${widget.context}"');
    print('🧠 SmartPrioritization: Sentence translation: "${_sentenceTranslation}"');
    if (mlKitCandidate != null) {
      print('🧠 SmartPrioritization: ML Kit candidate: "$mlKitCandidate" (score: ${mlKitScore.toStringAsFixed(3)})');
    } else {
      print('🧠 SmartPrioritization: ML Kit candidate: None available');
    }
    print('🧠 SmartPrioritization: Best dictionary: "$bestDictMatch" (score: ${bestDictScore.toStringAsFixed(3)})');
    
    // Check if ML Kit wins and doesn't match a dictionary option
    if (mlKitCandidate != null && mlKitScore > bestDictScore) {
      // Check if ML Kit result matches any dictionary option (case-insensitive)
      bool matchesDictionary = false;
      if (isReverseLookup) {
        final reverseResult = prioritizedResult as ReverseLookupResult;
        matchesDictionary = reverseResult.translations.any((t) => 
          t.sourceWord.toLowerCase() == mlKitCandidate.toLowerCase());
      } else {
        final sourceResult = prioritizedResult as MeaningLookupResult;
        matchesDictionary = sourceResult.meanings.any((m) => 
          m.meaning.targetMeaning.toLowerCase() == mlKitCandidate.toLowerCase());
      }
      
      if (matchesDictionary) {
        print('🧠 SmartPrioritization: DECISION: ML Kit matches dictionary → Using DICTIONARY');
        print('🧠 SmartPrioritization: Reason: ML Kit "$mlKitCandidate" found in dictionary options');
        return prioritizedResult;
      } else {
        print('🧠 SmartPrioritization: DECISION: ML Kit wins contextually → Using ML KIT');
        print('🧠 SmartPrioritization: Reason: ML Kit score ${mlKitScore.toStringAsFixed(3)} > dictionary ${bestDictScore.toStringAsFixed(3)}, no dictionary match');
        // Update best match for highlighting ML Kit result before setting state
        _updateCurrentBestMatchForMlKit(mlKitCandidate);
        setState(() {
          _mlKitFallbackResult = mlKitCandidate;
        });
        return prioritizedResult; // Return dictionary results but display will show ML Kit
      }
    }
    
    print('🧠 SmartPrioritization: DECISION: Dictionary wins contextually → Using DICTIONARY');
    print('🧠 SmartPrioritization: Reason: Dictionary score ${bestDictScore.toStringAsFixed(3)} >= ML Kit ${mlKitScore.toStringAsFixed(3)}');
    return prioritizedResult;
  }

  /// Try ML Kit translation as fallback when dictionary lookup fails
  Future<void> _tryMlKitFallback() async {
    try {
      print('CyclingPopup: Trying ML Kit fallback translation...');
      
      final translationResponse = await widget.translationService.translateText(
        text: widget.selectedText,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        useCache: false, // Skip cache since we already tried dictionary
      );
      
      // Check if ML Kit models are not downloaded
      if (translationResponse.source == TranslationSource.modelsNotDownloaded) {
        print('CyclingPopup: ML Kit models not downloaded');
        _handleMissingMlKitModels();
        return;
      }
      
      // Check if translation was successful
      if (translationResponse.source == TranslationSource.mlKit || 
          translationResponse.source == TranslationSource.server) {
        print('CyclingPopup: ML Kit/Server fallback successful');
        // Update best match for highlighting ML Kit result
        _updateCurrentBestMatchForMlKit(translationResponse.translatedText);
        setState(() {
          _error = null;
          _isLoading = false;
          // Store the ML Kit result for display
          _mlKitFallbackResult = translationResponse.translatedText;
        });
        return;
      }
      
      // Translation failed completely
      setState(() {
        _error = 'No translation found for "${widget.selectedText}"';
        _isLoading = false;
      });
      
    } catch (e) {
      print('CyclingPopup: ML Kit fallback error: $e');
      setState(() {
        _error = 'Translation failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Handle missing ML Kit models by showing installation prompt
  Future<void> _handleMissingMlKitModels() async {
    await _handleMissingComponents(MissingComponent.mlKitModel);
  }

  Map<String, double> _calculatePopupPosition() {
    if (widget.position == null) {
      return {'left': 50.0, 'top': 100.0};
    }
    
    final screenSize = MediaQuery.of(context).size;
    final screenPadding = MediaQuery.of(context).padding;
    final constraints = _getPopupConstraints();
    
    // Estimate popup dimensions for positioning
    final estimatedWidth = (constraints.minWidth + constraints.maxWidth) / 2;
    final estimatedHeight = constraints.maxHeight * 0.4; // Conservative estimate
    
    // Calculate safe positioning bounds
    final safeLeft = screenPadding.left + 16;
    final safeRight = screenSize.width - screenPadding.right - estimatedWidth - 16;
    final safeTop = screenPadding.top + 60; // Below app bar
    final safeBottom = screenSize.height - screenPadding.bottom - estimatedHeight - 20;
    
    // Preferred position: centered horizontally, below tap point
    double x = widget.position!.dx - (estimatedWidth / 2);
    double y = widget.position!.dy + 40; // Offset below tap point
    
    // Smart positioning adjustments
    if (y > safeBottom) {
      // If popup would go below screen, position above tap point instead
      y = widget.position!.dy - estimatedHeight - 10;
    }
    
    // Ensure popup stays within safe bounds
    x = x.clamp(safeLeft, safeRight);
    y = y.clamp(safeTop, safeBottom);
    
    return {'left': x, 'top': y};
  }

  /// Apply smart prioritization to dictionary results using ML Kit sentence translation
  Future<dynamic> _applySmartPrioritization(dynamic lookupResult, bool isReverseLookup) async {
    print('🧠 SmartPrioritization: Starting smart prioritization...');
    print('🧠 SmartPrioritization: Is reverse lookup: $isReverseLookup');
    
    // Wait for sentence translation to complete if it's still loading
    if (_sentenceTranslation == null && _isSentenceLoading) {
      print('🧠 SmartPrioritization: Waiting for sentence translation to complete...');
      // Wait a bit for sentence translation, but don't block indefinitely
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // If we don't have sentence translation, return original results
    if (_sentenceTranslation == null || _sentenceTranslation!.trim().isEmpty) {
      print('🧠 SmartPrioritization: No sentence translation available, using original order');
      return lookupResult;
    }
    
    print('🧠 SmartPrioritization: Using sentence translation: "${_sentenceTranslation}"');
    print('🧠 SmartPrioritization: Selected word: "${widget.selectedText}"');
    print('🧠 SmartPrioritization: Source context: "${widget.context}"');
    
    // Calculate expected position of the word in the source sentence
    final expectedPosition = _calculateExpectedPosition();
    
    if (isReverseLookup) {
      return _prioritizeReverseResults(lookupResult as ReverseLookupResult, expectedPosition);
    } else {
      return _prioritizeSourceResults(lookupResult as MeaningLookupResult, expectedPosition);
    }
  }
  
  /// Prioritize source lookup results (meanings)
  MeaningLookupResult _prioritizeSourceResults(MeaningLookupResult sourceResult, int expectedPosition) {
    print('🧠 SmartPrioritization: Prioritizing ${sourceResult.meanings.length} source meanings');
    
    final prioritizedMeanings = <CyclableMeaning>[];
    final scoringResults = <String, _WordPrioritizationResult>{};
    
    for (final meaning in sourceResult.meanings) {
      final targetMeaning = meaning.meaning.targetMeaning;
      final score = _calculateWordPriorityScore(targetMeaning, expectedPosition);
      
      print('🧠 SmartPrioritization: "${targetMeaning}" -> Score: ${score.finalScore.toStringAsFixed(3)} (similarity: ${score.fuzzySimilarity.toStringAsFixed(3)}, position: ${score.positionScore.toStringAsFixed(3)})');
      
      scoringResults[targetMeaning] = score;
      prioritizedMeanings.add(meaning);
    }
    
    // Sort by final score (highest first)
    prioritizedMeanings.sort((a, b) {
      final scoreA = scoringResults[a.meaning.targetMeaning]?.finalScore ?? 0.0;
      final scoreB = scoringResults[b.meaning.targetMeaning]?.finalScore ?? 0.0;
      return scoreB.compareTo(scoreA);
    });
    
    print('🧠 SmartPrioritization: Final order: ${prioritizedMeanings.map((m) => '"${m.meaning.targetMeaning}" (${scoringResults[m.meaning.targetMeaning]?.finalScore.toStringAsFixed(3)})').join(', ')}');
    
    return MeaningLookupResult(
      query: sourceResult.query,
      meanings: prioritizedMeanings,
      sourceLanguage: sourceResult.sourceLanguage,
      targetLanguage: sourceResult.targetLanguage,
      latencyMs: sourceResult.latencyMs,
      fromCache: sourceResult.fromCache,
    );
  }
  
  /// Prioritize reverse lookup results (translations)
  ReverseLookupResult _prioritizeReverseResults(ReverseLookupResult reverseResult, int expectedPosition) {
    print('🧠 SmartPrioritization: Prioritizing ${reverseResult.translations.length} reverse translations');
    
    final prioritizedTranslations = <CyclableReverseLookup>[];
    final scoringResults = <String, _WordPrioritizationResult>{};
    
    for (final translation in reverseResult.translations) {
      final sourceWord = translation.sourceWord;
      final score = _calculateWordPriorityScore(sourceWord, expectedPosition);
      
      print('🧠 SmartPrioritization: "${sourceWord}" -> Score: ${score.finalScore.toStringAsFixed(3)} (similarity: ${score.fuzzySimilarity.toStringAsFixed(3)}, position: ${score.positionScore.toStringAsFixed(3)})');
      
      scoringResults[sourceWord] = score;
      prioritizedTranslations.add(translation);
    }
    
    // Sort by final score (highest first)
    prioritizedTranslations.sort((a, b) {
      final scoreA = scoringResults[a.sourceWord]?.finalScore ?? 0.0;
      final scoreB = scoringResults[b.sourceWord]?.finalScore ?? 0.0;
      return scoreB.compareTo(scoreA);
    });
    
    print('🧠 SmartPrioritization: Final order: ${prioritizedTranslations.map((t) => '"${t.sourceWord}" (${scoringResults[t.sourceWord]?.finalScore.toStringAsFixed(3)})').join(', ')}');
    
    return ReverseLookupResult(
      query: reverseResult.query,
      translations: prioritizedTranslations,
      sourceLanguage: reverseResult.sourceLanguage,
      targetLanguage: reverseResult.targetLanguage,
      latencyMs: reverseResult.latencyMs,
      fromCache: reverseResult.fromCache,
    );
  }
  
  /// Calculate priority score for a word candidate based on fuzzy similarity and position
  _WordPrioritizationResult _calculateWordPriorityScore(String candidate, int expectedPosition) {
    // Check cache first
    final cacheKey = '${candidate}_$expectedPosition';
    if (_scoringCache.containsKey(cacheKey)) {
      return _scoringCache[cacheKey]!;
    }
    
    final sentenceWords = _getCachedSentenceWords();
    
    print('🧠 SmartPrioritization: Sentence words: [${sentenceWords.join(', ')}]');
    print('🧠 SmartPrioritization: Evaluating candidate: "${candidate}"');
    print('🧠 SmartPrioritization: Expected position: $expectedPosition');
    
    // Find best fuzzy match in the sentence
    double bestFuzzySimilarity = 0.0;
    String bestMatch = '';
    int actualPosition = -1;
    
    for (int i = 0; i < sentenceWords.length; i++) {
      final sentenceWord = sentenceWords[i];
      final similarity = _calculateFuzzySimilarity(candidate, sentenceWord);
      
      if (similarity > bestFuzzySimilarity) {
        bestFuzzySimilarity = similarity;
        bestMatch = sentenceWord;
        actualPosition = i;
      }
    }
    
    // Calculate position score (closer to expected = higher score)
    double positionScore = 0.0;
    if (bestFuzzySimilarity > 0.0 && sentenceWords.isNotEmpty) {
      final distance = (expectedPosition - actualPosition).abs();
      final maxDistance = sentenceWords.length;
      positionScore = maxDistance > 0 ? 1.0 - (distance / maxDistance) : 1.0;
    }
    
    // Weighted final score: 80% similarity, 20% position
    final finalScore = (bestFuzzySimilarity * 0.8) + (positionScore * 0.2);
    
    final result = _WordPrioritizationResult(
      fuzzySimilarity: bestFuzzySimilarity,
      positionScore: positionScore,
      finalScore: finalScore,
      bestMatch: bestMatch,
      expectedPosition: expectedPosition,
      actualPosition: actualPosition,
    );
    
    print('🧠 SmartPrioritization: Best match: "${bestMatch}" at position $actualPosition');
    print('🧠 SmartPrioritization: Fuzzy similarity: ${bestFuzzySimilarity.toStringAsFixed(3)}');
    print('🧠 SmartPrioritization: Position score: ${positionScore.toStringAsFixed(3)}');
    print('🧠 SmartPrioritization: Final score: ${finalScore.toStringAsFixed(3)}');
    
    // Cache the result for future use
    _scoringCache[cacheKey] = result;
    
    return result;
  }

  /// Update the current best match for highlighting based on current cycling position
  void _updateCurrentBestMatch() {
    if (_sentenceTranslation == null) {
      _currentBestMatch = null;
      return;
    }

    String? currentCandidate;
    
    // Get current candidate based on cycling position
    if (_sourceLookupResult != null && _sourceLookupResult!.meanings.isNotEmpty) {
      currentCandidate = _sourceLookupResult!.meanings[_currentMeaningIndex].meaning.targetMeaning;
    } else if (_reverseLookupResult != null && _reverseLookupResult!.translations.isNotEmpty) {
      currentCandidate = _reverseLookupResult!.translations[_currentReverseIndex].sourceWord;
    }
    
    if (currentCandidate == null) {
      _currentBestMatch = null;
      return;
    }
    
    print('🎯 Updating best match for current candidate: "$currentCandidate"');
    
    // Use cached sentence words and normalized candidate
    final sentenceWords = _getCachedSentenceWords();
    final normalizedCandidate = _getCachedNormalizedWord(currentCandidate);
    
    for (final sentenceWord in sentenceWords) {
      final normalizedSentenceWord = _getCachedNormalizedWord(sentenceWord);
      
      if (normalizedSentenceWord == normalizedCandidate) {
        _currentBestMatch = sentenceWord;
        print('🎯 Stored best match: "$sentenceWord" for candidate "$currentCandidate"');
        return;
      }
    }
    
    print('🎯 No exact match found for candidate "$currentCandidate"');
    _currentBestMatch = null;
  }
  
  /// Calculate fuzzy similarity between candidate and sentence word
  double _calculateFuzzySimilarity(String candidate, String sentenceWord) {
    final normCandidate = _getCachedNormalizedWord(candidate);
    final normSentenceWord = _getCachedNormalizedWord(sentenceWord);
    
    // Exact match
    if (normCandidate == normSentenceWord) {
      return 1.0;
    }
    
    // Substring match (handles conjugations and partial words)
    if (normSentenceWord.contains(normCandidate) || normCandidate.contains(normSentenceWord)) {
      final longerLength = math.max(normCandidate.length, normSentenceWord.length);
      final shorterLength = math.min(normCandidate.length, normSentenceWord.length);
      
      // Score based on how much of the longer word is covered
      return shorterLength / longerLength * 0.8;
    }
    
    // Levenshtein similarity for spelling variations and accent differences
    final distance = _levenshteinDistance(normCandidate, normSentenceWord);
    final maxLen = math.max(normCandidate.length, normSentenceWord.length);
    
    if (maxLen == 0) return 0.0;
    
    final similarity = 1.0 - (distance / maxLen);
    
    // Only consider it a match if similarity is above threshold and words are not too short
    if (similarity >= 0.7 && maxLen >= 3) {
      return similarity * 0.6; // Reduced score for fuzzy matches
    }
    
    return 0.0;
  }
  
  /// Normalize word for comparison (remove accents, lowercase, trim)
  /// Supports Spanish, French, German, Portuguese, and other European languages
  String _normalizeWord(String word) {
    return word
        .toLowerCase()
        .trim()
        // Remove common punctuation
        .replaceAll(RegExp(r'''[.,!?;:'"]'''), '')
        // Normalize accent variations (Spanish, French, German, Portuguese, Italian)
        .replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ä', 'a').replaceAll('â', 'a').replaceAll('ã', 'a').replaceAll('å', 'a')
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ë', 'e').replaceAll('ê', 'e').replaceAll('ē', 'e')
        .replaceAll('í', 'i').replaceAll('ì', 'i').replaceAll('ï', 'i').replaceAll('î', 'i').replaceAll('ī', 'i')
        .replaceAll('ó', 'o').replaceAll('ò', 'o').replaceAll('ö', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o').replaceAll('ø', 'o')
        .replaceAll('ú', 'u').replaceAll('ù', 'u').replaceAll('ü', 'u').replaceAll('û', 'u').replaceAll('ū', 'u')
        .replaceAll('ñ', 'n').replaceAll('ç', 'c').replaceAll('ß', 'ss') // German ß
        .replaceAll('æ', 'ae').replaceAll('œ', 'oe'); // French ligatures
  }
  
  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    
    final List<List<int>> matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );
    
    // Initialize first row and column
    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }
    
    // Fill the matrix
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(
            matrix[i - 1][j] + 1,     // deletion
            matrix[i][j - 1] + 1,     // insertion
          ),
          matrix[i - 1][j - 1] + cost, // substitution
        );
      }
    }
    
    return matrix[a.length][b.length];
  }
  
  /// Calculate expected position of the selected word in the source sentence
  int _calculateExpectedPosition() {
    if (widget.context == null || widget.context!.trim().isEmpty) {
      return 0; // Default to beginning if no context
    }
    
    final sourceWords = widget.context!.toLowerCase()
        .split(RegExp(r'[\s\p{P}]+', unicode: true))
        .where((word) => word.isNotEmpty)
        .toList();
    
    final normalizedSelectedWord = _getCachedNormalizedWord(widget.selectedText);
    
    // Find the position of the selected word in the source sentence
    for (int i = 0; i < sourceWords.length; i++) {
      final normalizedSourceWord = _getCachedNormalizedWord(sourceWords[i]);
      if (normalizedSourceWord.contains(normalizedSelectedWord) || 
          normalizedSelectedWord.contains(normalizedSourceWord)) {
        print('🧠 SmartPrioritization: Found selected word "${widget.selectedText}" at position $i in source sentence');
        return i;
      }
    }
    
    print('🧠 SmartPrioritization: Selected word "${widget.selectedText}" not found in context, defaulting to position 0');
    return 0; // Default to beginning if word not found
  }
  
  /// Performance optimization: Cache helpers
  
  /// Get cached sentence words, splitting only once
  List<String> _getCachedSentenceWords() {
    if (_cachedSentenceWords == null && _sentenceTranslation != null) {
      _cachedSentenceWords = _sentenceTranslation!.toLowerCase()
          .split(RegExp(r'[\s\p{P}]+', unicode: true))
          .where((word) => word.isNotEmpty)
          .toList();
    }
    return _cachedSentenceWords ?? [];
  }
  
  /// Get cached normalized word
  String _getCachedNormalizedWord(String word) {
    if (!_normalizedWordCache.containsKey(word)) {
      _normalizedWordCache[word] = _normalizeWord(word);
    }
    return _normalizedWordCache[word]!;
  }
  
  /// Invalidate performance caches when sentence translation changes
  void _invalidatePerformanceCache() {
    _cachedSentenceWords = null;
    _normalizedWordCache.clear();
    _scoringCache.clear();
  }
  
  /// Get text style for translation based on sentence matching confidence
  TextStyle? _getTranslationTextStyle(String translation) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
    );
    
    // If no sentence translation available, use default styling
    if (_sentenceTranslation == null) {
      return baseStyle?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );
    }
    
    // Check if this translation has a good match in the sentence
    final hasGoodMatch = _checkTranslationMatch(translation);
    
    if (hasGoodMatch) {
      // Good match: confident styling with bold weight and primary color
      return baseStyle?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600, // Bolder for confident matches
      );
    } else {
      // No good match: same style but reduced opacity to show uncertainty
      return baseStyle?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), // Reduced opacity
      );
    }
  }
  
  /// Check if a translation has a good match in the sentence
  bool _checkTranslationMatch(String translation) {
    if (_sentenceTranslation == null) return false;
    
    final sentenceWords = _getCachedSentenceWords();
    final normalizedTranslation = _getCachedNormalizedWord(translation);
    
    // Check for exact or fuzzy matches above confidence threshold
    for (final sentenceWord in sentenceWords) {
      final normalizedSentenceWord = _getCachedNormalizedWord(sentenceWord);
      
      // Exact match
      if (normalizedSentenceWord == normalizedTranslation) {
        return true;
      }
      
      // Fuzzy match above threshold
      final similarity = _calculateFuzzySimilarity(translation, sentenceWord);
      if (similarity >= 0.6) { // Slightly lower threshold than highlighting (0.7)
        return true;
      }
    }
    
    return false;
  }

  /// Update best match for highlighting ML Kit translation
  void _updateCurrentBestMatchForMlKit(String mlKitTranslation) {
    if (_sentenceTranslation == null) {
      _currentBestMatch = null;
      return;
    }
    
    print('🎯 Updating best match for ML Kit translation: "$mlKitTranslation"');
    
    // Use cached sentence words and normalized ML Kit translation
    final sentenceWords = _getCachedSentenceWords();
    final normalizedMlKit = _getCachedNormalizedWord(mlKitTranslation);
    
    // Find exact match first
    for (final sentenceWord in sentenceWords) {
      final normalizedSentenceWord = _getCachedNormalizedWord(sentenceWord);
      
      if (normalizedSentenceWord == normalizedMlKit) {
        _currentBestMatch = sentenceWord;
        print('🎯 Stored ML Kit best match: "$sentenceWord" for translation "$mlKitTranslation"');
        return;
      }
    }
    
    // If no exact match, try fuzzy matching like in prioritization
    double bestSimilarity = 0.0;
    String? bestMatch;
    
    for (final sentenceWord in sentenceWords) {
      final similarity = _calculateFuzzySimilarity(mlKitTranslation, sentenceWord);
      if (similarity > bestSimilarity && similarity > 0.7) { // Use same threshold as prioritization
        bestSimilarity = similarity;
        bestMatch = sentenceWord;
      }
    }
    
    if (bestMatch != null) {
      _currentBestMatch = bestMatch;
      print('🎯 Stored ML Kit fuzzy match: "$bestMatch" (similarity: ${bestSimilarity.toStringAsFixed(3)}) for translation "$mlKitTranslation"');
    } else {
      _currentBestMatch = null;
      print('🎯 No match found for ML Kit translation "$mlKitTranslation"');
    }
  }

  /// Launch dictionary URL for the original word
  Future<void> _launchDictionaryLink() async {
    final settings = ref.read(settingsProvider);
    final homeLanguage = settings.defaultTargetLanguage;
    
    if (homeLanguage == 'auto' || homeLanguage == widget.sourceLanguage) {
      // If home language is auto or same as source, don't show dictionary
      return;
    }
    
    final url = DictionaryLinkService.getDictionaryUrl(
      widget.selectedText,
      widget.sourceLanguage,
      homeLanguage,
    );
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('🔗 Launched dictionary: $url');
      } else {
        print('❌ Cannot launch dictionary URL: $url');
      }
    } catch (e) {
      print('❌ Error launching dictionary: $e');
    }
  }

  /// Create clickable text span for original word
  TextSpan _createClickableOriginalWordSpan() {
    final settings = ref.read(settingsProvider);
    final homeLanguage = settings.defaultTargetLanguage;
    final isClickable = homeLanguage != 'auto' && homeLanguage != widget.sourceLanguage;
    
    return TextSpan(
      text: widget.selectedText,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: isClickable 
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w400,
        decoration: isClickable ? TextDecoration.underline : null,
        decorationColor: isClickable ? Theme.of(context).colorScheme.primary : null,
      ),
      recognizer: isClickable ? (TapGestureRecognizer()..onTap = _launchDictionaryLink) : null,
    );
  }

  /// Create clickable text span for translated word (for cycling)
  TextSpan _createClickableTranslatedWordSpan(String translatedText) {
    final baseStyle = _getTranslationTextStyle(translatedText);
    return TextSpan(
      text: translatedText,
      style: (baseStyle ?? Theme.of(context).textTheme.bodyLarge)?.copyWith(
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
      ),
      recognizer: TapGestureRecognizer()..onTap = _handleTap,
    );
  }
}