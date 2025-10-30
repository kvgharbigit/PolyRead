// Translation Popup - Simple, space-efficient design with cycling
// Shows word translation on top, sentence translation below, original sentence with hyperlinks

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dictionary_entry.dart';
import '../models/translation_request.dart';
import '../models/translation_response.dart' as response_model;

class TranslationPopup extends ConsumerStatefulWidget {
  final String selectedText;
  final String sourceLanguage;
  final String targetLanguage;
  final Offset position;
  final VoidCallback onClose;
  final dynamic translationService;
  final String? context;

  const TranslationPopup({
    super.key,
    required this.selectedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.position,
    required this.onClose,
    this.translationService,
    this.context,
  });

  @override
  ConsumerState<TranslationPopup> createState() => _TranslationPopupState();
}

class _TranslationPopupState extends ConsumerState<TranslationPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  response_model.TranslationResponse? _currentResponse;
  bool _isLoading = true;
  String? _error;
  int _currentResultIndex = 0;
  int _currentSynonymIndex = 0;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
    _performTranslation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _performTranslation() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (widget.translationService != null) {
        final response = await widget.translationService!.translateText(
          text: widget.selectedText,
          sourceLanguage: widget.sourceLanguage,
          targetLanguage: widget.targetLanguage,
        );
        
        if (!mounted) return;
        setState(() {
          _currentResponse = response;
          _isLoading = false;
          if (response.error != null) {
            _error = response.error;
          }
        });
      } else {
        // Fallback mock response
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        final mockResponse = _createMockResponse();
        setState(() {
          _currentResponse = mockResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  response_model.TranslationResponse _createMockResponse() {
    final mockDictEntry = DictionaryEntry(
      writtenRep: widget.selectedText.toLowerCase(),
      sourceLanguage: widget.sourceLanguage,
      targetLanguage: widget.targetLanguage,
      sense: 'Example definition for "${widget.selectedText}"',
      transList: 'Example definition for "${widget.selectedText}"',
      pos: 'noun',
      pronunciation: 'pronunciation',
      examples: 'This is an example sentence.',
      sourceDictionary: 'Oxford Dictionary',
      createdAt: DateTime.now(),
    );

    return response_model.TranslationResponse.fromDictionary(
      request: TranslationRequest(
        text: widget.selectedText,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        timestamp: DateTime.now(),
      ),
      dictionaryResult: DictionaryLookupResult(
        query: widget.selectedText,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        entries: [mockDictEntry],
        latencyMs: 5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final popupWidth = screenSize.width * 0.9;
    final maxWidth = popupWidth.clamp(280.0, 400.0);
    final maxHeight = screenSize.height * 0.6;
    
    final position = _calculateOptimalPosition(
      screenSize: screenSize,
      popupWidth: maxWidth,
      maxHeight: maxHeight,
    );

    return Stack(
      children: [
        // Backdrop for tap-to-dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        
        // Popup
        Positioned(
          left: position.dx,
          top: position.dy,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: maxWidth,
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Close button
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          
                          // Content
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildContent(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Translating...'),
        ],
      );
    }

    if (_error != null) {
      return Text('Error: $_error');
    }

    if (_currentResponse == null) {
      return const Text('No translation available');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Word translation with cycling
        _buildWordTranslation(),
        
        // Sentence translation (if context available)
        if (widget.context != null && widget.context!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSentenceTranslation(),
        ],
      ],
    );
  }

  Widget _buildWordTranslation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Original word and arrow
        Row(
          children: [
            Flexible(
              child: Text(
                widget.selectedText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              ' → ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Part of speech emoji cycling (if dictionary)
            if (_currentResponse!.dictionaryResult?.entries.isNotEmpty == true)
              GestureDetector(
                onTap: _nextResult,
                child: Text(
                  '${_getPartOfSpeechEmoji(_getCurrentPartOfSpeech())}${_getDictionaryCounter()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Translation with synonym cycling
        GestureDetector(
          onTap: _cycleSynonym,
          child: Text(
            '${_getCurrentTranslation()}${_getSynonymCounter()}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceTranslation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Translated sentence
        FutureBuilder<String?>(
          future: _getSentenceTranslation(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Translating...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              );
            }
            
            if (snapshot.hasData && snapshot.data != null) {
              return Text(
                snapshot.data!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              );
            }
            
            return const SizedBox.shrink();
          },
        ),
        
        const SizedBox(height: 8),
        
        // Original sentence with clickable words
        _buildClickableOriginalSentence(),
      ],
    );
  }

  Widget _buildClickableOriginalSentence() {
    if (widget.context == null) return const SizedBox.shrink();
    
    final words = widget.context!.split(' ');
    final spans = <InlineSpan>[];
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      final isSelected = cleanWord.toLowerCase() == widget.selectedText.toLowerCase();
      
      spans.add(
        TextSpan(
          text: word,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            decoration: isSelected ? null : TextDecoration.underline,
            decorationColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          recognizer: isSelected ? null : (TapGestureRecognizer()
            ..onTap = () {
              if (cleanWord.isNotEmpty) {
                print('Tapped word: $cleanWord');
                // Could trigger new translation for this word
              }
            }),
        ),
      );
      
      if (i < words.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  // Cycling methods
  void _nextResult() {
    print('🔄 TranslationPopup: _nextResult() called');
    if (!mounted) {
      print('🔄 TranslationPopup: Widget not mounted, skipping _nextResult');
      return;
    }
    
    final entries = _currentResponse?.dictionaryResult?.entries;
    print('🔄 TranslationPopup: Current entries count: ${entries?.length ?? 0}');
    print('🔄 TranslationPopup: Current result index: $_currentResultIndex');
    
    if (entries != null && entries.length > 1 && _currentResultIndex < entries.length - 1) {
      final oldIndex = _currentResultIndex;
      final oldSynonymIndex = _currentSynonymIndex;
      
      setState(() {
        _currentResultIndex++;
        _currentSynonymIndex = 0;
      });
      
      print('🔄 TranslationPopup: Result index changed from $oldIndex to $_currentResultIndex');
      print('🔄 TranslationPopup: Synonym index reset from $oldSynonymIndex to $_currentSynonymIndex');
      print('🔄 TranslationPopup: New current translation: ${_getCurrentTranslation()}');
    } else {
      print('🔄 TranslationPopup: Cannot cycle results - entries: ${entries?.length}, currentIndex: $_currentResultIndex');
    }
  }
  
  void _cycleSynonym() {
    print('🔄 TranslationPopup: _cycleSynonym() called');
    if (!mounted) {
      print('🔄 TranslationPopup: Widget not mounted, skipping _cycleSynonym');
      return;
    }
    
    final synonyms = _getCurrentSynonyms();
    print('🔄 TranslationPopup: Current synonyms: $synonyms');
    print('🔄 TranslationPopup: Current synonym index: $_currentSynonymIndex');
    
    if (synonyms.length > 1) {
      final oldIndex = _currentSynonymIndex;
      final oldTranslation = _getCurrentTranslation();
      
      setState(() {
        _currentSynonymIndex = (_currentSynonymIndex + 1) % synonyms.length;
      });
      
      final newTranslation = _getCurrentTranslation();
      print('🔄 TranslationPopup: Synonym index changed from $oldIndex to $_currentSynonymIndex');
      print('🔄 TranslationPopup: Translation changed from "$oldTranslation" to "$newTranslation"');
    } else {
      print('🔄 TranslationPopup: Cannot cycle synonyms - only ${synonyms.length} available');
    }
  }

  // Translation helpers
  String _getCurrentTranslation() {
    print('📝 TranslationPopup: _getCurrentTranslation() called');
    print('📝 TranslationPopup: Current result index: $_currentResultIndex, synonym index: $_currentSynonymIndex');
    
    if (_currentResponse!.dictionaryResult?.entries.isNotEmpty == true) {
      print('📝 TranslationPopup: Using dictionary result');
      final synonyms = _getCurrentSynonyms();
      print('📝 TranslationPopup: Available synonyms: $synonyms');
      
      if (synonyms.isNotEmpty && _currentSynonymIndex < synonyms.length) {
        final selectedSynonym = synonyms[_currentSynonymIndex];
        print('📝 TranslationPopup: Selected synonym at index $_currentSynonymIndex: "$selectedSynonym"');
        return selectedSynonym;
      }
      
      final entry = _currentResponse!.dictionaryResult!.entries[_currentResultIndex];
      final extractedTranslation = _extractTranslationFromDefinition(entry.transList);
      print('📝 TranslationPopup: Extracted translation from definition: "$extractedTranslation"');
      return extractedTranslation;
    }
    
    final mlKitTranslation = _currentResponse!.translatedText;
    print('📝 TranslationPopup: Using ML Kit translation: "$mlKitTranslation"');
    return mlKitTranslation;
  }
  
  List<String> _getCurrentSynonyms() {
    print('📝 TranslationPopup: _getCurrentSynonyms() called for result index $_currentResultIndex');
    
    if (_currentResponse!.dictionaryResult?.entries.isNotEmpty == true) {
      final entry = _currentResponse!.dictionaryResult!.entries[_currentResultIndex];
      print('📝 TranslationPopup: Dictionary entry - transList: "${entry.transList}"');
      
      final synonyms = <String>[];
      
      // Parse translations from modern transList field (pipe-separated)
      final translations = entry.transList.split(' | ')
          .where((t) => t.trim().isNotEmpty)
          .map((t) => t.trim())
          .toList();
      
      final primaryTranslation = translations.isNotEmpty ? translations.first : entry.sense ?? '';
      synonyms.add(primaryTranslation);
      print('📝 TranslationPopup: Added primary translation: "$primaryTranslation"');
      
      // Add additional translations as synonyms
      if (translations.length > 1) {
        final additionalTranslations = translations.skip(1).toList();
        synonyms.addAll(additionalTranslations);
        print('📝 TranslationPopup: Added ${additionalTranslations.length} additional synonyms: $additionalTranslations');
      }
      
      // Remove duplicates and empty entries
      final cleanedSynonyms = synonyms.where((s) => s.trim().isNotEmpty).toSet().toList();
      print('📝 TranslationPopup: Final cleaned synonyms: $cleanedSynonyms');
      return cleanedSynonyms;
    }
    
    final fallbackSynonyms = [_currentResponse!.translatedText];
    print('📝 TranslationPopup: Using fallback synonyms: $fallbackSynonyms');
    return fallbackSynonyms;
  }
  
  String _getCurrentPartOfSpeech() {
    if (_currentResponse!.dictionaryResult?.entries.isNotEmpty == true) {
      final entry = _currentResponse!.dictionaryResult!.entries[_currentResultIndex];
      return entry.pos ?? 'general';
    }
    return 'general';
  }
  
  String _getDictionaryCounter() {
    if (_currentResponse!.dictionaryResult?.entries.isNotEmpty == true) {
      final total = _currentResponse!.dictionaryResult!.entries.length;
      final counter = total > 1 ? '(${_currentResultIndex + 1}/$total)' : '';
      print('📊 TranslationPopup: Dictionary counter: "$counter" (index: $_currentResultIndex, total: $total)');
      return counter;
    }
    print('📊 TranslationPopup: No dictionary counter (no entries)');
    return '';
  }
  
  String _getSynonymCounter() {
    final count = _getCurrentSynonyms().length;
    final counter = count > 1 ? '(${_currentSynonymIndex + 1}/$count)' : '';
    print('📊 TranslationPopup: Synonym counter: "$counter" (index: $_currentSynonymIndex, count: $count)');
    return counter;
  }

  String _extractTranslationFromDefinition(String definition) {
    final parts = definition.split(RegExp(r'[;,\.:]'));
    if (parts.isNotEmpty) {
      final translation = parts.first.trim();
      if (translation.length < 50 && !translation.toLowerCase().startsWith('to ')) {
        return translation;
      }
    }
    
    final sentences = definition.split('.');
    if (sentences.isNotEmpty) {
      return sentences.first.trim();
    }
    
    return definition;
  }

  String _getPartOfSpeechEmoji(String partOfSpeech) {
    // Use PolyBook's exact emoji mapping
    const emojiMap = {
      'noun': '📦',
      'verb': '⚡', 
      'adjective': '🎨',
      'adverb': '🏃',
      'pronoun': '👤',
      'preposition': '🌉',
      'conjunction': '🔗',
      'interjection': '❗',
      // Handle abbreviations too
      'n': '📦',
      'v': '⚡',
      'adj': '🎨', 
      'adv': '🏃',
      'prep': '🌉',
      'conj': '🔗',
      'int': '❗',
    };
    return emojiMap[partOfSpeech.toLowerCase()] ?? '📝';
  }

  Future<String?> _getSentenceTranslation() async {
    if (widget.translationService == null || widget.context == null || widget.context!.isEmpty) {
      return null;
    }

    try {
      final sentence = _extractSentenceFromContext();
      if (sentence.isEmpty) return null;

      final response = await widget.translationService!.translateText(
        text: sentence,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );

      return (response.error == null && response.translatedText.isNotEmpty) ? response.translatedText : null;
    } catch (e) {
      return null;
    }
  }

  String _extractSentenceFromContext() {
    if (widget.context == null) return '';
    
    final context = widget.context!;
    final selectedText = widget.selectedText;
    final selectedIndex = context.indexOf(selectedText);
    
    if (selectedIndex == -1) return context;
    
    int sentenceStart = 0;
    int sentenceEnd = context.length;
    
    for (int i = selectedIndex; i >= 0; i--) {
      if (i < context.length - 1 && RegExp(r'[.!?]\s').hasMatch(context.substring(i, i + 2))) {
        sentenceStart = i + 2;
        break;
      }
    }
    
    for (int i = selectedIndex; i < context.length - 1; i++) {
      if (RegExp(r'[.!?]\s').hasMatch(context.substring(i, i + 2))) {
        sentenceEnd = i + 1;
        break;
      }
    }
    
    return context.substring(sentenceStart, sentenceEnd).trim();
  }

  Offset _calculateOptimalPosition({
    required Size screenSize,
    required double popupWidth,
    required double maxHeight,
  }) {
    const padding = 16.0;
    double left = widget.position.dx;
    double top = widget.position.dy;

    if (left + popupWidth + padding > screenSize.width) {
      left = screenSize.width - popupWidth - padding;
    }
    if (left < padding) {
      left = padding;
    }

    if (top + maxHeight + padding > screenSize.height) {
      top = widget.position.dy - maxHeight - 20;
      if (top < padding) {
        top = (screenSize.height - maxHeight) / 2;
      }
    }

    return Offset(left, top);
  }
}