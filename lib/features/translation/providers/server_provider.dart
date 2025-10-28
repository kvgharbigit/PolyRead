// Server-based translation provider using unofficial Google Translate
// Free fallback option when offline providers are unavailable

import 'package:dio/dio.dart';
import 'translation_provider.dart';

class ServerTranslationProvider implements TranslationProvider {
  static const String _providerId = 'google_translate_free';
  final Dio _dio;
  
  ServerTranslationProvider() : _dio = Dio();
  
  @override
  String get providerId => _providerId;
  
  @override
  String get providerName => 'Google Translate (Online)';
  
  @override
  bool get isOfflineCapable => false;
  
  @override
  Future<bool> get isAvailable async {
    try {
      // Check if we have internet connectivity by trying to reach Google Translate
      final response = await _dio.get(
        'https://translate.googleapis.com',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<List<LanguagePair>> getSupportedLanguagePairs() async {
    // Return common Google Translate supported language pairs
    const supportedLanguages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'es', 'name': 'Spanish'},
      {'code': 'fr', 'name': 'French'},
      {'code': 'de', 'name': 'German'},
      {'code': 'it', 'name': 'Italian'},
      {'code': 'pt', 'name': 'Portuguese'},
      {'code': 'ru', 'name': 'Russian'},
      {'code': 'ja', 'name': 'Japanese'},
      {'code': 'ko', 'name': 'Korean'},
      {'code': 'zh', 'name': 'Chinese'},
      {'code': 'ar', 'name': 'Arabic'},
      {'code': 'hi', 'name': 'Hindi'},
      {'code': 'th', 'name': 'Thai'},
      {'code': 'vi', 'name': 'Vietnamese'},
      {'code': 'nl', 'name': 'Dutch'},
      {'code': 'sv', 'name': 'Swedish'},
      {'code': 'pl', 'name': 'Polish'},
      {'code': 'tr', 'name': 'Turkish'},
    ];
    
    final pairs = <LanguagePair>[];
    for (final source in supportedLanguages) {
      for (final target in supportedLanguages) {
        if (source['code'] != target['code']) {
          pairs.add(LanguagePair(
            sourceLanguage: source['code']!,
            targetLanguage: target['code']!,
            sourceLanguageName: source['name']!,
            targetLanguageName: target['name']!,
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
      // Use unofficial Google Translate API endpoint
      final response = await _dio.get(
        'https://translate.googleapis.com/translate_a/single',
        queryParameters: {
          'client': 'gtx',
          'sl': sourceLanguage,
          'tl': targetLanguage,
          'dt': 't',
          'q': text,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );
      
      stopwatch.stop();
      
      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>;
        final translations = data[0] as List<dynamic>;
        
        // Extract translated text from response
        String translatedText = '';
        for (final translation in translations) {
          if (translation is List && translation.isNotEmpty) {
            translatedText += translation[0] as String;
          }
        }
        
        return TranslationResult.success(
          originalText: text,
          translatedText: translatedText,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          providerId: providerId,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return TranslationResult.error(
          originalText: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          providerId: providerId,
          error: 'Google Translate returned status ${response.statusCode}',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
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
    // Check if both languages are in our supported list
    const supportedCodes = [
      'en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'ja', 'ko', 'zh',
      'ar', 'hi', 'th', 'vi', 'nl', 'sv', 'pl', 'tr'
    ];
    
    return supportedCodes.contains(sourceLanguage) && 
           supportedCodes.contains(targetLanguage) &&
           sourceLanguage != targetLanguage;
  }
  
  @override
  Future<void> initialize() async {
    // Server provider doesn't need initialization
  }
  
  @override
  Future<void> dispose() async {
    _dio.close();
  }
}