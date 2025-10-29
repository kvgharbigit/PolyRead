// Dictionary Management Service
// Handles dictionary availability, initialization, and user prompting

import 'package:drift/drift.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/services/dictionary_loader_service.dart';
import 'package:polyread/features/translation/services/drift_dictionary_service.dart';

class DictionaryManagementService {
  final AppDatabase _database;
  final DictionaryLoaderService _loaderService;
  final DriftDictionaryService _dictionaryService;
  
  DictionaryManagementService(this._database) 
    : _loaderService = DictionaryLoaderService(_database),
      _dictionaryService = DriftDictionaryService(_database);
  
  /// Check if dictionary is available for a language pair
  Future<bool> isDictionaryAvailable({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final stats = await _dictionaryService.getStats();
      
      // Check for exact language pair or individual languages
      final languagePairs = [
        '$sourceLanguage-$targetLanguage',
        '$targetLanguage-$sourceLanguage',
        sourceLanguage,
        targetLanguage,
      ];
      
      for (final pair in languagePairs) {
        if (stats.languageStats.containsKey(pair) && 
            stats.getLanguageTotal(pair) > 0) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('DictionaryManagement: Error checking availability: $e');
      return false;
    }
  }
  
  /// Get dictionary availability status with details
  Future<DictionaryAvailabilityStatus> getAvailabilityStatus({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final stats = await _dictionaryService.getStats();
      
      if (stats.totalEntries == 0) {
        return DictionaryAvailabilityStatus(
          isAvailable: false,
          totalEntries: 0,
          message: 'No dictionary data loaded. Download language packs from Settings.',
          recommendedAction: DictionaryAction.downloadLanguagePack,
        );
      }
      
      final languagePairs = [
        '$sourceLanguage-$targetLanguage',
        '$targetLanguage-$sourceLanguage',
        sourceLanguage,
        targetLanguage,
      ];
      
      int relevantEntries = 0;
      final availablePairs = <String>[];
      
      for (final pair in languagePairs) {
        if (stats.languageStats.containsKey(pair)) {
          final count = stats.getLanguageTotal(pair);
          relevantEntries += count;
          if (count > 0) {
            availablePairs.add(pair);
          }
        }
      }
      
      if (relevantEntries == 0) {
        return DictionaryAvailabilityStatus(
          isAvailable: false,
          totalEntries: stats.totalEntries,
          message: 'No dictionary entries found for $sourceLanguage-$targetLanguage. Available languages: ${stats.availableLanguages.join(", ")}',
          recommendedAction: DictionaryAction.downloadLanguagePack,
          availableLanguages: stats.availableLanguages,
        );
      }
      
      return DictionaryAvailabilityStatus(
        isAvailable: true,
        totalEntries: stats.totalEntries,
        relevantEntries: relevantEntries,
        message: 'Dictionary available with $relevantEntries entries for language pair',
        recommendedAction: DictionaryAction.none,
        availablePairs: availablePairs,
        availableLanguages: stats.availableLanguages,
      );
      
    } catch (e) {
      return DictionaryAvailabilityStatus(
        isAvailable: false,
        totalEntries: 0,
        message: 'Error checking dictionary status: $e',
        recommendedAction: DictionaryAction.troubleshoot,
      );
    }
  }
  
  /// Initialize dictionary with real downloaded data from language packs
  Future<DictionaryInitializationResult> initializeRealDictionary({
    bool forceReload = false,
    Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Checking for available language packs...');
      
      // Check if any dictionary language packs are already installed
      final dictionaryPacks = _database.select(_database.languagePacks)
        ..where((pack) => pack.isInstalled.equals(true) & pack.packType.equals('dictionary'));
      
      final combinedPacks = _database.select(_database.languagePacks)
        ..where((pack) => pack.isInstalled.equals(true) & pack.packType.equals('combined'));
      
      final dictPackList = await dictionaryPacks.get();
      final combPackList = await combinedPacks.get();
      
      final packList = [...dictPackList, ...combPackList];
      
      if (packList.isNotEmpty) {
        onProgress?.call('Found ${packList.length} installed language pack(s), integrating...');
        
        // Language pack integration service is available if needed for future integration
        
        // Check if dictionary data is already loaded
        final stats = await _dictionaryService.getStats();
        
        if (stats.totalEntries > 0) {
          return DictionaryInitializationResult(
            success: true,
            entriesLoaded: stats.totalEntries,
            message: 'Dictionary loaded from language packs: ${stats.totalEntries} entries',
          );
        } else {
          // Language packs are installed but dictionary data not loaded
          onProgress?.call('Language packs found but dictionary not loaded. Dictionary data will be available when language packs are properly installed via Settings.');
          
          return DictionaryInitializationResult(
            success: false,
            entriesLoaded: 0,
            message: 'Language packs found but dictionary not loaded. Please go to Settings → Language Packs and reinstall your dictionary pack to load the data.',
          );
        }
      }
      
      // No language packs installed - guide user to download them
      return DictionaryInitializationResult(
        success: false,
        entriesLoaded: 0,
        message: 'No dictionary language packs found. Please go to Settings → Language Packs to download dictionaries for your language pair.',
      );
    } catch (e) {
      return DictionaryInitializationResult(
        success: false,
        entriesLoaded: 0,
        message: 'Failed to initialize dictionary: $e',
        error: e.toString(),
      );
    }
  }
  
  /// Test dictionary functionality
  Future<DictionaryTestResult> testDictionary({
    String sourceLanguage = 'en',
    String targetLanguage = 'es',
  }) async {
    try {
      final testWords = ['hello', 'for', 'the', 'and'];
      final results = <String, int>{};
      
      for (final word in testWords) {
        final entries = await _dictionaryService.lookupWord(
          word: word,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        results[word] = entries.length;
      }
      
      final totalFound = results.values.fold(0, (sum, count) => sum + count);
      
      return DictionaryTestResult(
        success: totalFound > 0,
        wordResults: results,
        message: totalFound > 0 
          ? 'Dictionary test passed: $totalFound results found'
          : 'Dictionary test failed: No results found for test words',
      );
    } catch (e) {
      return DictionaryTestResult(
        success: false,
        wordResults: {},
        message: 'Dictionary test failed with error: $e',
        error: e.toString(),
      );
    }
  }
  
  /// Force reload dictionary data (for troubleshooting)
  Future<DictionaryInitializationResult> forceReloadDictionary() async {
    return await initializeRealDictionary(forceReload: true);
  }
  
  /// Get comprehensive dictionary health report
  Future<DictionaryHealthReport> getHealthReport() async {
    try {
      final stats = await _dictionaryService.getStats();
      final testResult = await testDictionary();
      
      final issues = <String>[];
      final recommendations = <String>[];
      
      if (stats.totalEntries == 0) {
        issues.add('Dictionary database is empty');
        recommendations.add('Download language packs from Settings → Language Packs');
      }
      
      if (!testResult.success) {
        issues.add('Dictionary lookup tests failed');
        recommendations.add('Check database integrity and reload dictionary data');
      }
      
      if (stats.availableLanguages.isEmpty) {
        issues.add('No language pairs available');
        recommendations.add('Load dictionary data for required language pairs');
      }
      
      return DictionaryHealthReport(
        isHealthy: issues.isEmpty,
        totalEntries: stats.totalEntries,
        availableLanguages: stats.availableLanguages,
        issues: issues,
        recommendations: recommendations,
        testResult: testResult,
        stats: stats,
      );
    } catch (e) {
      return DictionaryHealthReport(
        isHealthy: false,
        totalEntries: 0,
        availableLanguages: [],
        issues: ['Failed to generate health report: $e'],
        recommendations: ['Check database connection and schema'],
        testResult: DictionaryTestResult(
          success: false,
          wordResults: {},
          message: 'Health check failed',
          error: e.toString(),
        ),
        stats: const DictionaryStats(totalEntries: 0, languageStats: {}),
      );
    }
  }
}

// Data classes for dictionary management

class DictionaryAvailabilityStatus {
  final bool isAvailable;
  final int totalEntries;
  final int? relevantEntries;
  final String message;
  final DictionaryAction recommendedAction;
  final List<String>? availablePairs;
  final List<String>? availableLanguages;
  
  const DictionaryAvailabilityStatus({
    required this.isAvailable,
    required this.totalEntries,
    this.relevantEntries,
    required this.message,
    required this.recommendedAction,
    this.availablePairs,
    this.availableLanguages,
  });
}

class DictionaryInitializationResult {
  final bool success;
  final int entriesLoaded;
  final String message;
  final String? error;
  
  const DictionaryInitializationResult({
    required this.success,
    required this.entriesLoaded,
    required this.message,
    this.error,
  });
}

class DictionaryTestResult {
  final bool success;
  final Map<String, int> wordResults;
  final String message;
  final String? error;
  
  const DictionaryTestResult({
    required this.success,
    required this.wordResults,
    required this.message,
    this.error,
  });
}

class DictionaryHealthReport {
  final bool isHealthy;
  final int totalEntries;
  final List<String> availableLanguages;
  final List<String> issues;
  final List<String> recommendations;
  final DictionaryTestResult testResult;
  final DictionaryStats stats;
  
  const DictionaryHealthReport({
    required this.isHealthy,
    required this.totalEntries,
    required this.availableLanguages,
    required this.issues,
    required this.recommendations,
    required this.testResult,
    required this.stats,
  });
}

enum DictionaryAction {
  none,
  downloadLanguagePack,
  troubleshoot,
}