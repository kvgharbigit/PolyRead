// Cycling Translation Popup with expansion UI pattern
// Supports tap-to-cycle + long-press/tap-to-expand for any language pair

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/meaning_entry.dart';
import '../services/cycling_dictionary_service.dart';
import '../../../core/providers/database_provider.dart';
import '../../reader/providers/reader_translation_provider.dart';

class CyclingTranslationPopup extends ConsumerStatefulWidget {
  final String selectedText;
  final String sourceLanguage;
  final String targetLanguage;
  final Offset? position;
  final VoidCallback? onClose;
  final String? context; // Add sentence context for translation
  final dynamic translationService; // Add translation service for sentences

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

class _CyclingTranslationPopupState extends ConsumerState<CyclingTranslationPopup> {
  late CyclingDictionaryService _dictionaryService;
  
  // Source → Target lookup state
  MeaningLookupResult? _sourceLookupResult;
  int _currentMeaningIndex = 0;
  bool _meaningExpanded = false;
  
  // Target → Source lookup state
  ReverseLookupResult? _reverseLookupResult;
  int _currentReverseIndex = 0;
  bool _reverseExpanded = false;
  
  // UI state
  bool _isLoading = true;
  bool _isReverseLookup = false;
  String? _error;
  
  // Sentence translation state
  String? _sentenceTranslation;
  bool _sentenceLoading = false;

  @override
  void initState() {
    super.initState();
    _dictionaryService = ref.read(cyclingDictionaryServiceProvider);
    _performLookup();
  }

  Future<void> _performLookup() async {
    print('🔍 Translation popup: Starting lookup for "${widget.selectedText}" (${widget.sourceLanguage} → ${widget.targetLanguage})');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First check if language pack is available
      final packId = '${widget.sourceLanguage}-${widget.targetLanguage}';
      print('📦 Translation popup: Checking availability for pack: $packId');
      final isDictionaryAvailable = await _checkDictionaryAvailable();
      
      if (!isDictionaryAvailable) {
        print('🚫 Translation popup: Dictionary not available for $packId');
        setState(() {
          _error = 'Language pack not installed: $packId';
          _isLoading = false;
        });
        return;
      }
      
      print('✅ Translation popup: Dictionary available for $packId');

      // Try source → target lookup first (e.g., en → es)
      final sourceResult = await _dictionaryService.lookupSourceMeanings(
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
        _loadSentenceTranslation(); // Load sentence after word translation
        return;
      }

      // Try target → source reverse lookup (e.g., en → es via reverse)
      final reverseResult = await _dictionaryService.lookupTargetTranslations(
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
        _loadSentenceTranslation(); // Load sentence after reverse lookup
        return;
      }
      
      // Try opposite direction lookup (e.g., look up English word in es-en dictionary)
      print('🔄 Trying opposite direction lookup: ${widget.targetLanguage}-${widget.sourceLanguage}');
      final oppositeSourceResult = await _dictionaryService.lookupSourceMeanings(
        widget.selectedText,
        widget.targetLanguage,
        widget.sourceLanguage,
      );

      print('📝 Opposite source lookup result: ${oppositeSourceResult.hasResults ? oppositeSourceResult.meanings.length : 0} meanings');
      if (oppositeSourceResult.hasResults) {
        print('✅ Found meanings in opposite direction!');
        setState(() {
          _sourceLookupResult = oppositeSourceResult;
          _isReverseLookup = false;
          _isLoading = false;
        });
        _loadSentenceTranslation();
        return;
      }
      
      // Try opposite direction reverse lookup (most likely to work for en→es)
      print('🔄 Trying opposite direction reverse lookup...');
      final oppositeReverseResult = await _dictionaryService.lookupTargetTranslations(
        widget.selectedText,
        widget.targetLanguage,
        widget.sourceLanguage,
      );

      print('📝 Opposite reverse lookup result: ${oppositeReverseResult.hasResults ? oppositeReverseResult.translations.length : 0} translations');
      if (oppositeReverseResult.hasResults) {
        print('✅ Found translations in opposite reverse direction!');
        setState(() {
          _reverseLookupResult = oppositeReverseResult;
          _isReverseLookup = true;
          _isLoading = false;
        });
        _loadSentenceTranslation();
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

  void _cycleToNextMeaning() {
    if (_isReverseLookup && _reverseLookupResult != null) {
      setState(() {
        _currentReverseIndex = (_currentReverseIndex + 1) % _reverseLookupResult!.translations.length;
        _reverseExpanded = false; // Collapse when cycling
      });
    } else if (_sourceLookupResult != null) {
      setState(() {
        _currentMeaningIndex = (_currentMeaningIndex + 1) % _sourceLookupResult!.meanings.length;
        _meaningExpanded = false; // Collapse when cycling
      });
    }
  }

  void _toggleExpansion() {
    setState(() {
      if (_isReverseLookup) {
        _reverseExpanded = !_reverseExpanded;
      } else {
        _meaningExpanded = !_meaningExpanded;
      }
    });
  }

  Future<void> _loadSentenceTranslation() async {
    if (widget.context == null || 
        widget.context!.isEmpty || 
        widget.translationService == null) {
      return;
    }

    setState(() {
      _sentenceLoading = true;
    });

    try {
      final sentence = _extractSentenceFromContext();
      if (sentence.isEmpty) {
        setState(() {
          _sentenceLoading = false;
        });
        return;
      }

      final response = await widget.translationService?.translateText(
        text: sentence,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );

      setState(() {
        _sentenceTranslation = (response != null && response.error == null && response.translatedText.isNotEmpty) 
            ? response.translatedText 
            : null;
        _sentenceLoading = false;
      });
    } catch (e) {
      setState(() {
        _sentenceLoading = false;
      });
    }
  }

  String _extractSentenceFromContext() {
    if (widget.context == null || widget.context!.isEmpty) return '';
    
    final context = widget.context!;
    final selectedText = widget.selectedText;
    final selectedIndex = context.indexOf(selectedText);
    
    if (selectedIndex == -1) return context;
    
    int sentenceStart = 0;
    int sentenceEnd = context.length;
    
    // Find sentence start
    for (int i = selectedIndex; i >= 0; i--) {
      if (i < context.length - 1 && RegExp(r'[.!?]\s').hasMatch(context.substring(i, i + 2))) {
        sentenceStart = i + 2;
        break;
      }
    }
    
    // Find sentence end
    for (int i = selectedIndex; i < context.length - 1; i++) {
      if (RegExp(r'[.!?]\s').hasMatch(context.substring(i, i + 2))) {
        sentenceEnd = i + 1;
        break;
      }
    }
    
    return context.substring(sentenceStart, sentenceEnd).trim();
  }

  Widget _buildLoadingView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            'Looking up "${widget.selectedText}"...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    // More comprehensive detection of missing language pack scenarios
    final isLanguagePackMissing = _error?.contains('Language pack not installed') == true ||
                                  _error?.contains('No translation found') == true ||
                                  _error?.contains('Dictionary not available') == true ||
                                  _error?.toLowerCase().contains('missing') == true ||
                                  _error?.toLowerCase().contains('not available') == true;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLanguagePackMissing ? Icons.download : Icons.error_outline,
            color: isLanguagePackMissing 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            isLanguagePackMissing 
                ? 'Dictionary not available'
                : 'Translation error',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isLanguagePackMissing 
                ? 'Install ${widget.sourceLanguage}-${widget.targetLanguage} language pack to translate "${widget.selectedText}"'
                : _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (isLanguagePackMissing) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openLanguagePackManager,
              icon: const Icon(Icons.download),
              label: const Text('Install Language Packs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceMeaningView() {
    final meaning = _sourceLookupResult!.meanings[_currentMeaningIndex];
    final isExpanded = _meaningExpanded;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with source word and language info
          Row(
            children: [
              Text(
                meaning.sourceWord,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (meaning.partOfSpeechTag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    meaning.partOfSpeechTag!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                meaning.languagePair,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Main translation area (tappable for cycling and expansion)
          GestureDetector(
            onTap: _sourceLookupResult!.meanings.length > 1 ? _cycleToNextMeaning : _toggleExpansion,
            onLongPress: _toggleExpansion,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpanded ? meaning.expandedTranslation : meaning.displayTranslation,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (meaning.isPrimary)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        'PRIMARY',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Bottom controls and info
          Row(
            children: [
              // Cycling indicator
              if (_sourceLookupResult!.meanings.length > 1) ...[
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Tap (${_currentMeaningIndex + 1}/${_sourceLookupResult!.meanings.length})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // Expansion indicator
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Hold for details',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const Spacer(),
              
              // Close button
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          
          // Sentence translation (if available)
          if (widget.context != null && widget.context!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSentenceTranslation(),
          ],
        ],
      ),
    );
  }

  Widget _buildSentenceTranslation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Divider(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          height: 1,
        ),
        const SizedBox(height: 12),
        
        // Section header
        Row(
          children: [
            Icon(
              Icons.text_fields,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'Sentence Translation',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Translated sentence
        if (_sentenceLoading)
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Translating sentence...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else if (_sentenceTranslation != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Text(
              _sentenceTranslation!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        
        const SizedBox(height: 8),
        
        // Original sentence with highlighted word
        _buildClickableOriginalSentence(),
      ],
    );
  }

  Widget _buildClickableOriginalSentence() {
    if (widget.context == null || widget.context!.isEmpty) {
      return const SizedBox.shrink();
    }

    final sentence = _extractSentenceFromContext();
    if (sentence.isEmpty) return const SizedBox.shrink();

    final words = sentence.split(' ');
    final spans = <InlineSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isSelectedWord = word.toLowerCase().contains(widget.selectedText.toLowerCase());

      spans.add(
        TextSpan(
          text: word,
          style: TextStyle(
            color: isSelectedWord 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isSelectedWord ? FontWeight.bold : FontWeight.normal,
            decoration: isSelectedWord ? TextDecoration.underline : null,
          ),
        ),
      );

      if (i < words.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: spans,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildReverseLookupView() {
    final translation = _reverseLookupResult!.translations[_currentReverseIndex];
    final isExpanded = _reverseExpanded;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with target word and language info
          Row(
            children: [
              Text(
                translation.targetWord,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (translation.partOfSpeechTag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    translation.partOfSpeechTag!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '${widget.targetLanguage}→${widget.sourceLanguage}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Main translation area (tappable for cycling and expansion)
          GestureDetector(
            onTap: _reverseLookupResult!.translations.length > 1 ? _cycleToNextMeaning : _toggleExpansion,
            onLongPress: _toggleExpansion,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpanded ? translation.expandedTranslation : translation.displayTranslation,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (translation.qualityIndicator.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        translation.qualityIndicator,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Bottom controls and info
          Row(
            children: [
              // Cycling indicator
              if (_reverseLookupResult!.translations.length > 1) ...[
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Tap (${_currentReverseIndex + 1}/${_reverseLookupResult!.translations.length})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // Expansion indicator
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Hold for details',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const Spacer(),
              
              // Close button
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          
          // Sentence translation (if available)
          if (widget.context != null && widget.context!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSentenceTranslation(),
          ],
        ],
      ),
    );
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

    // Calculate optimal position to keep popup on screen
    final screenSize = MediaQuery.of(context).size;
    final tapPosition = widget.position ?? const Offset(50, 100);
    
    // Popup dimensions - more realistic estimates
    const popupWidth = 300.0;
    const popupMinHeight = 120.0; // Minimum height for loading/error states
    const popupMaxHeight = 250.0; // More conservative max height
    const margin = 16.0; // Margin from screen edges
    const tapOffset = 40.0; // Offset from tap point
    
    // Calculate horizontal position
    double left = tapPosition.dx;
    if (left + popupWidth + margin > screenSize.width) {
      // Would go off right edge, position to the left of tap
      left = tapPosition.dx - popupWidth;
      print('📍 Popup positioned to left of tap (${tapPosition.dx} → $left)');
    }
    if (left < margin) {
      // Would go off left edge, clamp to margin
      left = margin;
      print('📍 Popup clamped to left margin ($left)');
    }
    
    // Calculate vertical position with better logic
    double top = tapPosition.dy + tapOffset; // Position below tap point
    final bottomBoundary = screenSize.height - margin;
    final topBoundary = margin;
    
    // Check if popup would go off bottom
    if (top + popupMaxHeight > bottomBoundary) {
      // Try positioning above tap point
      final alternateTop = tapPosition.dy - popupMaxHeight - tapOffset;
      if (alternateTop >= topBoundary) {
        // Fits above, use it
        top = alternateTop;
        print('📍 Popup positioned above tap (${tapPosition.dy} → $top)');
      } else {
        // Doesn't fit above either, find best position
        final spaceAbove = tapPosition.dy - topBoundary;
        final spaceBelow = bottomBoundary - (tapPosition.dy + tapOffset);
        
        if (spaceBelow >= popupMinHeight) {
          // Use space below, but clamp to fit
          top = tapPosition.dy + tapOffset;
          print('📍 Popup positioned below with limited space');
        } else if (spaceAbove >= popupMinHeight) {
          // Use space above
          top = topBoundary;
          print('📍 Popup positioned at top with limited space');
        } else {
          // Very little space, center on tap point
          top = (tapPosition.dy - popupMaxHeight / 2).clamp(topBoundary, bottomBoundary - popupMaxHeight);
          print('📍 Popup centered on tap due to limited space');
        }
      }
    }
    
    // Final bounds check
    if (top < topBoundary) {
      top = topBoundary;
      print('📍 Popup clamped to top boundary ($top)');
    }
    if (top + popupMinHeight > bottomBoundary) {
      top = bottomBoundary - popupMinHeight;
      print('📍 Popup clamped to bottom boundary ($top)');
    }
    
    print('📍 Final popup position: ($left, $top) for tap at (${tapPosition.dx}, ${tapPosition.dy}) on ${screenSize.width}x${screenSize.height} screen');

    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 300,
            minWidth: 250,
            minHeight: 120, // Ensure minimum height
            maxHeight: 250, // More conservative max height
          ),
          child: content,
        ),
      ),
    );
  }
  
  /// Check if dictionary is available for the language pair (checking both directions)
  Future<bool> _checkDictionaryAvailable() async {
    print('🔎 _checkDictionaryAvailable called for ${widget.sourceLanguage} → ${widget.targetLanguage}');
    try {
      // Check forward direction (source → target)
      final forwardStats = await _dictionaryService.getStats(
        widget.sourceLanguage, 
        widget.targetLanguage,
      );
      
      final forwardWordGroups = forwardStats['wordGroups'] as int? ?? 0;
      final forwardMeanings = forwardStats['meanings'] as int? ?? 0;
      
      print('📊 Dictionary stats for ${widget.sourceLanguage}-${widget.targetLanguage}: $forwardWordGroups word groups, $forwardMeanings meanings');
      
      // If forward direction has data, dictionary is available
      if (forwardWordGroups > 0) {
        return true;
      }
      
      // Check reverse direction (target → source) for bidirectional support
      final reverseStats = await _dictionaryService.getStats(
        widget.targetLanguage,
        widget.sourceLanguage, 
      );
      
      final reverseWordGroups = reverseStats['wordGroups'] as int? ?? 0;
      final reverseMeanings = reverseStats['meanings'] as int? ?? 0;
      
      print('📊 Dictionary stats for ${widget.targetLanguage}-${widget.sourceLanguage} (reverse): $reverseWordGroups word groups, $reverseMeanings meanings');
      
      // Consider dictionary available if either direction has word groups
      return reverseWordGroups > 0;
    } catch (e) {
      print('❌ Error checking dictionary availability: $e');
      return false;
    }
  }
  
  /// Open language pack manager for downloading dictionaries
  void _openLanguagePackManager() {
    // Close the translation popup first
    widget.onClose?.call();
    
    // Navigate to language pack manager using GoRouter
    GoRouter.of(context).push('/language-packs');
  }
}