// ML Kit translation provider for mobile devices (iOS/Android)
// Provides offline translation using Google ML Kit

import 'package:google_ml_kit/google_ml_kit.dart';
import 'translation_provider.dart';

class MlKitTranslationProvider implements TranslationProvider {
  static const String _providerId = 'ml_kit';
  
  OnDeviceTranslator? _currentTranslator;
  String? _currentSourceLanguage;
  String? _currentTargetLanguage;
  
  @override
  String get providerId => _providerId;
  
  @override
  String get providerName => 'Google ML Kit (Offline)';
  
  @override
  bool get isOfflineCapable => true;
  
  @override
  Future<bool> get isAvailable async {
    try {
      // Check if ML Kit is available on this platform
      final modelManager = OnDeviceTranslatorModelManager();
      return true; // ML Kit should be available on mobile platforms
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<List<LanguagePair>> getSupportedLanguagePairs() async {
    final supportedLanguages = TranslateLanguage.values;
    final pairs = <LanguagePair>[];
    
    // Generate all possible language pairs
    for (final source in supportedLanguages) {
      for (final target in supportedLanguages) {
        if (source != target) {
          pairs.add(LanguagePair(
            sourceLanguage: source.bcpCode,
            targetLanguage: target.bcpCode,
            sourceLanguageName: _getLanguageName(source),
            targetLanguageName: _getLanguageName(target),
          ));
        }
      }
    }
    
    return pairs;
  }
  
  @override
  Future<TranslationResult> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check if we need to create a new translator
      if (_currentTranslator == null ||
          _currentSourceLanguage != sourceLanguage ||
          _currentTargetLanguage != targetLanguage) {
        await _setupTranslator(sourceLanguage, targetLanguage);
      }
      
      if (_currentTranslator == null) {
        throw Exception('Failed to initialize translator');
      }
      
      final translatedText = await _currentTranslator!.translateText(text);
      stopwatch.stop();
      
      return TranslationResult.success(
        originalText: text,
        translatedText: translatedText,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        providerId: providerId,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return TranslationResult.error(
        originalText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        providerId: providerId,
        error: e.toString(),
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
  
  @override
  Future<bool> supportsLanguagePair({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final sourceEnum = TranslateLanguage.values
          .where((lang) => lang.bcpCode == sourceLanguage)
          .firstOrNull;
      final targetEnum = TranslateLanguage.values
          .where((lang) => lang.bcpCode == targetLanguage)
          .firstOrNull;
      
      return sourceEnum != null && targetEnum != null;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<void> initialize() async {
    // ML Kit doesn't require global initialization
    // Initialization happens per-translator in _setupTranslator
  }
  
  @override
  Future<void> dispose() async {
    await _currentTranslator?.close();
    _currentTranslator = null;
    _currentSourceLanguage = null;
    _currentTargetLanguage = null;
  }
  
  /// Download models for a specific language pair
  Future<ModelDownloadResult> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
    bool wifiOnly = true,
    Function(double progress)? onProgress,
  }) async {
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      
      // Check current status
      final sourceDownloaded = await modelManager.isModelDownloaded(sourceLanguage);
      final targetDownloaded = await modelManager.isModelDownloaded(targetLanguage);
      
      if (sourceDownloaded && targetDownloaded) {
        return const ModelDownloadResult(
          success: true,
          message: 'Models already downloaded',
          sourceDownloaded: true,
          targetDownloaded: true,
        );
      }
      
      // Download missing models with progress tracking
      final totalDownloads = (!sourceDownloaded ? 1 : 0) + (!targetDownloaded ? 1 : 0);
      var completedDownloads = 0;
      
      if (!sourceDownloaded) {
        onProgress?.call(0.2); // Starting source download
        await modelManager.downloadModel(
          sourceLanguage,
          isWifiRequired: wifiOnly,
        );
        completedDownloads++;
        onProgress?.call(completedDownloads / totalDownloads * 0.7 + 0.2); // More granular progress
      }
      
      if (!targetDownloaded) {
        if (sourceDownloaded) onProgress?.call(0.2); // Starting first download
        else onProgress?.call(0.5); // Starting target after source
        await modelManager.downloadModel(
          targetLanguage,
          isWifiRequired: wifiOnly,
        );
        completedDownloads++;
        onProgress?.call(completedDownloads / totalDownloads * 0.7 + 0.2);
      }
      
      // Verify downloads
      onProgress?.call(0.95); // Almost complete
      final finalSourceDownloaded = await modelManager.isModelDownloaded(sourceLanguage);
      final finalTargetDownloaded = await modelManager.isModelDownloaded(targetLanguage);
      
      // Always complete progress regardless of verification result
      onProgress?.call(1.0);
      
      return ModelDownloadResult(
        success: finalSourceDownloaded && finalTargetDownloaded,
        message: finalSourceDownloaded && finalTargetDownloaded 
            ? 'All models downloaded successfully'
            : 'Some models failed to download',
        sourceDownloaded: finalSourceDownloaded,
        targetDownloaded: finalTargetDownloaded,
      );
    } catch (e) {
      // Complete progress even on failure to prevent UI from hanging
      onProgress?.call(1.0);
      return ModelDownloadResult(
        success: false,
        message: 'Download failed: $e',
        sourceDownloaded: false,
        targetDownloaded: false,
      );
    }
  }
  
  /// Check if models are downloaded for a language pair
  Future<bool> areModelsDownloaded({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final sourceDownloaded = await modelManager.isModelDownloaded(sourceLanguage);
      final targetDownloaded = await modelManager.isModelDownloaded(targetLanguage);
      return sourceDownloaded && targetDownloaded;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> _setupTranslator(String sourceLanguage, String targetLanguage) async {
    // Close existing translator
    await _currentTranslator?.close();
    
    try {
      final sourceEnum = TranslateLanguage.values
          .firstWhere((lang) => lang.bcpCode == sourceLanguage);
      final targetEnum = TranslateLanguage.values
          .firstWhere((lang) => lang.bcpCode == targetLanguage);
      
      _currentTranslator = OnDeviceTranslator(
        sourceLanguage: sourceEnum,
        targetLanguage: targetEnum,
      );
      
      _currentSourceLanguage = sourceLanguage;
      _currentTargetLanguage = targetLanguage;
    } catch (e) {
      _currentTranslator = null;
      _currentSourceLanguage = null;
      _currentTargetLanguage = null;
      throw Exception('Unsupported language pair: $sourceLanguage → $targetLanguage');
    }
  }
  
  String _getLanguageName(TranslateLanguage language) {
    // Map language codes to human-readable names
    const languageNames = {
      'af': 'Afrikaans',
      'ar': 'Arabic',
      'be': 'Belarusian',
      'bg': 'Bulgarian',
      'bn': 'Bengali',
      'ca': 'Catalan',
      'cs': 'Czech',
      'cy': 'Welsh',
      'da': 'Danish',
      'de': 'German',
      'el': 'Greek',
      'en': 'English',
      'eo': 'Esperanto',
      'es': 'Spanish',
      'et': 'Estonian',
      'fa': 'Persian',
      'fi': 'Finnish',
      'fr': 'French',
      'ga': 'Irish',
      'gl': 'Galician',
      'gu': 'Gujarati',
      'he': 'Hebrew',
      'hi': 'Hindi',
      'hr': 'Croatian',
      'ht': 'Haitian',
      'hu': 'Hungarian',
      'id': 'Indonesian',
      'is': 'Icelandic',
      'it': 'Italian',
      'ja': 'Japanese',
      'ka': 'Georgian',
      'kn': 'Kannada',
      'ko': 'Korean',
      'lt': 'Lithuanian',
      'lv': 'Latvian',
      'mk': 'Macedonian',
      'mr': 'Marathi',
      'ms': 'Malay',
      'mt': 'Maltese',
      'nl': 'Dutch',
      'no': 'Norwegian',
      'pl': 'Polish',
      'pt': 'Portuguese',
      'ro': 'Romanian',
      'ru': 'Russian',
      'sk': 'Slovak',
      'sl': 'Slovenian',
      'sq': 'Albanian',
      'sv': 'Swedish',
      'sw': 'Swahili',
      'ta': 'Tamil',
      'te': 'Telugu',
      'th': 'Thai',
      'tl': 'Filipino',
      'tr': 'Turkish',
      'uk': 'Ukrainian',
      'ur': 'Urdu',
      'vi': 'Vietnamese',
      'zh': 'Chinese',
    };
    
    return languageNames[language.bcpCode] ?? language.bcpCode.toUpperCase();
  }
}

class ModelDownloadResult {
  final bool success;
  final String message;
  final bool sourceDownloaded;
  final bool targetDownloaded;
  
  const ModelDownloadResult({
    required this.success,
    required this.message,
    required this.sourceDownloaded,
    required this.targetDownloaded,
  });
}

extension on List<TranslateLanguage> {
  TranslateLanguage? get firstOrNull {
    return isEmpty ? null : first;
  }
}