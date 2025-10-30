// Centralized Translation Service - Coordinates between dictionary and ML providers
// Implements fallback strategy: Dictionary → ML Kit → Google Translate

import '../providers/translation_provider.dart';
import '../providers/ml_kit_provider.dart';
import '../providers/server_provider.dart';
import '../services/drift_dictionary_service.dart';
import '../services/translation_cache_service.dart';
import '../models/dictionary_entry.dart';
import '../models/translation_request.dart';
import '../models/translation_response.dart' as response_model;

class TranslationService {
  final DriftDictionaryService _dictionaryService;
  final TranslationCacheService _cacheService;
  final List<TranslationProvider> _providers;
  
  late final MlKitTranslationProvider _mlKitProvider;
  late final ServerTranslationProvider _serverProvider;
  
  TranslationService({
    required DriftDictionaryService dictionaryService,
    required TranslationCacheService cacheService,
  }) : _dictionaryService = dictionaryService,
       _cacheService = cacheService,
       _providers = [] {
    _mlKitProvider = MlKitTranslationProvider();
    _serverProvider = ServerTranslationProvider();
    _providers.addAll([_mlKitProvider, _serverProvider]);
  }
  
  /// Initialize all translation providers
  Future<void> initialize() async {
    // DriftDictionaryService doesn't need initialization - database is already set up
    await _cacheService.initialize();
    
    for (final provider in _providers) {
      try {
        await provider.initialize();
      } catch (e) {
        // Log error but continue with other providers
        print('Failed to initialize provider ${provider.providerId}: $e');
      }
    }
  }
  
  /// Main translation method with fallback strategy
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
      final cachedResult = await _cacheService.getCachedTranslation(request);
      if (cachedResult != null) {
        return response_model.TranslationResponse.fromCached(cachedResult);
      }
    }
    
    // Step 1: Dictionary lookup (for single words)
    if (_isSingleWord(text)) {
      final dictionaryResult = await _tryDictionaryLookup(
        text, 
        sourceLanguage,
        targetLanguage,
      );
      
      if (dictionaryResult.hasResults) {
        final response = response_model.TranslationResponse.fromDictionary(
          request: request,
          dictionaryResult: dictionaryResult,
        );
        
        // Cache dictionary results
        if (useCache) {
          await _cacheService.cacheTranslation(request, response);
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
              await _cacheService.cacheTranslation(request, response);
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
    
    // Step 3: Google Translate (online fallback)
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
            await _cacheService.cacheTranslation(request, response);
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
    
    // Dictionary status
    final dictionaryStats = await _dictionaryService.getStats();
    statuses.add(ProviderStatus(
      providerId: 'dictionary',
      providerName: 'Dictionary Lookup',
      isAvailable: dictionaryStats.totalEntries > 0,
      isOfflineCapable: true,
      additionalInfo: '${dictionaryStats.totalEntries} entries',
    ));
    
    // ML providers status
    for (final provider in _providers) {
      final isAvailable = await provider.isAvailable;
      String? additionalInfo;
      
      if (provider is MlKitTranslationProvider) {
        // Could add model download status here
        additionalInfo = isAvailable ? 'Ready' : 'Not available';
      } else if (provider is ServerTranslationProvider) {
        additionalInfo = isAvailable ? 'Online' : 'Offline';
      }
      
      statuses.add(ProviderStatus(
        providerId: provider.providerId,
        providerName: provider.providerName,
        isAvailable: isAvailable,
        isOfflineCapable: provider.isOfflineCapable,
        additionalInfo: additionalInfo,
      ));
    }
    
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
    
    for (final provider in _providers) {
      try {
        final pairs = await provider.getSupportedLanguagePairs();
        allPairs[provider.providerId] = pairs;
      } catch (e) {
        allPairs[provider.providerId] = [];
      }
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
    for (final provider in _providers) {
      await provider.dispose();
    }
    await _cacheService.dispose();
  }
  
  Future<DictionaryLookupResult> _tryDictionaryLookup(
    String word, 
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final entries = await _dictionaryService.lookupWord(
        word: word,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage, // Use proper target language for bidirectional lookup
        limit: 5,
      );
      
      stopwatch.stop();
      
      return DictionaryLookupResult(
        query: word,
        language: '$sourceLanguage-$targetLanguage',
        entries: entries,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return DictionaryLookupResult(
        query: word,
        language: '$sourceLanguage-$targetLanguage',
        entries: [],
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
  
  bool _isSingleWord(String text) {
    final trimmed = text.trim();
    return !trimmed.contains(' ') && 
           !trimmed.contains('\n') && 
           !trimmed.contains('\t') &&
           trimmed.length > 0 &&
           trimmed.length < 50; // Reasonable word length limit
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

// Import needed models
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