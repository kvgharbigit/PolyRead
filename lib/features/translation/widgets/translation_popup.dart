// Translation Popup - Displays translation results with provider cycling
// Shows dictionary entries first, then ML Kit/Google Translate results

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/translation_service.dart';
import '../models/dictionary_entry.dart';

class TranslationPopup extends ConsumerStatefulWidget {
  final String selectedText;
  final String sourceLanguage;
  final String targetLanguage;
  final Offset position;
  final VoidCallback onClose;
  final Function(String word)? onAddToVocabulary;

  const TranslationPopup({
    super.key,
    required this.selectedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.position,
    required this.onClose,
    this.onAddToVocabulary,
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
  bool _isLoading = true;
  String? _error;
  int _currentResultIndex = 0;

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

      // Get translation service (would be provided via Riverpod in real app)
      // For now, simulating the service call
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Simulate translation response
      setState(() {
        _currentResponse = _createMockResponse();
        _isLoading = false;
      });
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
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
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
                  width: 320,
                  constraints: const BoxConstraints(maxHeight: 400),
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
            _buildProviderIndicator(),
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

  Widget _buildProviderIndicator() {
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

    return Tooltip(
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
            if (_currentResponse!.dictionaryEntries != null)
              _buildDictionaryResults()
            else if (_currentResponse!.translatedText != null)
              _buildTranslationResult(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.menu_book,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Dictionary',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (entries.length > 1) ...[
              const Spacer(),
              Text(
                '${_currentResultIndex + 1} of ${entries.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildDictionaryEntry(entries[_currentResultIndex]),
        if (entries.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _currentResultIndex > 0 ? _previousResult : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              TextButton.icon(
                onPressed: _currentResultIndex < entries.length - 1 ? _nextResult : null,
                label: const Text('Next'),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

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

  Widget _buildTranslationResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _currentResponse!.source == TranslationSource.mlKit
                  ? Icons.offline_bolt
                  : Icons.cloud,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              _currentResponse!.source == TranslationSource.mlKit
                  ? 'ML Kit Translation'
                  : 'Google Translate',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _currentResponse!.translatedText!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
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
}

// Import the missing classes for compilation
class TranslationRequest {
  final String text;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;
  
  const TranslationRequest({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });
}

class DictionaryLookupResult {
  final String query;
  final String language;
  final List<DictionaryEntry> entries;
  final int latencyMs;
  
  const DictionaryLookupResult({
    required this.query,
    required this.language,
    required this.entries,
    required this.latencyMs,
  });
}