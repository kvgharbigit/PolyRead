// Translation Popup - Displays translation results with provider cycling
// Shows dictionary entries first, then ML Kit/Google Translate results

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/translation_service.dart';
import '../models/dictionary_entry.dart';
import '../models/translation_request.dart';

class TranslationPopup extends ConsumerStatefulWidget {
  final String selectedText;
  final String sourceLanguage;
  final String targetLanguage;
  final Offset position;
  final VoidCallback onClose;
  final Function(String word)? onAddToVocabulary;
  final dynamic translationService; // Accept both TranslationService and DriftTranslationService
  final String? context; // Surrounding text for context display
  final TextSelection? textSelection; // Original text selection

  const TranslationPopup({
    super.key,
    required this.selectedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.position,
    required this.onClose,
    this.onAddToVocabulary,
    this.translationService,
    this.context,
    this.textSelection,
  });

  @override
  ConsumerState<TranslationPopup> createState() => _TranslationPopupState();
}

class _TranslationPopupState extends ConsumerState<TranslationPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  TranslationResponse? _currentResponse;
  List<TranslationResponse> _allResponses = [];
  bool _isLoading = true;
  String? _error;
  int _currentResultIndex = 0;
  int _currentProviderIndex = 0;

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
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (widget.translationService != null) {
        // Use real translation service
        final response = await widget.translationService!.translateText(
          text: widget.selectedText,
          sourceLanguage: widget.sourceLanguage,
          targetLanguage: widget.targetLanguage,
        );
        
        setState(() {
          _currentResponse = response;
          _allResponses = [response];
          _isLoading = false;
        });
      } else {
        // Fallback to mock response for development
        await Future.delayed(const Duration(milliseconds: 500));
        final mockResponse = _createMockResponse();
        setState(() {
          _currentResponse = mockResponse;
          _allResponses = [mockResponse];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  TranslationResponse _createMockResponse() {
    // Mock dictionary entry for demonstration
    final mockDictEntry = DictionaryEntry(
      word: widget.selectedText.toLowerCase(),
      language: widget.sourceLanguage,
      definition: 'Example definition for "${widget.selectedText}"',
      pronunciation: 'pronunciation',
      partOfSpeech: 'noun',
      exampleSentence: 'This is an example sentence.',
      sourceDictionary: 'Oxford Dictionary',
      createdAt: DateTime.now(),
    );

    return TranslationResponse.fromDictionary(
      request: TranslationRequest(
        text: widget.selectedText,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        timestamp: DateTime.now(),
      ),
      dictionaryResult: DictionaryLookupResult(
        query: widget.selectedText,
        language: widget.sourceLanguage,
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
    
    // Calculate optimal position to keep popup on screen
    final position = _calculateOptimalPosition(
      screenSize: screenSize,
      popupWidth: maxWidth,
      maxHeight: maxHeight,
    );

    return Positioned(
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
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                  ),
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
                      _buildHeader(),
                      if (widget.context != null) _buildContextDisplay(),
                      if (_isLoading) _buildLoadingContent(),
                      if (_error != null) _buildErrorContent(),
                      if (_currentResponse != null) _buildTranslationContent(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Offset _calculateOptimalPosition({
    required Size screenSize,
    required double popupWidth,
    required double maxHeight,
  }) {
    const padding = 16.0;
    double left = widget.position.dx;
    double top = widget.position.dy;

    // Adjust horizontal position
    if (left + popupWidth + padding > screenSize.width) {
      left = screenSize.width - popupWidth - padding;
    }
    if (left < padding) {
      left = padding;
    }

    // Adjust vertical position
    if (top + maxHeight + padding > screenSize.height) {
      // Try positioning above the tap point
      top = widget.position.dy - maxHeight - 20;
      if (top < padding) {
        // If still doesn't fit, position at center
        top = (screenSize.height - maxHeight) / 2;
      }
    }

    return Offset(left, top);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '${widget.sourceLanguage.toUpperCase()} → ${widget.targetLanguage.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (_currentResponse != null && !_isLoading)
            _buildProviderCycler(),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCycler() {
    if (_currentResponse == null) return const SizedBox.shrink();

    IconData icon;
    String tooltip;
    Color color;

    switch (_currentResponse!.source) {
      case TranslationSource.dictionary:
        icon = Icons.menu_book;
        tooltip = 'Dictionary';
        color = Colors.blue;
        break;
      case TranslationSource.mlKit:
        icon = Icons.offline_bolt;
        tooltip = 'ML Kit (Offline)';
        color = Colors.green;
        break;
      case TranslationSource.server:
        icon = Icons.cloud;
        tooltip = 'Google Translate';
        color = Colors.orange;
        break;
      default:
        icon = Icons.help;
        tooltip = 'Unknown';
        color = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Try alternative providers button
        if (widget.translationService != null)
          IconButton(
            onPressed: _tryAlternativeProviders,
            icon: const Icon(Icons.refresh, size: 16),
            tooltip: 'Try other providers',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        
        // Current provider indicator
        Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  '${_currentResponse!.latencyMs}ms',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContextDisplay() {
    if (widget.context == null || widget.context!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Context',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: _buildContextTextSpan(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  TextSpan _buildContextTextSpan() {
    final contextText = widget.context!;
    final selectedText = widget.selectedText;
    final selection = widget.textSelection;
    final theme = Theme.of(context);

    if (selection == null) {
      return TextSpan(
        text: contextText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Find the selected text in context and highlight it
    final selectedStart = contextText.indexOf(selectedText);
    if (selectedStart == -1) {
      return TextSpan(
        text: contextText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final selectedEnd = selectedStart + selectedText.length;
    final beforeText = contextText.substring(0, selectedStart);
    final afterText = contextText.substring(selectedEnd);

    return TextSpan(
      children: [
        if (beforeText.isNotEmpty)
          TextSpan(
            text: beforeText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        TextSpan(
          text: selectedText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.5),
          ),
        ),
        if (afterText.isNotEmpty)
          TextSpan(
            text: afterText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingContent() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Translating...'),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            'Translation failed',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _error ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _performTranslation,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationContent() {
    if (_currentResponse == null) return const SizedBox.shrink();

    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dictionary definitions on top with cycling
            if (_currentResponse!.dictionaryEntries != null)
              _buildDictionaryResults(),
            
            // Sentence translation below (always try to get sentence translation)
            _buildSentenceTranslation(),
            
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDictionaryResults() {
    final entries = _currentResponse!.dictionaryEntries!;
    if (entries.isEmpty) return const SizedBox.shrink();

    final currentEntry = entries[_currentResultIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dictionary header with word pair
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word pair (source → target)
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: widget.selectedText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    TextSpan(
                      text: ' → ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                      ),
                    ),
                    TextSpan(
                      text: currentEntry.definition.split('.').first, // First sentence as translation
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Part of speech with cycling counter
              if (currentEntry.partOfSpeech != null)
                GestureDetector(
                  onTap: entries.length > 1 ? _nextResult : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entries.length > 1 
                          ? '${_getPartOfSpeechEmoji(currentEntry.partOfSpeech!)} ${currentEntry.partOfSpeech} (${_currentResultIndex + 1}/${entries.length})'
                          : '${_getPartOfSpeechEmoji(currentEntry.partOfSpeech!)} ${currentEntry.partOfSpeech}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Full definition
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentEntry.definition,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (currentEntry.exampleSentence != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    currentEntry.exampleSentence!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
                if (currentEntry.pronunciation != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentEntry.pronunciation!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Cycling controls
        if (entries.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _currentResultIndex > 0 ? _previousResult : null,
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('Previous'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: _currentResultIndex < entries.length - 1 ? _nextResult : null,
                label: const Text('Next'),
                icon: const Icon(Icons.chevron_right, size: 16),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _getPartOfSpeechEmoji(String partOfSpeech) {
    const emojiMap = {
      'noun': '🏷️',
      'verb': '⚡',
      'adjective': '🎨',
      'adverb': '🔄',
      'pronoun': '👤',
      'preposition': '📍',
      'conjunction': '🔗',
      'interjection': '❗',
    };
    return emojiMap[partOfSpeech.toLowerCase()] ?? '📝';
  }

  // TODO: Implement when needed for detailed dictionary view
  /*
  Widget _buildDictionaryEntry(DictionaryEntry entry) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.partOfSpeech != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.partOfSpeech!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              entry.definition,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (entry.exampleSentence != null) ...[
              const SizedBox(height: 8),
              Text(
                entry.exampleSentence!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            if (entry.pronunciation != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.volume_up,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.pronunciation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Source: ${entry.sourceDictionary}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
  */

  Widget _buildSentenceTranslation() {
    // Always try to get sentence translation for context
    return FutureBuilder<String?>(
      future: _getSentenceTranslation(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final sentenceTranslation = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // Section divider
            Divider(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            
            const SizedBox(height: 8),
            
            // Sentence context header
            Text(
              'Sentence Context',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Translated sentence (prominent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                ),
              ),
              child: Text(
                sentenceTranslation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Original sentence context (if available)
            if (widget.context != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: RichText(
                  text: _buildContextTextSpan(),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<String?> _getSentenceTranslation() async {
    if (widget.translationService == null || widget.context == null) {
      return null;
    }

    try {
      // Extract sentence containing the selected word
      final sentence = _extractSentenceFromContext();
      if (sentence.isEmpty) return null;

      final response = await widget.translationService!.translateText(
        text: sentence,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );

      return response.success ? response.translatedText : null;
    } catch (e) {
      return null;
    }
  }

  String _extractSentenceFromContext() {
    if (widget.context == null) return '';
    
    final context = widget.context!;
    final selectedText = widget.selectedText;
    
    // Find the selected text position
    final selectedIndex = context.indexOf(selectedText);
    if (selectedIndex == -1) return context;
    
    // Find sentence boundaries around the selected text
    int sentenceStart = 0;
    int sentenceEnd = context.length;
    
    // Look backwards for sentence start
    for (int i = selectedIndex; i >= 0; i--) {
      if (i < context.length - 1 && RegExp(r'[.!?]\s').hasMatch(context.substring(i, i + 2))) {
        sentenceStart = i + 2;
        break;
      }
    }
    
    // Look forwards for sentence end
    for (int i = selectedIndex; i < context.length - 1; i++) {
      if (RegExp(r'[.!?]\s').hasMatch(context.substring(i, i + 2))) {
        sentenceEnd = i + 1;
        break;
      }
    }
    
    return context.substring(sentenceStart, sentenceEnd).trim();
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.onAddToVocabulary != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => widget.onAddToVocabulary!(widget.selectedText),
              icon: const Icon(Icons.bookmark_add),
              label: const Text('Add to Vocabulary'),
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _copyToClipboard,
          tooltip: 'Copy',
          icon: const Icon(Icons.copy),
        ),
        IconButton(
          onPressed: _shareTranslation,
          tooltip: 'Share',
          icon: const Icon(Icons.share),
        ),
      ],
    );
  }

  void _previousResult() {
    if (_currentResultIndex > 0) {
      setState(() {
        _currentResultIndex--;
      });
    }
  }

  void _nextResult() {
    final entries = _currentResponse?.dictionaryEntries;
    if (entries != null && _currentResultIndex < entries.length - 1) {
      setState(() {
        _currentResultIndex++;
      });
    }
  }

  void _copyToClipboard() {
    // Implementation for copying translation to clipboard
  }

  void _shareTranslation() {
    // Implementation for sharing translation
  }
  
  Future<void> _tryAlternativeProviders() async {
    if (widget.translationService == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // For now, just re-translate with the service
      // In a full implementation, this would try different providers
      // or force using a different provider than the current one
      final response = await widget.translationService!.translateText(
        text: widget.selectedText,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        useCache: false, // Force fresh translation
      );
      
      setState(() {
        _currentResponse = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}

