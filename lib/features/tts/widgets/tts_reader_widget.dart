// TTS Reader Widget
// Integrates text-to-speech with highlighting in the reading interface

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/tts/services/tts_service.dart';
import 'package:polyread/features/reader/widgets/enhanced_interactive_text.dart';

class TtsReaderWidget extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final Function(String, Offset, TextSelection, WordContext)? onWordTap;
  final Function(String, Offset, TextSelection)? onSentenceTap;
  final bool showTtsControls;
  final bool autoScroll;

  const TtsReaderWidget({
    super.key,
    required this.text,
    this.style,
    this.onWordTap,
    this.onSentenceTap,
    this.showTtsControls = true,
    this.autoScroll = true,
  });

  @override
  ConsumerState<TtsReaderWidget> createState() => _TtsReaderWidgetState();
}

class _TtsReaderWidgetState extends ConsumerState<TtsReaderWidget> {
  late TtsService _ttsService;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _textKey = GlobalKey();
  
  // Highlighting state
  int _highlightedWordIndex = -1;
  List<String> _words = [];
  List<TextSpan> _textSpans = [];
  
  @override
  void initState() {
    super.initState();
    _initializeTts();
    _buildTextSpans();
  }

  @override
  void didUpdateWidget(TtsReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _buildTextSpans();
      if (_ttsService.isPlaying) {
        _ttsService.stop();
      }
    }
  }

  void _initializeTts() {
    _ttsService = TtsService();
    _ttsService.initialize();
    
    // Set up TTS callbacks
    _ttsService.onWordHighlight = (wordIndex, word) {
      setState(() {
        _highlightedWordIndex = wordIndex;
      });
      
      if (widget.autoScroll) {
        _scrollToHighlightedWord(wordIndex);
      }
    };
    
    _ttsService.onSpeechComplete = () {
      setState(() {
        _highlightedWordIndex = -1;
      });
    };
    
    _ttsService.addListener(() {
      setState(() {}); // Rebuild to show TTS state changes
    });
  }

  void _buildTextSpans() {
    _words = widget.text.split(RegExp(r'\s+'));
    _textSpans = [];
    
    final words = widget.text.split(RegExp(r'(\s+)'));
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final isWord = word.trim().isNotEmpty && !RegExp(r'^\s+$').hasMatch(word);
      final wordIndex = isWord ? _getWordIndex(i, words) : -1;
      final isHighlighted = wordIndex == _highlightedWordIndex;
      
      _textSpans.add(
        TextSpan(
          text: word,
          style: (widget.style ?? const TextStyle()).copyWith(
            backgroundColor: isHighlighted 
                ? Colors.yellow.withOpacity(0.7)
                : null,
            fontWeight: isHighlighted ? FontWeight.bold : null,
          ),
          recognizer: isWord ? (TapGestureRecognizer()
            ..onTap = () => _handleWordTap(wordIndex, word))
            : null,
        ),
      );
    }
  }

  int _getWordIndex(int spanIndex, List<String> allSpans) {
    int wordCount = 0;
    for (int i = 0; i < spanIndex; i++) {
      if (allSpans[i].trim().isNotEmpty && !RegExp(r'^\s+$').hasMatch(allSpans[i])) {
        wordCount++;
      }
    }
    return wordCount;
  }

  void _handleWordTap(int wordIndex, String word) {
    if (_ttsService.isPlaying) {
      // Jump to tapped word during playback
      _ttsService.jumpToWord(wordIndex);
    } else {
      // Start TTS from tapped word
      final remainingWords = _words.skip(wordIndex).toList();
      final remainingText = remainingWords.join(' ');
      _ttsService.speak(remainingText);
    }
  }

  void _scrollToHighlightedWord(int wordIndex) {
    // Calculate approximate position of highlighted word
    if (_scrollController.hasClients && _words.isNotEmpty) {
      final progress = wordIndex / _words.length;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetScroll = maxScroll * progress;
      
      _scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showTtsControls) _buildTtsControls(),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rich text with TTS highlighting
                SelectableText.rich(
                  TextSpan(children: _textSpans),
                  key: _textKey,
                  style: widget.style,
                  onSelectionChanged: (selection, cause) {
                    if (selection != null && selection.textInside(widget.text).isNotEmpty) {
                      final selectedText = selection.textInside(widget.text);
                      
                      // Handle text selection for translation
                      if (selectedText.contains(' ')) {
                        // Sentence selection
                        widget.onSentenceTap?.call(
                          selectedText,
                          Offset.zero,
                          selection,
                        );
                      } else {
                        // Word selection - create mock context
                        final context = WordContext(
                          sentence: selectedText,
                          surroundingWords: [selectedText],
                          wordPosition: 0,
                          totalWords: 1,
                        );
                        
                        widget.onWordTap?.call(
                          selectedText,
                          Offset.zero,
                          selection,
                          context,
                        );
                      }
                    }
                  },
                ),
                
                // TTS progress indicator
                if (_ttsService.isPlaying) ...[
                  const SizedBox(height: 16),
                  _buildProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTtsControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // Main control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Play/Pause button
              IconButton(
                onPressed: () {
                  if (_ttsService.isPlaying) {
                    _ttsService.pause();
                  } else if (_ttsService.isPaused) {
                    _ttsService.resume();
                  } else {
                    _ttsService.speak(widget.text);
                  }
                },
                icon: Icon(
                  _ttsService.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                iconSize: 32,
              ),
              
              // Stop button
              IconButton(
                onPressed: _ttsService.isPlaying || _ttsService.isPaused
                    ? () => _ttsService.stop()
                    : null,
                icon: const Icon(Icons.stop),
                iconSize: 32,
              ),
              
              // Settings button
              IconButton(
                onPressed: () => _showTtsSettings(),
                icon: const Icon(Icons.tune),
                iconSize: 28,
              ),
            ],
          ),
          
          // Speed and volume controls
          const SizedBox(height: 8),
          Row(
            children: [
              // Speed control
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _ttsService.speechRate,
                        onChanged: (value) => _ttsService.setSpeechRate(value),
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        label: '${(_ttsService.speechRate * 100).round()}%',
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Volume control
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _ttsService.volume > 0.5
                          ? Icons.volume_up
                          : _ttsService.volume > 0
                              ? Icons.volume_down
                              : Icons.volume_off,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _ttsService.volume,
                        onChanged: (value) => _ttsService.setVolume(value),
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(_ttsService.volume * 100).round()}%',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: _ttsService.progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Current word and progress text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Speaking: "${_ttsService.getCurrentWordText()}"',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${(_ttsService.progress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTtsSettings() {
    showDialog(
      context: context,
      builder: (context) => _TtsSettingsDialog(ttsService: _ttsService),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ttsService.removeListener(() {});
    super.dispose();
  }
}

class _TtsSettingsDialog extends StatefulWidget {
  final TtsService ttsService;

  const _TtsSettingsDialog({required this.ttsService});

  @override
  State<_TtsSettingsDialog> createState() => _TtsSettingsDialogState();
}

class _TtsSettingsDialogState extends State<_TtsSettingsDialog> {
  List<String> _languages = [];
  List<Map<String, String>> _voices = [];
  String? _selectedLanguage;
  Map<String, String>? _selectedVoice;

  @override
  void initState() {
    super.initState();
    _loadTtsOptions();
  }

  Future<void> _loadTtsOptions() async {
    final languages = await widget.ttsService.getLanguages();
    final voices = await widget.ttsService.getVoices();
    
    setState(() {
      _languages = languages.cast<String>();
      _voices = voices.cast<Map<String, String>>();
      _selectedLanguage = widget.ttsService.language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('TTS Settings'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Language selection
            if (_languages.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                ),
                items: _languages.map((lang) {
                  return DropdownMenuItem(
                    value: lang,
                    child: Text(lang),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedLanguage = value);
                    widget.ttsService.setLanguage(value);
                  }
                },
              ),
            
            const SizedBox(height: 16),
            
            // Voice selection
            if (_voices.isNotEmpty)
              DropdownButtonFormField<Map<String, String>>(
                value: _selectedVoice,
                decoration: const InputDecoration(
                  labelText: 'Voice',
                  border: OutlineInputBorder(),
                ),
                items: _voices.map((voice) {
                  return DropdownMenuItem(
                    value: voice,
                    child: Text(voice['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedVoice = value);
                    widget.ttsService.setVoice(value);
                  }
                },
              ),
            
            const SizedBox(height: 16),
            
            // Pitch control
            ListTile(
              title: const Text('Pitch'),
              subtitle: Slider(
                value: widget.ttsService.pitch,
                onChanged: (value) {
                  widget.ttsService.setPitch(value);
                  setState(() {});
                },
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: widget.ttsService.pitch.toStringAsFixed(1),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}