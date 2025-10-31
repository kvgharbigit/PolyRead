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
  
  @override
  void initState() {
    super.initState();
    
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

  @override
  Widget build(BuildContext context) {
    Widget content;
    
    if (_isLoading) {
      content = _buildLoadingView();
    } else if (_error != null) {
      content = _buildErrorView();
    } else if (_mlKitFallbackResult != null) {
      content = _buildMlKitFallbackView();
    } else if (_isReverseLookup && _reverseLookupResult != null) {
      content = _buildReverseLookupView();
    } else if (_sourceLookupResult != null) {
      content = _buildSourceMeaningView();
    } else {
      content = _buildErrorView();
    }

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
                      child: Container(
                        width: _isExpanded ? 300 : 200,
                        constraints: BoxConstraints(
                          minWidth: _isExpanded ? 300 : 200,
                          maxWidth: _isExpanded ? 300 : 200,
                        ),
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
    
    // Adaptive positioning for different popup sizes
    final popupWidth = _isExpanded ? 300.0 : 200.0;
    final x = widget.position!.dx - (popupWidth / 2); // Center popup
    final y = widget.position!.dy + 20;   // Below selection
    
    return {'left': x.clamp(10.0, 400.0), 'top': y.clamp(50.0, 600.0)};
  }
}