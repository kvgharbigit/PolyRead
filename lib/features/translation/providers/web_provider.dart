// Web translation provider using Bergamot WASM
// Currently a stub - will be implemented when web support is added

import 'translation_provider.dart';

class WebTranslationProvider implements TranslationProvider {
  static const String _providerId = 'bergamot_wasm';
  
  @override
  String get providerId => _providerId;
  
  @override
  String get providerName => 'Bergamot WASM (Web)';
  
  @override
  bool get isOfflineCapable => true;
  
  @override
  Future<bool> get isAvailable async {
    // TODO: Check if running on web platform and Bergamot WASM is loaded
    return false; // Stub implementation
  }
  
  @override
  Future<List<LanguagePair>> getSupportedLanguagePairs() async {
    // TODO: Return Bergamot supported language pairs
    return [];
  }
  
  @override
  Future<TranslationResult> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // TODO: Implement Bergamot WASM translation
    return TranslationResult.error(
      originalText: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      providerId: providerId,
      error: 'Web translation not yet implemented',
      latencyMs: 0,
    );
  }
  
  @override
  Future<bool> supportsLanguagePair({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // TODO: Check Bergamot supported pairs
    return false;
  }
  
  @override
  Future<void> initialize() async {
    // TODO: Initialize Bergamot WASM
  }
  
  @override
  Future<void> dispose() async {
    // TODO: Clean up Bergamot resources
  }
}