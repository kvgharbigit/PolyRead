// TTS Service with Text Highlighting
// Provides text-to-speech functionality with synchronized highlighting

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  late FlutterTts _flutterTts;
  TtsState _ttsState = TtsState.stopped;
  
  // Text and highlighting
  String? _currentText;
  List<String> _words = [];
  int _currentWordIndex = -1;
  double _progress = 0.0;
  
  // Configuration
  double _volume = 1.0;
  double _pitch = 1.0;
  double _speechRate = 0.5;
  String _language = 'en-US';
  String? _engine;
  String? _voice;
  
  // Callbacks
  Function(int wordIndex, String word)? onWordHighlight;
  Function()? onSpeechComplete;
  Function()? onSpeechStart;
  Function(double progress)? onProgressUpdate;
  
  // Timers and state management
  Timer? _progressTimer;
  Timer? _jumpToWordTimer;
  DateTime? _speechStartTime;
  int _estimatedDurationMs = 0;
  bool _isDisposed = false;

  // Getters
  TtsState get ttsState => _ttsState;
  String? get currentText => _currentText;
  int get currentWordIndex => _currentWordIndex;
  double get progress => _progress;
  double get volume => _volume;
  double get pitch => _pitch;
  double get speechRate => _speechRate;
  String get language => _language;
  List<String> get words => _words;

  Future<void> initialize() async {
    _flutterTts = FlutterTts();
    
    // Set up TTS callbacks
    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      _speechStartTime = DateTime.now();
      _startProgressTracking();
      onSpeechStart?.call();
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      _currentWordIndex = -1;
      _progress = 1.0;
      _stopProgressTracking();
      onSpeechComplete?.call();
      notifyListeners();
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
      _currentWordIndex = -1;
      _progress = 0.0;
      _stopProgressTracking();
      notifyListeners();
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
      _stopProgressTracking();
      notifyListeners();
    });

    _flutterTts.setContinueHandler(() {
      _ttsState = TtsState.continued;
      _startProgressTracking();
      notifyListeners();
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
      _stopProgressTracking();
      print('TTS Error: $msg');
      notifyListeners();
    });

    // Set initial configuration
    await _setInitialConfiguration();
  }

  Future<void> _setInitialConfiguration() async {
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setLanguage(_language);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    _currentText = text;
    _words = _splitIntoWords(text);
    _currentWordIndex = -1;
    _progress = 0.0;
    _estimatedDurationMs = _estimateSpeechDuration(text);
    
    await _flutterTts.speak(text);
    notifyListeners();
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _currentWordIndex = -1;
    _progress = 0.0;
    _stopProgressTracking();
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }

  Future<void> resume() async {
    // Note: Flutter TTS doesn't have native resume, so we implement it differently
    if (_ttsState == TtsState.paused && _currentText != null) {
      // Calculate remaining text from current position
      final remainingWords = _words.skip(_currentWordIndex + 1).toList();
      final remainingText = remainingWords.join(' ');
      
      if (remainingText.isNotEmpty) {
        await speak(remainingText);
      }
    }
  }

  // Configuration methods
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_pitch);
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(_speechRate);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await _flutterTts.setLanguage(_language);
    notifyListeners();
  }

  Future<List<dynamic>> getLanguages() async {
    return await _flutterTts.getLanguages ?? [];
  }

  Future<List<dynamic>> getEngines() async {
    return await _flutterTts.getEngines ?? [];
  }

  Future<List<dynamic>> getVoices() async {
    return await _flutterTts.getVoices ?? [];
  }

  Future<void> setEngine(String engine) async {
    _engine = engine;
    await _flutterTts.setEngine(_engine!);
    notifyListeners();
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _flutterTts.setVoice(voice);
    _voice = voice['name'];
    notifyListeners();
  }

  // Word tracking and highlighting
  List<String> _splitIntoWords(String text) {
    // Enhanced word splitting that preserves punctuation context
    final words = <String>[];
    final regex = RegExp(r'\S+');
    final matches = regex.allMatches(text);
    
    for (final match in matches) {
      words.add(match.group(0)!);
    }
    
    return words;
  }

  int _estimateSpeechDuration(String text) {
    // Estimate speech duration based on word count and speech rate
    // Average speaking rate is about 150-160 words per minute
    final wordCount = _words.length;
    final wordsPerMinute = 150 * (1 + _speechRate); // Adjust for speech rate
    final estimatedMinutes = wordCount / wordsPerMinute;
    return (estimatedMinutes * 60 * 1000).round(); // Convert to milliseconds
  }

  void _startProgressTracking() {
    _stopProgressTracking(); // Ensure no duplicate timers
    
    if (!_isDisposed) {
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_isDisposed) {
          timer.cancel();
          return;
        }
        _updateProgress();
      });
    }
  }

  void _stopProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
  
  void _stopAllTimers() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _jumpToWordTimer?.cancel();
    _jumpToWordTimer = null;
  }

  void _updateProgress() {
    if (_speechStartTime == null || _estimatedDurationMs <= 0) return;
    
    final elapsedMs = DateTime.now().difference(_speechStartTime!).inMilliseconds;
    _progress = (elapsedMs / _estimatedDurationMs).clamp(0.0, 1.0);
    
    // Estimate current word based on progress
    final estimatedWordIndex = (_progress * _words.length).floor().clamp(0, _words.length - 1);
    
    // Update highlighted word if it changed
    if (estimatedWordIndex != _currentWordIndex && estimatedWordIndex < _words.length) {
      _currentWordIndex = estimatedWordIndex;
      final currentWord = _words[_currentWordIndex];
      onWordHighlight?.call(_currentWordIndex, currentWord);
    }
    
    onProgressUpdate?.call(_progress);
    notifyListeners();
  }

  // Manual word highlighting (for precise synchronization)
  void highlightWordAtIndex(int index) {
    if (index >= 0 && index < _words.length) {
      _currentWordIndex = index;
      _progress = index / _words.length;
      onWordHighlight?.call(_currentWordIndex, _words[_currentWordIndex]);
      notifyListeners();
    }
  }

  void jumpToWord(int wordIndex) {
    if (wordIndex >= 0 && wordIndex < _words.length && _ttsState == TtsState.playing) {
      // Stop current speech and resume from the selected word
      stop();
      
      // Cancel any existing timer to prevent memory leaks
      _jumpToWordTimer?.cancel();
      
      if (!_isDisposed) {
        _jumpToWordTimer = Timer(const Duration(milliseconds: 100), () {
          if (_isDisposed) return;
          
          final remainingWords = _words.skip(wordIndex).toList();
          final remainingText = remainingWords.join(' ');
          _currentWordIndex = wordIndex - 1; // Will be incremented when speech starts
          speak(remainingText);
        });
      }
    }
  }

  // Utility methods
  bool get isPlaying => _ttsState == TtsState.playing || _ttsState == TtsState.continued;
  bool get isPaused => _ttsState == TtsState.paused;
  bool get isStopped => _ttsState == TtsState.stopped;

  String getCurrentWordText() {
    if (_currentWordIndex >= 0 && _currentWordIndex < _words.length) {
      return _words[_currentWordIndex];
    }
    return '';
  }

  int getWordIndexForProgress(double progress) {
    if (_words.isEmpty) return -1;
    return (progress * _words.length).floor().clamp(0, _words.length - 1);
  }

  double getProgressForWordIndex(int index) {
    if (_words.isEmpty) return 0.0;
    return index / _words.length;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopAllTimers();
    _flutterTts.stop();
    
    // Clear callbacks to prevent memory leaks
    onWordHighlight = null;
    onSpeechComplete = null;
    onSpeechStart = null;
    onProgressUpdate = null;
    
    super.dispose();
  }
}

// Data classes for TTS configuration
class TtsConfiguration {
  final double volume;
  final double pitch;
  final double speechRate;
  final String language;
  final String? engine;
  final String? voice;

  const TtsConfiguration({
    this.volume = 1.0,
    this.pitch = 1.0,
    this.speechRate = 0.5,
    this.language = 'en-US',
    this.engine,
    this.voice,
  });

  TtsConfiguration copyWith({
    double? volume,
    double? pitch,
    double? speechRate,
    String? language,
    String? engine,
    String? voice,
  }) {
    return TtsConfiguration(
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      speechRate: speechRate ?? this.speechRate,
      language: language ?? this.language,
      engine: engine ?? this.engine,
      voice: voice ?? this.voice,
    );
  }
}

class TtsHighlightData {
  final int wordIndex;
  final String word;
  final double progress;
  final int startCharIndex;
  final int endCharIndex;

  const TtsHighlightData({
    required this.wordIndex,
    required this.word,
    required this.progress,
    required this.startCharIndex,
    required this.endCharIndex,
  });
}