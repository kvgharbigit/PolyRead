// Drift Translation Service - Direct integration with Drift database
// Enhanced translation service that works directly with AppDatabase

import '../providers/translation_provider.dart';
import '../providers/ml_kit_provider.dart';
import '../providers/server_provider.dart';
import 'drift_dictionary_service.dart';
import '../models/dictionary_entry.dart' as model;
import '../models/translation_request.dart';
import 'package:polyread/core/database/app_database.dart';

class DriftTranslationService {
  final DriftDictionaryService _dictionaryService;
  final List<TranslationProvider> _providers;
  
  late final MlKitTranslationProvider _mlKitProvider;
  late final ServerTranslationProvider _serverProvider;
  
  DriftTranslationService({
    required AppDatabase database,
  }) : _dictionaryService = DriftDictionaryService(database),
       _providers = [] {
    _mlKitProvider = MlKitTranslationProvider();
    _serverProvider = ServerTranslationProvider();
    _providers.addAll([_mlKitProvider, _serverProvider]);
  }
  
  /// Initialize all translation providers
  Future<void> initialize() async {
    // Dictionary service doesn't need initialization with Drift
    // as tables are created during database setup
    
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
  Future<TranslationResponse> translateText({
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
    
    // TODO: Implement cache service with Drift
    // if (useCache) {
    //   final cachedResult = await _cacheService.getCachedTranslation(request);
    //   if (cachedResult != null) {
    //     return TranslationResponse.fromCached(cachedResult);
    //   }
    // }
    
    // Step 1: Dictionary lookup (for single words)
    if (_isSingleWord(text)) {
      final dictionaryResult = await _tryDictionaryLookup(
        text, 
        sourceLanguage,
        targetLanguage,
      );
      
      if (dictionaryResult.hasResults) {
        final response = TranslationResponse.fromDictionary(
          request: request,
          dictionaryResult: dictionaryResult,
        );
        
        // TODO: Cache dictionary results
        // if (useCache) {
        //   await _cacheService.cacheTranslation(request, response);
        // }
        
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
          final mlKitResult = await _mlKitProvider.translateText(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );
          
          if (mlKitResult.success) {
            final response = TranslationResponse.fromProvider(
              request: request,
              result: mlKitResult,
            );
            
            // TODO: Cache ML Kit results
            // if (useCache) {
            //   await _cacheService.cacheTranslation(request, response);
            // }
            
            return response;
          }
        } else {
          // Models not downloaded - could trigger download here
          return TranslationResponse.modelsNotDownloaded(
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
        final serverResult = await _serverProvider.translateText(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        if (serverResult.success) {
          final response = TranslationResponse.fromProvider(
            request: request,
            result: serverResult,
          );
          
          // TODO: Cache server results
          // if (useCache) {
          //   await _cacheService.cacheTranslation(request, response);
          // }
          
          return response;
        }
      }
    }
    
    // All providers failed
    return TranslationResponse.error(
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
  
  /// Clean up resources
  Future<void> dispose() async {
    for (final provider in _providers) {
      await provider.dispose();
    }
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
        targetLanguage: targetLanguage,
        limit: 5,
      );
      
      stopwatch.stop();
      
      return DictionaryLookupResult(
        query: word,
        language: sourceLanguage,
        entries: entries,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return DictionaryLookupResult(
        query: word,
        language: sourceLanguage,
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

// Re-export required classes from the original translation service
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

class TranslationResponse {
  final TranslationRequest request;
  final String? translatedText;
  final List<model.DictionaryEntry>? dictionaryEntries;
  final String? providerId;
  final int latencyMs;
  final bool success;
  final String? error;
  final TranslationSource source;
  final bool fromCache;
  
  const TranslationResponse({
    required this.request,
    this.translatedText,
    this.dictionaryEntries,
    this.providerId,
    required this.latencyMs,
    required this.success,
    this.error,
    required this.source,
    this.fromCache = false,
  });
  
  factory TranslationResponse.fromDictionary({
    required TranslationRequest request,
    required DictionaryLookupResult dictionaryResult,
  }) {
    return TranslationResponse(
      request: request,
      dictionaryEntries: dictionaryResult.entries,
      latencyMs: dictionaryResult.latencyMs,
      success: dictionaryResult.hasResults,
      source: TranslationSource.dictionary,
      providerId: 'dictionary',
    );
  }
  
  factory TranslationResponse.fromProvider({
    required TranslationRequest request,
    required TranslationResult result,
  }) {
    return TranslationResponse(
      request: request,
      translatedText: result.translatedText,
      providerId: result.providerId,
      latencyMs: result.latencyMs,
      success: result.success,
      error: result.error,
      source: result.providerId == 'ml_kit' 
          ? TranslationSource.mlKit 
          : TranslationSource.server,
    );
  }
  
  factory TranslationResponse.fromCached(TranslationResponse cached) {
    return TranslationResponse(
      request: cached.request,
      translatedText: cached.translatedText,
      dictionaryEntries: cached.dictionaryEntries,
      providerId: cached.providerId,
      latencyMs: 0, // Cache lookups are essentially instant
      success: cached.success,
      error: cached.error,
      source: cached.source,
      fromCache: true,
    );
  }
  
  factory TranslationResponse.modelsNotDownloaded({
    required TranslationRequest request,
    required String providerId,
  }) {
    return TranslationResponse(
      request: request,
      providerId: providerId,
      latencyMs: 0,
      success: false,
      error: 'Translation models not downloaded',
      source: TranslationSource.mlKit,
    );
  }
  
  factory TranslationResponse.error({
    required TranslationRequest request,
    required String error,
  }) {
    return TranslationResponse(
      request: request,
      latencyMs: 0,
      success: false,
      error: error,
      source: TranslationSource.none,
    );
  }
}

enum TranslationSource {
  dictionary,
  mlKit,
  server,
  none,
}

class DictionaryLookupResult {
  final String query;
  final String language;
  final List<model.DictionaryEntry> entries;
  final int latencyMs;
  
  const DictionaryLookupResult({
    required this.query,
    required this.language,
    required this.entries,
    required this.latencyMs,
  });
  
  bool get hasResults => entries.isNotEmpty;
}