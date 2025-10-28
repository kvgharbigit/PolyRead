// Reader Translation Service
// Connects text selection in readers to the translation pipeline

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/translation/models/translation_request.dart';
import 'package:polyread/features/translation/models/translation_response.dart';
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/dictionary_service.dart';
import 'package:polyread/features/translation/services/translation_cache_service.dart';
import 'package:polyread/features/vocabulary/services/vocabulary_service.dart';
import 'package:polyread/features/vocabulary/models/vocabulary_item.dart';
import 'package:polyread/core/database/app_database.dart';

class ReaderTranslationService extends ChangeNotifier {
  final TranslationService _translationService;
  final VocabularyService _vocabularyService;
  final AppDatabase _database;
  
  // Current translation state
  TranslationResponse? _currentTranslation;
  bool _isTranslating = false;
  String? _error;
  
  // Text selection state
  String? _selectedText;
  Offset? _selectionPosition;
  String? _selectionContext;
  int? _currentBookId;

  ReaderTranslationService({
    required TranslationService translationService,
    required VocabularyService vocabularyService,
    required AppDatabase database,
  }) : _translationService = translationService,
       _vocabularyService = vocabularyService,
       _database = database;

  // Getters
  TranslationResponse? get currentTranslation => _currentTranslation;
  bool get isTranslating => _isTranslating;
  String? get error => _error;
  String? get selectedText => _selectedText;
  Offset? get selectionPosition => _selectionPosition;
  bool get hasSelection => _selectedText != null && _selectedText!.isNotEmpty;

  /// Initialize the service
  Future<void> initialize() async {
    await _translationService.initialize();
  }

  /// Set the current book being read
  void setCurrentBook(int bookId) {
    _currentBookId = bookId;
    notifyListeners();
  }

  /// Handle text selection from reader engines
  Future<void> handleTextSelection({
    required String selectedText,
    required Offset position,
    required String sourceLanguage,
    required String targetLanguage,
    String? context,
  }) async {
    _selectedText = selectedText.trim();
    _selectionPosition = position;
    _selectionContext = context;
    _error = null;
    
    if (_selectedText!.isEmpty) {
      clearSelection();
      return;
    }

    notifyListeners();

    // Auto-translate if enabled in settings
    await translateSelection(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  /// Translate the currently selected text
  Future<void> translateSelection({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (_selectedText == null || _selectedText!.isEmpty) {
      _error = 'No text selected';
      notifyListeners();
      return;
    }

    _isTranslating = true;
    _error = null;
    notifyListeners();

    try {
      final request = TranslationRequest(
        text: _selectedText!,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        timestamp: DateTime.now(),
      );

      _currentTranslation = await _translationService.translateText(
        text: _selectedText!,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      _isTranslating = false;
      notifyListeners();

    } catch (e) {
      _error = e.toString();
      _isTranslating = false;
      notifyListeners();
    }
  }

  /// Add current translation to vocabulary
  Future<void> addToVocabulary({
    String? customTranslation,
    String? customDefinition,
  }) async {
    if (_selectedText == null || _currentTranslation == null || _currentBookId == null) {
      return;
    }

    try {
      final vocabularyItem = VocabularyItem(
        id: 0, // Will be auto-generated
        bookId: _currentBookId!,
        sourceText: _selectedText!,
        translation: customTranslation ?? _currentTranslation!.translatedText,
        sourceLanguage: _currentTranslation!.request.sourceLanguage,
        targetLanguage: _currentTranslation!.request.targetLanguage,
        context: _selectionContext,
        bookPosition: null, // TODO: Add current reader position
        definition: customDefinition ?? _extractDefinition(),
        difficulty: DifficultyLevel.learning,
        reviewCount: 0,
        nextReview: DateTime.now().add(const Duration(hours: 4)),
        lastReviewed: null,
        createdAt: DateTime.now(),
        isFavorite: false,
      );

      await _vocabularyService.addVocabularyItem(vocabularyItem);
      
      // Clear selection after adding to vocabulary
      clearSelection();
      
    } catch (e) {
      _error = 'Failed to add to vocabulary: $e';
      notifyListeners();
    }
  }

  /// Extract definition from dictionary result
  String? _extractDefinition() {
    final dictionaryResult = _currentTranslation?.dictionaryResult;
    if (dictionaryResult?.entries.isNotEmpty == true) {
      final entry = dictionaryResult!.entries.first;
      return entry.definition;
    }
    return null;
  }

  /// Clear current selection and translation
  void clearSelection() {
    _selectedText = null;
    _selectionPosition = null;
    _selectionContext = null;
    _currentTranslation = null;
    _error = null;
    _isTranslating = false;
    notifyListeners();
  }

  /// Get translation suggestions for current selection
  Future<List<String>> getTranslationSuggestions() async {
    if (_currentTranslation == null) return [];

    final suggestions = <String>[];
    
    // Primary translation
    suggestions.add(_currentTranslation!.translatedText);
    
    // Dictionary alternatives
    final dictionaryResult = _currentTranslation!.dictionaryResult;
    if (dictionaryResult?.entries.isNotEmpty == true) {
      for (final entry in dictionaryResult!.entries) {
        suggestions.addAll(entry.translations);
      }
    }
    
    // Remove duplicates and return
    return suggestions.toSet().toList();
  }

  /// Get context information for translation
  Map<String, dynamic> getTranslationContext() {
    if (_currentTranslation == null) return {};

    return {
      'source': _currentTranslation!.source.name,
      'confidence': _currentTranslation!.confidence,
      'responseTime': _currentTranslation!.responseTime?.inMilliseconds,
      'hasDictionary': _currentTranslation!.dictionaryResult != null,
      'hasML': _currentTranslation!.mlKitResult != null,
      'hasServer': _currentTranslation!.serverResult != null,
    };
  }

  @override
  void dispose() {
    clearSelection();
    super.dispose();
  }
}