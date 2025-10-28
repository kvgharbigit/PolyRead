// Phase 0 Validation: ML Kit Translation Proof
// Tests google_ml_kit package for translation performance and accuracy

import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class MlKitTranslationProof {
  /// Test ML Kit translation performance and accuracy
  static Future<TranslationProofResult> testTranslation({
    required String sourceLanguage,
    required String targetLanguage,
    required List<String> testSentences,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Initialize translator
      final onDeviceTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.values
            .firstWhere((lang) => lang.bcpCode == sourceLanguage),
        targetLanguage: TranslateLanguage.values
            .firstWhere((lang) => lang.bcpCode == targetLanguage),
      );
      
      // Check if models are downloaded
      final modelManager = OnDeviceTranslatorModelManager();
      final sourceModelDownloaded = await modelManager.isModelDownloaded(sourceLanguage);
      final targetModelDownloaded = await modelManager.isModelDownloaded(targetLanguage);
      
      if (!sourceModelDownloaded || !targetModelDownloaded) {
        return TranslationProofResult.error(
          'Models not downloaded. Source: $sourceModelDownloaded, Target: $targetModelDownloaded',
          stopwatch.elapsedMilliseconds,
        );
      }
      
      // Test translation performance
      final translationResults = <TranslationTestCase>[];
      
      for (final sentence in testSentences) {
        final sentenceStopwatch = Stopwatch()..start();
        
        try {
          final translation = await onDeviceTranslator.translateText(sentence);
          sentenceStopwatch.stop();
          
          translationResults.add(TranslationTestCase(
            originalText: sentence,
            translatedText: translation,
            latencyMs: sentenceStopwatch.elapsedMilliseconds,
            success: true,
          ));
        } catch (e) {
          sentenceStopwatch.stop();
          translationResults.add(TranslationTestCase(
            originalText: sentence,
            translatedText: '',
            latencyMs: sentenceStopwatch.elapsedMilliseconds,
            success: false,
            error: e.toString(),
          ));
        }
      }
      
      onDeviceTranslator.close();
      stopwatch.stop();
      
      return TranslationProofResult(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        testResults: translationResults,
        totalTimeMs: stopwatch.elapsedMilliseconds,
        averageLatencyMs: translationResults
            .map((r) => r.latencyMs)
            .reduce((a, b) => a + b) / translationResults.length,
        successRate: translationResults.where((r) => r.success).length / translationResults.length,
      );
    } catch (e) {
      stopwatch.stop();
      return TranslationProofResult.error(
        e.toString(),
        stopwatch.elapsedMilliseconds,
      );
    }
  }
  
  /// Download required models for testing
  static Future<ModelDownloadResult> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
    bool wifiOnly = true,
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
      
      // Download missing models
      final downloadTasks = <Future<void>>[];
      
      if (!sourceDownloaded) {
        downloadTasks.add(modelManager.downloadModel(
          sourceLanguage,
          isWifiRequired: wifiOnly,
        ));
      }
      
      if (!targetDownloaded) {
        downloadTasks.add(modelManager.downloadModel(
          targetLanguage,
          isWifiRequired: wifiOnly,
        ));
      }
      
      await Future.wait(downloadTasks);
      
      // Verify downloads
      final finalSourceDownloaded = await modelManager.isModelDownloaded(sourceLanguage);
      final finalTargetDownloaded = await modelManager.isModelDownloaded(targetLanguage);
      
      return ModelDownloadResult(
        success: finalSourceDownloaded && finalTargetDownloaded,
        message: finalSourceDownloaded && finalTargetDownloaded 
            ? 'All models downloaded successfully'
            : 'Some models failed to download',
        sourceDownloaded: finalSourceDownloaded,
        targetDownloaded: finalTargetDownloaded,
      );
    } catch (e) {
      return ModelDownloadResult(
        success: false,
        message: 'Download failed: $e',
        sourceDownloaded: false,
        targetDownloaded: false,
      );
    }
  }
  
  /// Run comprehensive test suite
  static Future<List<TranslationProofResult>> runTestSuite() async {
    const testCases = [
      TranslationTestConfiguration(
        sourceLanguage: 'en',
        targetLanguage: 'es',
        testSentences: [
          'Hello, how are you?',
          'I am reading a book about language learning.',
          'The weather is beautiful today.',
          'Can you help me translate this sentence?',
          'What time does the library close?',
        ],
      ),
      TranslationTestConfiguration(
        sourceLanguage: 'es', 
        targetLanguage: 'en',
        testSentences: [
          '¡Hola! ¿Cómo estás?',
          'Estoy leyendo un libro sobre aprendizaje de idiomas.',
          'El clima está hermoso hoy.',
          '¿Puedes ayudarme a traducir esta oración?',
          '¿A qué hora cierra la biblioteca?',
        ],
      ),
    ];
    
    final results = <TranslationProofResult>[];
    
    for (final config in testCases) {
      // First ensure models are downloaded
      final downloadResult = await downloadModels(
        sourceLanguage: config.sourceLanguage,
        targetLanguage: config.targetLanguage,
      );
      
      if (!downloadResult.success) {
        results.add(TranslationProofResult.error(
          'Model download failed: ${downloadResult.message}',
          0,
        ));
        continue;
      }
      
      // Run translation test
      final translationResult = await testTranslation(
        sourceLanguage: config.sourceLanguage,
        targetLanguage: config.targetLanguage,
        testSentences: config.testSentences,
      );
      
      results.add(translationResult);
    }
    
    return results;
  }
}

class TranslationProofResult {
  final String sourceLanguage;
  final String targetLanguage;
  final List<TranslationTestCase> testResults;
  final int totalTimeMs;
  final double averageLatencyMs;
  final double successRate;
  final String? error;
  
  const TranslationProofResult({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.testResults,
    required this.totalTimeMs,
    required this.averageLatencyMs,
    required this.successRate,
    this.error,
  });
  
  const TranslationProofResult.error(this.error, this.totalTimeMs)
      : sourceLanguage = '',
        targetLanguage = '',
        testResults = const [],
        averageLatencyMs = 0.0,
        successRate = 0.0;
  
  bool get hasError => error != null;
  bool get meetsCriteria => averageLatencyMs < 300 && successRate > 0.9 && !hasError;
}

class TranslationTestCase {
  final String originalText;
  final String translatedText;
  final int latencyMs;
  final bool success;
  final String? error;
  
  const TranslationTestCase({
    required this.originalText,
    required this.translatedText,
    required this.latencyMs,
    required this.success,
    this.error,
  });
}

class TranslationTestConfiguration {
  final String sourceLanguage;
  final String targetLanguage;
  final List<String> testSentences;
  
  const TranslationTestConfiguration({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.testSentences,
  });
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