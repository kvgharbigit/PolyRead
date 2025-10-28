// Abstract interface for translation providers
// Allows swapping between ML Kit, Web (Bergamot), and Server providers

abstract class TranslationProvider {
  /// Unique identifier for this provider
  String get providerId;
  
  /// Human-readable name for this provider
  String get providerName;
  
  /// Whether this provider can work offline
  bool get isOfflineCapable;
  
  /// Whether this provider is currently available
  Future<bool> get isAvailable;
  
  /// List of supported language pairs for this provider
  Future<List<LanguagePair>> getSupportedLanguagePairs();
  
  /// Translate text from source to target language
  Future<TranslationResult> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
  
  /// Check if a specific language pair is supported
  Future<bool> supportsLanguagePair({
    required String sourceLanguage,
    required String targetLanguage,
  });
  
  /// Initialize the provider (download models, setup, etc.)
  Future<void> initialize();
  
  /// Clean up resources
  Future<void> dispose();
}

class LanguagePair {
  final String sourceLanguage;
  final String targetLanguage;
  final String sourceLanguageName;
  final String targetLanguageName;
  
  const LanguagePair({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceLanguageName,
    required this.targetLanguageName,
  });
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguagePair &&
        other.sourceLanguage == sourceLanguage &&
        other.targetLanguage == targetLanguage;
  }
  
  @override
  int get hashCode => sourceLanguage.hashCode ^ targetLanguage.hashCode;
  
  @override
  String toString() => '$sourceLanguageName → $targetLanguageName';
}

class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String providerId;
  final int latencyMs;
  final bool success;
  final String? error;
  final DateTime timestamp;
  
  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.providerId,
    required this.latencyMs,
    required this.success,
    this.error,
    required this.timestamp,
  });
  
  factory TranslationResult.success({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
    required String providerId,
    required int latencyMs,
  }) {
    return TranslationResult(
      originalText: originalText,
      translatedText: translatedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      providerId: providerId,
      latencyMs: latencyMs,
      success: true,
      timestamp: DateTime.now(),
    );
  }
  
  factory TranslationResult.error({
    required String originalText,
    required String sourceLanguage,
    required String targetLanguage,
    required String providerId,
    required String error,
    required int latencyMs,
  }) {
    return TranslationResult(
      originalText: originalText,
      translatedText: '',
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      providerId: providerId,
      latencyMs: latencyMs,
      success: false,
      error: error,
      timestamp: DateTime.now(),
    );
  }
}