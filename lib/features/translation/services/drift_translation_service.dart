// Drift Translation Service - Direct integration with Drift database
// Enhanced translation service that works directly with AppDatabase

import 'package:flutter/material.dart';
import '../providers/translation_provider.dart';
import '../providers/ml_kit_provider.dart';
import '../providers/server_provider.dart';
import '../widgets/translation_setup_dialog.dart';
import 'drift_dictionary_service.dart';
import '../models/dictionary_entry.dart';
import '../models/translation_request.dart';
import '../models/translation_response.dart' as response_model;
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/services/dictionary_management_service.dart';

class DriftTranslationService {
  final AppDatabase _database;
  final DriftDictionaryService _dictionaryService;
  final DictionaryManagementService _dictionaryManagementService;
  final List<TranslationProvider> _providers;
  
  late final MlKitTranslationProvider _mlKitProvider;
  late final ServerTranslationProvider _serverProvider;
  
  // Context for showing dialogs - set by the UI when needed
  BuildContext? _context;
  
  // Track if setup dialog was already shown to prevent repeated prompts
  bool _setupDialogShown = false;
  
  DriftTranslationService({
    required AppDatabase database,
  }) : _database = database,
       _dictionaryService = DriftDictionaryService(database),
       _dictionaryManagementService = DictionaryManagementService(database),
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
  
  /// Set the BuildContext for showing dialogs
  void setContext(BuildContext? context) {
    _context = context;
  }
  
  /// Reset the setup dialog state (call when user downloads language packs)
  void resetSetupDialogState() {
    _setupDialogShown = false;
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
    
    // TODO: Implement cache service with Drift
    // if (useCache) {
    //   final cachedResult = await _cacheService.getCachedTranslation(request);
    //   if (cachedResult != null) {
    //     return TranslationResponse.fromCached(cachedResult);
    //   }
    // }
    
    // Step 1: Check translation setup and prompt if needed (only once per session)
    final setupNeeded = await _checkTranslationSetup(sourceLanguage, targetLanguage);
    if (setupNeeded && !_setupDialogShown && _context != null && _context!.mounted) {
      print('DriftTranslation: Translation setup needed, showing setup dialog...');
      _setupDialogShown = true; // Mark as shown to prevent repeated prompts
      
      final setupResult = await showTranslationSetupDialog(
        context: _context!,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        dictionaryService: _dictionaryManagementService,
        mlKitProvider: _mlKitProvider,
      );
      
      if (setupResult?.completed != true) {
        print('DriftTranslation: User skipped setup, proceeding with available providers');
      } else {
        print('DriftTranslation: Setup completed, dictionary: ${setupResult!.dictionaryInitialized}, ML Kit: ${setupResult.mlKitDownloaded}');
        // Note: Dictionary and ML Kit availability will be re-checked in subsequent steps
      }
    } else if (setupNeeded && _setupDialogShown) {
      print('DriftTranslation: Setup needed but dialog already shown this session, proceeding silently');
    }
    
    // Step 2: Dictionary lookup (for single words)
    if (_isSingleWord(text)) {
      print('DriftTranslation: "$text" IS a single word, checking dictionary...');
      try {
        final dictionaryAvailable = await _dictionaryManagementService.isDictionaryAvailable(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        print('DriftTranslation: Dictionary available for $sourceLanguage->$targetLanguage: $dictionaryAvailable');
        
        final dictionaryResult = await _tryDictionaryLookup(
          text, 
          sourceLanguage,
          targetLanguage,
        );
        
        print('DriftTranslation: Dictionary lookup result: ${dictionaryResult.entries.length} entries found');
        
        if (dictionaryResult.hasResults) {
          print('DriftTranslation: Dictionary found results, creating response');
          final response = response_model.TranslationResponse.fromDictionary(
            request: request,
            dictionaryResult: dictionaryResult,
          );
          
          print('DriftTranslation: Dictionary response: ${response.translatedText}');
          return response;
        } else {
          print('DriftTranslation: No dictionary results found');
          
          // Dictionary not available - setup dialog should have handled this already
          print('DriftTranslation: No dictionary results found, setup was already shown');
        }
      } catch (e) {
        print('DriftTranslation: Error during dictionary lookup: $e');
        // Continue to ML Kit/Server fallback
      }
    } else {
      print('DriftTranslation: "$text" is not a single word, skipping dictionary');
    }
    
    // Step 3: ML Kit (offline, preferred for mobile)
    print('DriftTranslation: Checking ML Kit availability...');
    try {
      if (await _mlKitProvider.isAvailable) {
        print('DriftTranslation: ML Kit is available');
        final mlKitSupported = await _mlKitProvider.supportsLanguagePair(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        print('DriftTranslation: ML Kit supports ${sourceLanguage}->${targetLanguage}: $mlKitSupported');
        
        if (mlKitSupported) {
          // Check if models are downloaded
          final modelsAvailable = await _mlKitProvider.areModelsDownloaded(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );
          
          print('DriftTranslation: ML Kit models available: $modelsAvailable');
          
          if (modelsAvailable) {
            print('DriftTranslation: Translating with ML Kit...');
            final mlKitResult = await _mlKitProvider.translateText(
              text: text,
              sourceLanguage: sourceLanguage,
              targetLanguage: targetLanguage,
            );
            
            print('DriftTranslation: ML Kit result success: ${mlKitResult.success}');
            
            if (mlKitResult.success) {
              final response = response_model.TranslationResponse.fromMlKit(
                request: request,
                mlKitResult: response_model.MlKitResult(
                  translatedText: mlKitResult.translatedText,
                  providerId: mlKitResult.providerId,
                  latencyMs: mlKitResult.latencyMs,
                  success: mlKitResult.success,
                  error: mlKitResult.error,
                ),
              );
              
              print('DriftTranslation: ML Kit response: ${response.translatedText}');
              return response;
            }
          }
        }
      } else {
        print('DriftTranslation: ML Kit not available');
      }
    } catch (e) {
      print('DriftTranslation: Error during ML Kit translation: $e');
      // Continue to server fallback
    }
    
    // Step 4: Google Translate (online fallback)
    try {
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
            final response = response_model.TranslationResponse.fromServer(
              request: request,
              serverResult: response_model.ServerResult(
                translatedText: serverResult.translatedText,
                providerId: serverResult.providerId,
                latencyMs: serverResult.latencyMs,
                success: serverResult.success,
                error: serverResult.error,
              ),
            );
            
            // TODO: Cache server results
            // if (useCache) {
            //   await _cacheService.cacheTranslation(request, response);
            // }
            
            return response;
          }
        }
      }
    } catch (e) {
      print('DriftTranslation: Error during server translation: $e');
      // Continue to final error response
    }
    
    // All providers failed
    print('DriftTranslation: All providers failed, returning error');
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
  
  /// Check if translation setup is needed (dictionary or ML Kit models missing)
  Future<bool> _checkTranslationSetup(String sourceLanguage, String targetLanguage) async {
    try {
      // Check dictionary availability
      final dictionaryAvailable = await _dictionaryManagementService.isDictionaryAvailable(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      
      // Check ML Kit model availability for supported language pairs
      bool mlKitSetupNeeded = false;
      if (await _mlKitProvider.isAvailable) {
        final mlKitSupported = await _mlKitProvider.supportsLanguagePair(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        if (mlKitSupported) {
          final modelsAvailable = await _mlKitProvider.areModelsDownloaded(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );
          mlKitSetupNeeded = !modelsAvailable;
        }
      }
      
      final setupNeeded = !dictionaryAvailable || mlKitSetupNeeded;
      print('DriftTranslation: Setup needed - Dictionary: ${!dictionaryAvailable}, ML Kit: $mlKitSetupNeeded, Total: $setupNeeded');
      
      return setupNeeded;
    } catch (e) {
      print('DriftTranslation: Error checking setup status: $e');
      return false; // Fail gracefully
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

