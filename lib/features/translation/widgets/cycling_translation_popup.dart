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
  bool _meaningExpanded = false;
  bool _reverseExpanded = false;
  
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
    // Initialize dictionary service if not already done
    _dictionaryService ??= ref.read(cyclingDictionaryServiceProvider);
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Simple lookup - try source meanings first
      final sourceResult = await _dictionaryService!.lookupSourceMeanings(
        widget.selectedText,
        widget.sourceLanguage,
        widget.targetLanguage,
      );

      if (sourceResult.hasResults) {
        setState(() {
          _sourceLookupResult = sourceResult;
          _isReverseLookup = false;
          _isLoading = false;
        });
        return;
      }

      // Try reverse lookup
      final reverseResult = await _dictionaryService!.lookupTargetTranslations(
        widget.selectedText,
        widget.sourceLanguage,
        widget.targetLanguage,
      );

      if (reverseResult.hasResults) {
        setState(() {
          _reverseLookupResult = reverseResult;
          _isReverseLookup = true;
          _isLoading = false;
        });
        return;
      }

      // No results found
      setState(() {
        _error = 'No translation found for "${widget.selectedText}"';
        _isLoading = false;
      });
    } catch (e) {
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
                        width: 280,
                        constraints: const BoxConstraints(
                          minHeight: 80,
                          maxHeight: 300,
                          maxWidth: 280,
                        ),
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
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Container(
      padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          Text(
            'Looking up "${widget.selectedText}"...',
            style: PolyReadTypography.interfaceCaption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 32,
          ),
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          Text(
            'Translation Error',
            style: PolyReadTypography.interfaceHeadline.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PolyReadSpacing.smallSpacing),
          Text(
            _error ?? 'Unknown error occurred',
            style: PolyReadTypography.interfaceCaption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
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
    
    return Flexible(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(PolyReadSpacing.elementSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Word and meaning
              Text(
                widget.selectedText,
                style: PolyReadTypography.translationWord.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: PolyReadSpacing.smallSpacing),
              Text(
                cyclableMeaning.displayTranslation,
                style: PolyReadTypography.translationMeaning.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (cyclableMeaning.meaning.context?.isNotEmpty == true) ...[
                const SizedBox(height: PolyReadSpacing.microSpacing),
                Text(
                  cyclableMeaning.meaning.context!,
                  style: PolyReadTypography.translationContext.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // Close button
              const SizedBox(height: PolyReadSpacing.elementSpacing),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onClose,
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReverseLookupView() {
    if (_reverseLookupResult == null || _reverseLookupResult!.translations.isEmpty) {
      return _buildErrorView();
    }
    
    final cyclableReverse = _reverseLookupResult!.translations[_currentReverseIndex];
    
    return Flexible(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(PolyReadSpacing.elementSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Word and translation
              Text(
                widget.selectedText,
                style: PolyReadTypography.translationWord.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: PolyReadSpacing.smallSpacing),
              Text(
                cyclableReverse.displayTranslation,
                style: PolyReadTypography.translationMeaning.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Close button
              const SizedBox(height: PolyReadSpacing.elementSpacing),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onClose,
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, double> _calculatePopupPosition() {
    if (widget.position == null) {
      return {'left': 50.0, 'top': 100.0};
    }
    
    // Simple positioning - center the popup
    final x = widget.position!.dx - 150; // Half of popup width (300)
    final y = widget.position!.dy + 20;   // Below selection
    
    return {'left': x.clamp(10.0, 400.0), 'top': y.clamp(50.0, 600.0)};
  }
}