// Enhanced Cycling Translation Popup
// Based on PolyBook's superior UI patterns with improved positioning and animations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/meaning_entry.dart';
import '../services/cycling_dictionary_service.dart';
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

class _CyclingTranslationPopupState extends ConsumerState<CyclingTranslationPopup>
    with TickerProviderStateMixin {
  late CyclingDictionaryService _dictionaryService;
  
  // Animation controllers (PolyBook-inspired)
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
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
    
    // Initialize animations (PolyBook pattern)
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
    
    // Start animations and lookup
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
  
  // Animation methods - _hidePopup() removed as animations are handled in dispose

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
    print('🔄 Loading sentence translation...');
    print('📝 Context: ${widget.context?.isNotEmpty == true ? "Available (${widget.context!.length} chars)" : "None"}');
    print('🔧 Translation service: ${widget.translationService != null ? "Available" : "Null"}');
    
    if (widget.context == null || 
        widget.context!.isEmpty || 
        widget.translationService == null) {
      print('❌ Sentence translation skipped: missing context or service');
      return;
    }

    setState(() {
      _sentenceLoading = true;
    });

    try {
      final sentence = _extractSentenceFromContext();
      print('📄 Extracted sentence: "${sentence.isEmpty ? "EMPTY" : sentence}"');
      if (sentence.isEmpty) {
        setState(() {
          _sentenceLoading = false;
        });
        return;
      }

      print('📤 Calling translateText for: "${sentence.substring(0, sentence.length.clamp(0, 50))}..."');
      
      final response = await widget.translationService?.translateText(
        text: sentence,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );

      print('📤 Translation response received: ${response != null ? "Success" : "Null"}');
      if (response != null) {
        print('❌ Has error: ${response.error ?? "None"}');
        print('📝 Translated text length: ${response.translatedText.length}');
        print('🔧 Provider: ${response.providerId ?? "Unknown"}');
        if (response.translatedText.isNotEmpty) {
          print('✅ Translation: "${response.translatedText.substring(0, response.translatedText.length.clamp(0, 50))}..."');
        }
      }

      setState(() {
        _sentenceTranslation = (response != null && response.error == null && response.translatedText.isNotEmpty) 
            ? response.translatedText 
            : null;
        _sentenceLoading = false;
      });
      
      // Debug: Final sentence translation result
      // print('🎯 Final sentence translation: ${_sentenceTranslation ?? "NULL"}');
    } catch (e) {
      print('❌ Sentence translation error: $e');
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Looking up "${widget.selectedText}"...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    // PolyBook-style error detection
    final isLanguagePackMissing = _error?.contains('Language pack not installed') == true ||
                                  _error?.contains('No translation found') == true ||
                                  _error?.contains('Dictionary not available') == true ||
                                  _error?.toLowerCase().contains('missing') == true ||
                                  _error?.toLowerCase().contains('not available') == true;
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(
            isLanguagePackMissing ? Icons.download_outlined : Icons.error_outline,
            color: isLanguagePackMissing 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            isLanguagePackMissing 
                ? '📦 Language Pack Required'
                : '❌ Translation Failed',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isLanguagePackMissing 
                ? 'Download ${widget.sourceLanguage}-${widget.targetLanguage} dictionary to translate "${widget.selectedText}"'
                : _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (isLanguagePackMissing) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openLanguagePackManager,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download Dictionary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will download ~2-3MB and enable offline translation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildSourceMeaningView() {
    final meaning = _sourceLookupResult!.meanings[_currentMeaningIndex];
    final isExpanded = _meaningExpanded;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // PolyBook-style content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Word Header Section
                _buildWordHeader(meaning),
                const SizedBox(height: 16),
                
                // Translation Section
                _buildTranslationSection(meaning, isExpanded),
                const SizedBox(height: 16),
                
                // Sentence Translation (if available)
                if (widget.context != null && widget.context!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSentenceSection(),
                ],
              ],
            ),
          ),
          
          // PolyBook-style Action Bar
          _buildActionBar(),
        ],
      ),
    );
  }
  
  Widget _buildWordHeader(CyclableMeaning meaning) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meaning.sourceWord,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meaning.languagePair.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (meaning.partOfSpeechTag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                meaning.partOfSpeechTag!.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTranslationSection(CyclableMeaning meaning, bool isExpanded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          '📝 Translation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Translation Item
        GestureDetector(
          onTap: _sourceLookupResult!.meanings.length > 1 ? _cycleToNextMeaning : _toggleExpansion,
          onLongPress: _toggleExpansion,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpanded ? meaning.expandedTranslation : meaning.displayTranslation,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (meaning.isPrimary) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRIMARY',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_sourceLookupResult!.meanings.length > 1)
                      Text(
                        'Tap (${_currentMeaningIndex + 1}/${_sourceLookupResult!.meanings.length})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      'Hold for details',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSentenceSection() {
    print('🏗️ Building sentence section - Loading: $_sentenceLoading, Translation: ${_sentenceTranslation != null ? "Available" : "None"}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          '📖 Sentence Translation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Sentence Content
        if (_sentenceLoading)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Translating sentence...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else if (_sentenceTranslation != null || _sentenceLoading)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_sentenceLoading)
                  Row(
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
                        'Translating sentence...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _sentenceTranslation ?? 'Sentence translation not available',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 12),
                _buildContextWithHighlight(),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildContextWithHighlight() {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
  
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onClose,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Add save to vocabulary functionality
                widget.onClose?.call();
              },
              icon: const Icon(Icons.bookmark_add, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Old methods removed - replaced by new sectioned components

  Widget _buildReverseLookupView() {
    final translation = _reverseLookupResult!.translations[_currentReverseIndex];
    final isExpanded = _reverseExpanded;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // PolyBook-style content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Word Header Section
                _buildReverseWordHeader(translation),
                const SizedBox(height: 16),
                
                // Translation Section
                _buildReverseTranslationSection(translation, isExpanded),
                const SizedBox(height: 16),
                
                // Sentence Translation (if available)
                if (widget.context != null && widget.context!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSentenceSection(),
                ],
              ],
            ),
          ),
          
          // PolyBook-style Action Bar
          _buildActionBar(),
        ],
      ),
    );
  }
  
  Widget _buildReverseWordHeader(CyclableReverseLookup translation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translation.targetWord,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.targetLanguage}→${widget.sourceLanguage}'.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (translation.partOfSpeechTag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                translation.partOfSpeechTag!.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildReverseTranslationSection(CyclableReverseLookup translation, bool isExpanded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          '🔄 Reverse Translation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Translation Item
        GestureDetector(
          onTap: _reverseLookupResult!.translations.length > 1 ? _cycleToNextMeaning : _toggleExpansion,
          onLongPress: _toggleExpansion,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpanded ? translation.expandedTranslation : translation.displayTranslation,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (translation.qualityIndicator.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          translation.qualityIndicator,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_reverseLookupResult!.translations.length > 1)
                      Flexible(
                        child: Text(
                          'Tap (${_currentReverseIndex + 1}/${_reverseLookupResult!.translations.length})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        'Hold for details',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // PolyBook-inspired position calculation
  Map<String, double> _calculatePopupPosition() {
    if (widget.position == null) {
      return {'left': 50, 'top': 100};
    }

    final screenSize = MediaQuery.of(context).size;
    final position = widget.position!;
    
    // PolyBook's simpler approach
    const popupWidth = 300.0;
    const popupHeight = 250.0;
    
    double x = position.dx - popupWidth / 2;
    double y = position.dy - popupHeight - 10; // Above the selection
    
    // Simple boundary checks (PolyBook pattern)
    if (x < 20) x = 20;
    if (x + popupWidth > screenSize.width - 20) {
      x = screenSize.width - popupWidth - 20;
    }
    if (y < 60) y = position.dy + 30; // Below if no space above
    
    return {'left': x, 'top': y};
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

    // PolyBook-style Modal with animations
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Positioned(
          left: position['left'],
          top: position['top'],
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
                shadowColor: Colors.black.withValues(alpha: 0.25),
                child: Container(
                  width: 280,
                  constraints: const BoxConstraints(
                    minHeight: 120,
                    maxHeight: 500,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
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