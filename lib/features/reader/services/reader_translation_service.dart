// Reader Translation Service
// Connects text selection in readers to the translation pipeline

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/translation/models/translation_request.dart';
import 'package:polyread/features/translation/models/translation_response.dart' as response_model;
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/translation_cache_service.dart';
import 'package:polyread/features/vocabulary/services/drift_vocabulary_service.dart';
import 'package:polyread/features/vocabulary/models/vocabulary_item.dart' as vocab_model;
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/utils/constants.dart';

class ReaderTranslationService extends ChangeNotifier {
  final TranslationService _translationService;
  final DriftVocabularyService? _vocabularyService;
  final AppDatabase _database;
  
  // Current translation state
  response_model.TranslationResponse? _currentTranslation;
  bool _isTranslating = false;
  String? _error;
  bool _needsModelDownload = false;
  String? _missingModelProvider;
  
  // Text selection state
  String? _selectedText;
  Offset? _selectionPosition;
  String? _selectionContext;
  int? _currentBookId;
  String? _currentBookTitle;
  String? _currentReaderPosition;
  BuildContext? _context;

  ReaderTranslationService({
    required TranslationService translationService,
    required DriftVocabularyService? vocabularyService,
    required AppDatabase database,
  }) : _translationService = translationService,
       _vocabularyService = vocabularyService,
       _database = database;

  // Getters
  response_model.TranslationResponse? get currentTranslation => _currentTranslation;
  bool get isTranslating => _isTranslating;
  String? get error => _error;
  String? get selectedText => _selectedText;
  String? get selectedContext => _selectionContext;
  Offset? get selectionPosition => _selectionPosition;
  bool get hasSelection => _selectedText != null && _selectedText!.isNotEmpty;
  bool get needsModelDownload => _needsModelDownload;
  String? get missingModelProvider => _missingModelProvider;
  
  // Access to underlying translation service for ML Kit provider
  TranslationService get translationService => _translationService;

  /// Initialize the service
  Future<void> initialize() async {
    await _translationService.initialize();
  }

  /// Set the current book being read
  void setCurrentBook(int bookId, {String? bookTitle}) {
    _currentBookId = bookId;
    _currentBookTitle = bookTitle;
    notifyListeners();
  }
  
  /// Update current reader position for vocabulary context
  void updateReaderPosition(String position) {
    _currentReaderPosition = position;
  }

  /// Set build context for dialog prompts and UI updates
  void setContext(BuildContext? context) {
    if (_context != context) {
      _context = context;
      // Don't notify listeners for context changes to avoid rebuild loops
    }
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
    _needsModelDownload = false;
    _missingModelProvider = null;
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

      // Check if models need to be downloaded
      if (_currentTranslation!.source == response_model.TranslationSource.modelsNotDownloaded) {
        _needsModelDownload = true;
        _missingModelProvider = _currentTranslation!.providerId;
        _error = _currentTranslation!.error;
      } else if (_currentTranslation!.source == response_model.TranslationSource.error) {
        _error = _currentTranslation!.error;
      }

      _isTranslating = false;
      notifyListeners();

    } catch (e) {
      _error = AppConstants.translationErrorMessage;
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
      final vocabularyItem = vocab_model.VocabularyItem(
        id: null, // Will be auto-generated
        word: _selectedText!,
        sourceLanguage: _currentTranslation!.request.sourceLanguage,
        targetLanguage: _currentTranslation!.request.targetLanguage,
        translation: customTranslation ?? _currentTranslation!.translatedText,
        definition: customDefinition ?? _extractDefinition(),
        context: _selectionContext,
        bookTitle: _currentBookTitle,
        bookLocation: _currentReaderPosition,
        createdAt: DateTime.now(),
        lastReviewed: DateTime.now(),
        srsData: vocab_model.SRSData.initial(),
        tags: const [],
        status: vocab_model.VocabularyStatus.learning,
      );

      await _vocabularyService?.addVocabularyItem(vocabularyItem);
      
      // Clear selection after adding to vocabulary
      clearSelection();
      
    } catch (e) {
      _error = AppConstants.vocabularyErrorMessage;
      notifyListeners();
    }
  }

  /// Extract definition from cycling dictionary result
  String? _extractDefinition() {
    final cyclingResult = _currentTranslation?.cyclingDictionaryResult;
    if (cyclingResult != null) {
      // Try to extract from cycling dictionary result
      try {
        if (cyclingResult.sourceMeanings?.hasResults == true) {
          final meanings = cyclingResult.sourceMeanings?.meanings;
          if (meanings != null && meanings.isNotEmpty) {
            return meanings.first.displayTranslation;
          }
        }
      } catch (e) {
        // Fallback to translated text
        return _currentTranslation?.translatedText;
      }
    }
    return _currentTranslation?.translatedText;
  }

  /// Clear current selection and translation
  void clearSelection() {
    _selectedText = null;
    _selectionPosition = null;
    _selectionContext = null;
    _currentTranslation = null;
    _error = null;
    _isTranslating = false;
    _needsModelDownload = false;
    _missingModelProvider = null;
    notifyListeners();
  }

  /// Trigger download of missing models and retry translation
  Future<void> downloadModelsAndRetry({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (!_needsModelDownload || _missingModelProvider == null) {
      return;
    }

    try {
      // Check if translation service supports model download
      if (_translationService.hasModelDownload(_missingModelProvider!)) {
        // Attempt to download the missing model
        await _translationService.downloadModel(
          _missingModelProvider!,
          sourceLanguage,
          targetLanguage,
        );
        
        _needsModelDownload = false;
        _missingModelProvider = null;
        notifyListeners();

        // Retry translation after download
        await translateSelection(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
      } else {
        // Provider doesn't support auto-download, show error
        _error = 'Model download not supported for $_missingModelProvider. Please install manually.';
        notifyListeners();
      }
    } catch (e) {
      _error = AppConstants.modelDownloadErrorMessage;
      notifyListeners();
    }
  }

  /// Get translation suggestions for current selection
  Future<List<String>> getTranslationSuggestions() async {
    if (_currentTranslation == null) return [];

    final suggestions = <String>[];
    
    // Primary translation
    suggestions.add(_currentTranslation!.translatedText);
    
    // Dictionary alternatives
    final cyclingResult = _currentTranslation!.cyclingDictionaryResult;
    if (cyclingResult?.sourceMeanings?.hasResults == true) {
      final meanings = cyclingResult!.sourceMeanings?.meanings;
      if (meanings != null) {
        for (final meaning in meanings) {
          // Add cycling dictionary meanings
          final translation = meaning.displayTranslation.trim();
          if (translation.isNotEmpty && !suggestions.contains(translation)) {
            suggestions.add(translation);
          }
        }
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
      'confidence': 1.0, // Placeholder for confidence
      'responseTime': _currentTranslation!.responseTime?.inMilliseconds,
      'hasDictionary': _currentTranslation!.cyclingDictionaryResult != null,
      'hasML': _currentTranslation!.mlKitResult != null,
      'hasServer': _currentTranslation!.serverResult != null,
    };
  }

  /// Direct translation method for sentence translation
  /// Delegates to the underlying TranslationService
  Future<response_model.TranslationResponse> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    bool useCache = true,
  }) async {
    return await _translationService.translateText(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      useCache: useCache,
    );
  }

  @override
  void dispose() {
    // Clear state without notifying listeners during disposal
    _selectedText = null;
    _selectionPosition = null;
    _selectionContext = null;
    _currentTranslation = null;
    _error = null;
    _isTranslating = false;
    _needsModelDownload = false;
    _missingModelProvider = null;
    _context = null;
    super.dispose();
  }
}