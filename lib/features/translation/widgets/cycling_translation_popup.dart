// Enhanced Cycling Translation Popup
// Reading-optimized translation overlay with PolyRead design integration
// Minimal working version for compilation

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/meaning_entry.dart';
import '../services/cycling_dictionary_service.dart';
import '../../reader/providers/reader_translation_provider.dart';
import '../../../core/themes/polyread_spacing.dart';
import '../../../core/themes/polyread_typography.dart';
import '../../../core/themes/polyread_theme.dart';
import '../../../core/utils/constants.dart';
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
  bool _isExpanded = false;
  String? _mlKitFallbackResult; // Store ML Kit fallback translation
  String? _expandedDefinition; // Store ML Kit translated expanded definition
  String? _sentenceTranslation; // Store ML Kit sentence translation
  bool _isSentenceLoading = false; // Loading state for sentence translation
  
  // Performance optimization: Cache calculated constraints
  BoxConstraints? _cachedConstraints;
  Size? _lastScreenSize;
  
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

  /// Handle long press for expanded definition
  void _handleLongPress() async {
    if (_isExpanded) return; // Already expanded
    
    // Check if there's actually context to expand
    bool hasContext = false;
    String fullDefinition = '';
    
    if (_isReverseLookup && _reverseLookupResult != null) {
      final cyclableReverse = _reverseLookupResult!.translations[_currentReverseIndex];
      
      // For reverse lookup, check if there's context available from the original entry
      hasContext = cyclableReverse.context?.isNotEmpty == true;
      
      if (hasContext) {
        // Extract only the context part for translation to home language
        fullDefinition = cyclableReverse.context!;
      }
    } else if (_sourceLookupResult != null) {
      final cyclableMeaning = _sourceLookupResult!.meanings[_currentMeaningIndex];
      
      // Only expand if there's actual context information
      hasContext = cyclableMeaning.meaning.context?.isNotEmpty == true;
      
      if (hasContext) {
        // Extract only the context part, not the repeated word
        fullDefinition = cyclableMeaning.meaning.context!;
      }
    } else if (_mlKitFallbackResult != null) {
      // ML Kit fallback has no context to expand
      hasContext = false;
    }
    
    if (!hasContext) return; // Nothing to expand
    
    setState(() {
      _isExpanded = true;
    });
    
    // Translate the expanded definition to home language using ML Kit
    if (fullDefinition.isNotEmpty && widget.translationService != null) {
      try {
        final translationResponse = await widget.translationService.translateText(
          text: fullDefinition,
          sourceLanguage: widget.sourceLanguage,
          targetLanguage: widget.targetLanguage,
          useCache: true,
        );
        
        if (translationResponse.translatedText.isNotEmpty) {
          setState(() {
            _expandedDefinition = translationResponse.translatedText;
          });
        }
      } catch (e) {
        print('Failed to translate expanded definition: $e');
        // Fallback to original definition
        setState(() {
          _expandedDefinition = fullDefinition;
        });
      }
    }
  }
  
  /// Handle tap for cycling through meanings
  void _handleTap() {
    if (_isExpanded) {
      // Collapse expanded view
      setState(() {
        _isExpanded = false;
        _expandedDefinition = null;
      });
      return;
    }
    
    // Cycle through meanings if available
    if (_isReverseLookup && _reverseLookupResult != null) {
      if (_currentReverseIndex < _reverseLookupResult!.translations.length - 1) {
        setState(() {
          _currentReverseIndex++;
        });
      } else {
        setState(() {
          _currentReverseIndex = 0; // Loop back to first
        });
      }
    } else if (_sourceLookupResult != null) {
      if (_currentMeaningIndex < _sourceLookupResult!.meanings.length - 1) {
        setState(() {
          _currentMeaningIndex++;
        });
      } else {
        setState(() {
          _currentMeaningIndex = 0; // Loop back to first
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
      
      // Simple lookup - try source meanings first
      final sourceResult = await _dictionaryService!.lookupSourceMeanings(
        widget.selectedText,
        widget.sourceLanguage,
        widget.targetLanguage,
      );

      print('CyclingPopup: Source lookup result - hasResults: ${sourceResult.hasResults}');
      if (sourceResult.hasResults) {
        print('CyclingPopup: Source lookup found ${sourceResult.meanings.length} meanings');
        setState(() {
          _sourceLookupResult = sourceResult;
          _isReverseLookup = false;
          _isLoading = false;
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
        setState(() {
          _reverseLookupResult = reverseResult;
          _isReverseLookup = true;
          _isLoading = false;
        });
        return;
      }

      // No results found in dictionary, try ML Kit as fallback
      print('CyclingPopup: No results found in either direction for "${widget.selectedText}"');
      await _tryMlKitFallback();
      
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
                            child: GestureDetector(
                              onLongPress: _handleLongPress,
                              onTap: _handleTap,
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
              // Translation text
              Expanded(
                child: Text(
                  cyclableMeaning.displayTranslation,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: _isExpanded ? null : 2,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          // Expanded content when long-pressed
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show the translated expanded definition
                  if (_expandedDefinition != null)
                    Text(
                      _expandedDefinition!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  else
                    // Minimal loading indicator for translation
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Translating context...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ] else ...[
            // Indicators: cycling and expansion availability
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cycling indicator (if multiple meanings)
                if (cyclableMeaning.totalMeanings > 1)
                  Text(
                    '${cyclableMeaning.currentIndex}/${cyclableMeaning.totalMeanings}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                
                // Expansion indicator (if context available)
                if (cyclableMeaning.meaning.context?.isNotEmpty == true)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
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
              // Translation text
              Expanded(
                child: Text(
                  cyclableReverse.displayTranslation,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: _isExpanded ? null : 2,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          // Expanded content when long-pressed
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Just the expanded translation content
                  if (_expandedDefinition != null)
                    Text(
                      _expandedDefinition!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  else
                    // Minimal loading indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Translating...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ] else ...[
            // Indicators: cycling and expansion availability
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cycling indicator (if multiple translations)
                if (cyclableReverse.totalTranslations > 1)
                  Text(
                    '${cyclableReverse.currentIndex}/${cyclableReverse.totalTranslations}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                
                // Expansion indicator (if context available)
                if (cyclableReverse.context?.isNotEmpty == true)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
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
              // Translation text
              Expanded(
                child: Text(
                  _mlKitFallbackResult!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
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
    
    // Factor in expanded content
    if (_isExpanded && _expandedDefinition != null) {
      final expandedLength = _expandedDefinition!.length;
      estimatedLines += ((expandedLength / 45).ceil()).clamp(1, 5);
      estimatedMinHeight += estimatedLines * 20;
    }
    
    return _ContentMetrics(
      estimatedMinHeight: estimatedMinHeight,
      estimatedLines: estimatedLines,
      hasLongContent: estimatedLines > 3,
    );
  }
  
  /// Get content-aware maximum width
  double _getContentAwareMaxWidth(double availableWidth, _ContentMetrics metrics) {
    if (_isExpanded) {
      return (availableWidth * 0.9).clamp(320, double.infinity);
    } else if (metrics.hasLongContent) {
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
    if (_isExpanded) {
      return 280; // Expanded content needs more space
    } else if (_sentenceTranslation != null || _isSentenceLoading) {
      return 240; // Sentence translation minimum
    } else {
      return 180; // Word-only minimum
    }
  }
  
  /// Get base maximum width based on available space
  double _getBaseMaxWidth(double availableWidth) {
    if (_isExpanded) {
      return (availableWidth * 0.9).clamp(320, double.infinity);
    } else if (_sentenceTranslation != null || _isSentenceLoading) {
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
        // Label for sentence translation
        Text(
          'Sentence:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        // Translated sentence - fully visible without line limits
        Text(
          _sentenceTranslation!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.4, // Slightly more line height for readability
            fontSize: 14, // Slightly smaller for longer text
          ),
          // No maxLines limit - let it expand as needed
          softWrap: true,
        ),
      ],
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
        setState(() {
          _error = null;
          _isLoading = false;
          // Store the ML Kit result for display (will need to add a field for this)
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
}