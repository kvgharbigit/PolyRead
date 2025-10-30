// Centralized Translation Service - Coordinates between dictionary and ML providers
// Strategy: Dictionary (single words) → ML Kit → Google Translate

import '../providers/translation_provider.dart';
import '../providers/ml_kit_provider.dart';
import '../providers/server_provider.dart';
import '../services/cycling_dictionary_service.dart';
import '../models/translation_request.dart';
import '../models/translation_response.dart' as response_model;

class TranslationService {
  final CyclingDictionaryService _dictionaryService;
  final dynamic _cacheService;
  final List<TranslationProvider> _providers;
  
  late final MlKitTranslationProvider _mlKitProvider;
  late final ServerTranslationProvider _serverProvider;
  
  TranslationService({
    required CyclingDictionaryService dictionaryService,
    required dynamic cacheService,
  }) : _dictionaryService = dictionaryService,
       _cacheService = cacheService,
       _providers = [] {
    _mlKitProvider = MlKitTranslationProvider();
    _serverProvider = ServerTranslationProvider();
    _providers.addAll([_mlKitProvider, _serverProvider]);
  }
  
  /// Initialize all translation providers
  Future<void> initialize() async {
    try {
      await _cacheService.initialize();
    } catch (e) {
      print('Failed to initialize cache service: $e');
      // Continue without cache if it fails
    }
    
    // Initialize providers in parallel for better performance
    final initFutures = _providers.map((provider) async {
      try {
        await provider.initialize();
        return true;
      } catch (e) {
        // Log error but continue with other providers
        print('Failed to initialize provider ${provider.providerId}: $e');
        return false;
      }
    });
    
    await Future.wait(initFutures);
  }
  
  /// Main translation method with fallback strategy
  /// Single words: CyclingDictionary → ML Kit → Google Translate
  /// Sentences: ML Kit → Google Translate (skip dictionary)
  Future<response_model.TranslationResponse> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    bool useCache = true,
  }) async {
    final request = TranslationRequest(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      timestamp: DateTime.now(),
    );
    
    // Check cache first if enabled
    if (useCache) {
      try {
        final cachedResult = await _cacheService.getCachedTranslation(request);
        if (cachedResult != null) {
          return response_model.TranslationResponse.fromCached(cachedResult);
        }
      } catch (e) {
        print('Cache lookup failed: $e');
        // Continue without cache
      }
    }
    
    // Step 1: Cycling Dictionary lookup (for single words)
    if (_isSingleWord(text)) {
      final dictionaryResult = await _tryCyclingDictionaryLookup(
        text, 
        sourceLanguage,
        targetLanguage,
      );
      
      if (dictionaryResult.hasResults) {
        final response = response_model.TranslationResponse.fromCyclingDictionary(
          request: request,
          dictionaryResult: dictionaryResult,
        );
        
        // Cache dictionary results
        if (useCache) {
          try {
            await _cacheService.cacheTranslation(request, response);
          } catch (e) {
            print('Failed to cache dictionary result: $e');
            // Don't fail translation due to cache errors
          }
        }
        
        return response;
      }
    }
    
    // Step 2: ML Kit (offline, preferred for mobile)
    if (await _mlKitProvider.isAvailable) {
      final mlKitSupported = await _mlKitProvider.supportsLanguagePair(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      
      if (mlKitSupported) {
        // Check if models are downloaded
        final modelsAvailable = await _mlKitProvider.areModelsDownloaded(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        if (modelsAvailable) {
          final translationResult = await _mlKitProvider.translateText(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );
          
          if (translationResult.success) {
            final mlKitResult = response_model.MlKitResult(
              translatedText: translationResult.translatedText,
              providerId: translationResult.providerId,
              latencyMs: translationResult.latencyMs,
              success: translationResult.success,
              error: translationResult.error,
            );
            
            final response = response_model.TranslationResponse.fromMlKit(
              request: request,
              mlKitResult: mlKitResult,
            );
            
            // Cache ML Kit results
            if (useCache) {
              try {
                await _cacheService.cacheTranslation(request, response);
              } catch (e) {
                print('Failed to cache ML Kit result: $e');
                // Don't fail translation due to cache errors
              }
            }
            
            return response;
          }
        } else {
          // Models not downloaded - could trigger download here
          return response_model.TranslationResponse.modelsNotDownloaded(
            request: request,
            providerId: _mlKitProvider.providerId,
          );
        }
      }
    }
    
    // Step 2: Google Translate (online fallback)
    if (await _serverProvider.isAvailable) {
      final serverSupported = await _serverProvider.supportsLanguagePair(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      
      if (serverSupported) {
        final translationResult = await _serverProvider.translateText(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        if (translationResult.success) {
          final serverResult = response_model.ServerResult(
            translatedText: translationResult.translatedText,
            providerId: translationResult.providerId,
            latencyMs: translationResult.latencyMs,
            success: translationResult.success,
            error: translationResult.error,
          );
          
          final response = response_model.TranslationResponse.fromServer(
            request: request,
            serverResult: serverResult,
          );
          
          // Cache server results
          if (useCache) {
            try {
              await _cacheService.cacheTranslation(request, response);
            } catch (e) {
              print('Failed to cache server result: $e');
              // Don't fail translation due to cache errors
            }
          }
          
          return response;
        }
      }
    }
    
    // All providers failed
    return response_model.TranslationResponse.error(
      request: request,
      error: 'No translation providers available',
    );
  }
  
  /// Get available translation providers and their status
  Future<List<ProviderStatus>> getProviderStatus() async {
    final statuses = <ProviderStatus>[];
    
    // Cycling Dictionary status
    try {
      final stats = await _dictionaryService.getStats('es', 'en'); // Default to es-en for status
      statuses.add(ProviderStatus(
        providerId: 'cycling_dictionary',
        providerName: 'Cycling Dictionary',
        isAvailable: stats['totalWordGroups']! > 0,
        isOfflineCapable: true,
        additionalInfo: '${stats['totalWordGroups']} word groups, ${stats['totalMeanings']} meanings',
      ));
    } catch (e) {
      statuses.add(ProviderStatus(
        providerId: 'cycling_dictionary',
        providerName: 'Cycling Dictionary',
        isAvailable: false,
        isOfflineCapable: true,
        additionalInfo: 'Error: $e',
      ));
    }
    
    // ML providers status - check in parallel for better performance
    final providerFutures = _providers.map((provider) async {
      final isAvailable = await provider.isAvailable;
      String? additionalInfo;
      
      if (provider is MlKitTranslationProvider) {
        // Could add model download status here
        additionalInfo = isAvailable ? 'Ready' : 'Not available';
      } else if (provider is ServerTranslationProvider) {
        additionalInfo = isAvailable ? 'Online' : 'Offline';
      }
      
      return ProviderStatus(
        providerId: provider.providerId,
        providerName: provider.providerName,
        isAvailable: isAvailable,
        isOfflineCapable: provider.isOfflineCapable,
        additionalInfo: additionalInfo,
      );
    });
    
    final providerStatuses = await Future.wait(providerFutures);
    statuses.addAll(providerStatuses);
    
    return statuses;
  }
  
  /// Download ML Kit models for a language pair
  Future<ModelDownloadResult> downloadModels({
    required String sourceLanguage,
    required String targetLanguage,
    bool wifiOnly = true,
  }) async {
    return await _mlKitProvider.downloadModels(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      wifiOnly: wifiOnly,
    );
  }
  
  /// Get supported language pairs across all providers
  Future<Map<String, List<LanguagePair>>> getSupportedLanguagePairs() async {
    final allPairs = <String, List<LanguagePair>>{};
    
    // Fetch language pairs in parallel for better performance
    final futures = _providers.map((provider) async {
      try {
        final pairs = await provider.getSupportedLanguagePairs();
        return MapEntry(provider.providerId, pairs);
      } catch (e) {
        return MapEntry(provider.providerId, <LanguagePair>[]);
      }
    });
    
    final results = await Future.wait(futures);
    for (final entry in results) {
      allPairs[entry.key] = entry.value;
    }
    
    return allPairs;
  }
  
  /// Clear translation cache
  Future<void> clearCache() async {
    await _cacheService.clearCache();
  }
  
  /// Get cache statistics
  Future<CacheStats> getCacheStats() async {
    return await _cacheService.getStats();
  }
  
  /// Clean up resources
  Future<void> dispose() async {
    // Dispose providers in parallel for faster cleanup
    final disposeFutures = _providers.map((provider) async {
      try {
        await provider.dispose();
      } catch (e) {
        print('Error disposing provider ${provider.providerId}: $e');
      }
    });
    
    await Future.wait(disposeFutures);
    
    try {
      await _cacheService.dispose();
    } catch (e) {
      print('Error disposing cache service: $e');
    }
  }
  
  /// Try cycling dictionary lookup for single words
  Future<CyclingDictionaryLookupResult> _tryCyclingDictionaryLookup(
    String word, 
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check if required language pack is available
      final packId = '$sourceLanguage-$targetLanguage';
      final isPackAvailable = await _isDictionaryPackAvailable(packId);
      
      if (!isPackAvailable) {
        stopwatch.stop();
        return CyclingDictionaryLookupResult(
          query: word,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          latencyMs: stopwatch.elapsedMilliseconds,
          error: 'Language pack not installed: $packId',
          missingLanguagePack: packId,
        );
      }
      
      // Try source → target lookup first
      final sourceMeanings = await _dictionaryService.lookupSourceMeanings(
        word,
        sourceLanguage,
        targetLanguage,
      );
      
      if (sourceMeanings.hasResults) {
        stopwatch.stop();
        return CyclingDictionaryLookupResult(
          query: word,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          sourceMeanings: sourceMeanings,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
      
      // Try target → source reverse lookup
      final reverseTranslations = await _dictionaryService.lookupTargetTranslations(
        word,
        sourceLanguage,
        targetLanguage,
      );
      
      stopwatch.stop();
      
      return CyclingDictionaryLookupResult(
        query: word,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        reverseTranslations: reverseTranslations,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
      
    } catch (e) {
      stopwatch.stop();
      return CyclingDictionaryLookupResult(
        query: word,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }
  
  bool _isSingleWord(String text) {
    final trimmed = text.trim();
    return !trimmed.contains(' ') && 
           !trimmed.contains('\n') && 
           !trimmed.contains('\t') &&
           trimmed.isNotEmpty &&
           trimmed.length < 50; // Reasonable word length limit
  }
  
  /// Check if a dictionary language pack is available
  Future<bool> _isDictionaryPackAvailable(String packId) async {
    try {
      // Quick check: try to get stats for this language pair
      final langParts = packId.split('-');
      if (langParts.length != 2) return false;
      
      final stats = await _dictionaryService.getStats(langParts[0], langParts[1]);
      return stats['totalWordGroups']! > 0;
    } catch (e) {
      // Any error means the pack is not available
      return false;
    }
  }
  
  /// Check if a provider supports model download
  bool hasModelDownload(String providerId) {
    try {
      final provider = _providers.firstWhere((p) => p.providerId == providerId);
      return provider is MlKitTranslationProvider;
    } catch (e) {
      return false;
    }
  }
  
  /// Download models for a specific provider and language pair
  Future<void> downloadModel(String providerId, String sourceLanguage, String targetLanguage) async {
    try {
      final provider = _providers.firstWhere((p) => p.providerId == providerId);
      
      if (provider is MlKitTranslationProvider) {
        // Attempt to trigger model download by trying a translation
        await provider.translateText(
          text: 'test',
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
      } else {
        throw Exception('Provider $providerId does not support model downloads');
      }
    } catch (e) {
      throw Exception('Failed to download model for $providerId: $e');
    }
  }
}

class ProviderStatus {
  final String providerId;
  final String providerName;
  final bool isAvailable;
  final bool isOfflineCapable;
  final String? additionalInfo;
  
  const ProviderStatus({
    required this.providerId,
    required this.providerName,
    required this.isAvailable,
    required this.isOfflineCapable,
    this.additionalInfo,
  });
}

// Result classes
class CyclingDictionaryLookupResult {
  final String query;
  final String sourceLanguage;
  final String targetLanguage;
  final dynamic sourceMeanings; // MeaningLookupResult
  final dynamic reverseTranslations; // ReverseLookupResult
  final int latencyMs;
  final String? error;
  final String? missingLanguagePack;
  
  const CyclingDictionaryLookupResult({
    required this.query,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.sourceMeanings,
    this.reverseTranslations,
    required this.latencyMs,
    this.error,
    this.missingLanguagePack,
  });
  
  bool get hasResults => 
    (sourceMeanings?.hasResults ?? false) || 
    (reverseTranslations?.hasResults ?? false);
}

class CacheStats {
  final int totalEntries;
  final int totalSize;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;
  
  const CacheStats({
    required this.totalEntries,
    required this.totalSize,
    this.oldestEntry,
    this.newestEntry,
  });
}