// Combined Language Pack Service - Downloads dictionary + ML Kit models together
// Simplifies user experience by bundling both resources in one action

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/dictionary_management_service.dart';
import '../../../core/services/dictionary_loader_service.dart';
import '../../../core/services/language_pack_integration_service.dart';
import '../../translation/providers/ml_kit_provider.dart';
import '../models/language_pack_manifest.dart';
import '../models/download_progress.dart';
import '../repositories/github_releases_repo.dart';
import 'drift_language_pack_service.dart' hide LanguagePackException;
import 'bidirectional_dictionary_service.dart';
import '../models/bidirectional_dictionary_entry.dart';
import 'zip_extraction_service.dart';
import 'sqlite_import_service.dart';

class CombinedLanguagePackService {
  final AppDatabase _database;
  final DriftLanguagePackService _packService;
  final BidirectionalDictionaryService _bidirectionalService;
  final DictionaryManagementService _dictionaryService;
  final DictionaryLoaderService _dictionaryLoader;
  final LanguagePackIntegrationService _integrationService;
  final MlKitTranslationProvider _mlKitProvider;
  final GitHubReleasesRepository _repository;
  
  final Map<String, DownloadProgress> _activeDownloads = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final StreamController<DownloadProgress> _progressController = StreamController.broadcast();
  
  CombinedLanguagePackService({
    required AppDatabase database,
    required GitHubReleasesRepository repository,
  }) : _database = database,
       _packService = DriftLanguagePackService(database),
       _bidirectionalService = BidirectionalDictionaryService(database),
       _dictionaryService = DictionaryManagementService(database),
       _dictionaryLoader = DictionaryLoaderService(database),
       _integrationService = LanguagePackIntegrationService(
         database: database,
         dictionaryLoader: DictionaryLoaderService(database),
       ),
       _mlKitProvider = MlKitTranslationProvider(),
       _repository = repository;
  
  /// Stream of download progress updates
  Stream<DownloadProgress> get progressStream => _progressController.stream;
  
  /// Get current download progress
  DownloadProgress? getDownloadProgress(String packId) => _activeDownloads[packId];
  
  /// Get all active downloads
  List<DownloadProgress> get activeDownloads => _activeDownloads.values.toList();
  
  /// Clear a failed download from the active downloads list
  void clearFailedDownload(String packId) {
    final download = _activeDownloads[packId];
    if (download != null && download.isFailed) {
      _activeDownloads.remove(packId);
      _cancelTokens.remove(packId);
      print('CombinedLanguagePackService: Cleared failed download for $packId');
    }
  }
  
  /// Clear any stale download state for a pack (force cleanup)
  void clearAnyDownloadState(String packId) {
    print('CombinedLanguagePackService: Force clearing any download state for $packId');
    if (_activeDownloads.containsKey(packId)) {
      _activeDownloads.remove(packId);
      print('CombinedLanguagePackService: Removed active download for $packId');
    }
    if (_cancelTokens.containsKey(packId)) {
      _cancelTokens[packId]?.cancel('Forced cleanup');
      _cancelTokens.remove(packId);
      print('CombinedLanguagePackService: Cancelled and removed cancel token for $packId');
    }
  }
  
  /// Check and repair any broken installations on startup
  Future<void> validateAndRepairOnStartup() async {
    try {
      print('CombinedLanguagePackService: Checking for broken installations...');
      final brokenPacks = await _packService.detectBrokenPacks();
      
      if (brokenPacks.isNotEmpty) {
        print('CombinedLanguagePackService: Found ${brokenPacks.length} broken packs: $brokenPacks');
        
        // Auto-repair broken packs by clearing their installation status
        for (final packId in brokenPacks) {
          try {
            print('CombinedLanguagePackService: Auto-repairing broken pack: $packId');
            
            // Mark as not installed so user can reinstall cleanly
            final updateCount = await (_database.update(_database.languagePacks)
              ..where((pack) => pack.packId.equals(packId)))
              .write(LanguagePacksCompanion(
                isInstalled: Value(false),
                isActive: Value(false),
              ));
              
            if (updateCount > 0) {
              print('CombinedLanguagePackService: Successfully marked $packId as not installed for clean reinstall');
            } else {
              print('CombinedLanguagePackService: Warning: No pack found with ID $packId to repair');
            }
          } catch (e) {
            print('CombinedLanguagePackService: Failed to auto-repair $packId: $e');
            // Continue with other packs even if one fails
          }
        }
      } else {
        print('CombinedLanguagePackService: No broken installations detected');
      }
    } catch (e) {
      print('CombinedLanguagePackService: Error during startup validation: $e');
    }
  }

  /// Install a complete language pack (dictionary + ML Kit models)
  Future<void> installLanguagePack({
    required String sourceLanguage,
    required String targetLanguage,
    bool wifiOnly = true,
    Function(String message)? onProgress,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    
    print('');
    print('********************************');
    print('CombinedLanguagePackService.installLanguagePack: ENTRY (Bidirectional)');
    print('CombinedLanguagePackService: Source: $sourceLanguage');
    print('CombinedLanguagePackService: Target: $targetLanguage');
    print('CombinedLanguagePackService: Bidirectional Pack ID: $packId');
    print('CombinedLanguagePackService: WiFi only: $wifiOnly');
    print('CombinedLanguagePackService: onProgress callback provided: ${onProgress != null}');
    print('********************************');
    
    // Check if bidirectional pack is already installed
    print('');
    print('CombinedLanguagePackService: 🔍 CHECKING BIDIRECTIONAL PACK INSTALLATION STATUS...');
    
    try {
      final isInstalled = await _packService.isPackInstalled(packId);
      print('CombinedLanguagePackService: Bidirectional pack ($packId) installed: $isInstalled');
      
      if (isInstalled) {
        print('CombinedLanguagePackService: ⚠️ Pack already installed - FORCING REINSTALL');
        print('CombinedLanguagePackService: Removing existing installation first...');
        
        try {
          await removeLanguagePack(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );
          print('CombinedLanguagePackService: ✅ Existing installation removed successfully');
        } catch (e) {
          print('CombinedLanguagePackService: ⚠️ Error removing existing installation: $e');
          print('CombinedLanguagePackService: Continuing with overwrite installation...');
        }
      }
      
      print('CombinedLanguagePackService: ✅ Ready to proceed with installation');
    } catch (e) {
      print('CombinedLanguagePackService: ❌ Error checking installation status: $e');
      print('CombinedLanguagePackService: Error type: ${e.runtimeType}');
      print('CombinedLanguagePackService: Continuing with installation anyway...');
    }
    
    // Check if download is in progress for either direction
    print('');
    print('CombinedLanguagePackService: 🔍 CHECKING ACTIVE DOWNLOADS...');
    print('CombinedLanguagePackService: Current active downloads: ${_activeDownloads.keys.toList()}');
    print('CombinedLanguagePackService: Total active downloads: ${_activeDownloads.length}');
    
    if (_activeDownloads.containsKey(packId)) {
      print('CombinedLanguagePackService: ⚠️ Found stale download state for ($packId)');
      print('CombinedLanguagePackService: 🧹 Clearing stale state and proceeding...');
      clearAnyDownloadState(packId);
    }
    
    print('CombinedLanguagePackService: ✅ No active downloads for this language pair');
    
    // Initialize progress tracking
    print('');
    print('CombinedLanguagePackService: 📊 INITIALIZING PROGRESS TRACKING...');
    
    // Get actual file size from GitHub manifest
    print('CombinedLanguagePackService: Fetching actual file size from GitHub...');
    int actualTotalBytes = 50 * 1024 * 1024; // fallback estimate
    try {
      final manifests = await _repository.getAvailableLanguagePacks();
      final manifest = manifests.firstWhere(
        (m) => m.id == packId,
        orElse: () => throw Exception('Pack not found in GitHub'),
      );
      actualTotalBytes = manifest.totalSize;
      print('CombinedLanguagePackService: Got actual size from GitHub: $actualTotalBytes bytes (${(actualTotalBytes / 1024 / 1024).toStringAsFixed(1)} MB)');
    } catch (e) {
      print('CombinedLanguagePackService: Could not get actual size from GitHub: $e');
      print('CombinedLanguagePackService: Using fallback size: ${(actualTotalBytes / 1024 / 1024).toStringAsFixed(1)} MB');
    }
    
    final progress = DownloadProgress.initial(
      packId: packId,
      packName: '$sourceLanguage ↔ $targetLanguage Language Pack',
      totalBytes: actualTotalBytes, // Use actual GitHub file size
      totalFiles: 2, // Dictionary + ML Kit models
    ).copyWith(
      stageDescription: 'Preparing installation...',
    );
    
    print('CombinedLanguagePackService: Created progress object:');
    print('  - Pack ID: ${progress.packId}');
    print('  - Pack Name: ${progress.packName}');
    print('  - Total Bytes: ${progress.totalBytes}');
    print('  - Total Files: ${progress.totalFiles}');
    print('  - Status: ${progress.status}');
    
    _activeDownloads[packId] = progress;
    _cancelTokens[packId] = CancelToken();
    
    print('CombinedLanguagePackService: Added to active downloads (count: ${_activeDownloads.length})');
    print('CombinedLanguagePackService: Created cancel token for $packId');
    print('CombinedLanguagePackService: Emitting initial progress...');
    
    _emitProgress(progress);
    
    print('CombinedLanguagePackService: Progress tracking initialized successfully');
    
    try {
      print('');
      print('CombinedLanguagePackService: 🚀 STARTING INSTALLATION PROCESS...');
      print('CombinedLanguagePackService: Calling onProgress callback...');
      onProgress?.call('Starting language pack installation...');
      print('CombinedLanguagePackService: onProgress callback completed');
      
      // Update progress to show checking ML Kit support
      if (_activeDownloads.containsKey(packId)) {
        final updatedProgress = _activeDownloads[packId]!.copyWith(
          stageDescription: 'Checking ML Kit support...',
          downloadedBytes: (progress.totalBytes * 0.05).toInt(), // 5% for initial checks
        );
        _activeDownloads[packId] = updatedProgress;
        _emitProgress(updatedProgress);
      }
      
      // Step 1: Check if ML Kit models are supported
      print('');
      print('CombinedLanguagePackService: 🤖 STEP 1 - CHECKING ML KIT SUPPORT...');
      print('CombinedLanguagePackService: ML Kit provider instance: $_mlKitProvider');
      
      bool mlKitSupported = false;
      try {
        mlKitSupported = await _mlKitProvider.supportsLanguagePair(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        print('CombinedLanguagePackService: ✅ ML Kit support check completed');
        print('CombinedLanguagePackService: ML Kit supported for $sourceLanguage-$targetLanguage: $mlKitSupported');
      } catch (e) {
        print('CombinedLanguagePackService: ❌ Error checking ML Kit support: $e');
        mlKitSupported = false; // Default to false if check fails
        print('CombinedLanguagePackService: Defaulting ML Kit support to: $mlKitSupported');
      }
      
      print('');
      print('CombinedLanguagePackService: 📚 STEP 2 - INSTALLING DICTIONARY PACK...');
      onProgress?.call('Downloading dictionary data...');
      print('CombinedLanguagePackService: Called onProgress for dictionary download');
      
      // Update progress to show dictionary download starting
      if (_activeDownloads.containsKey(packId)) {
        final updatedProgress = _activeDownloads[packId]!.copyWith(
          stageDescription: 'Downloading Wiktionary dictionary...',
          downloadedBytes: (progress.totalBytes * 0.1).toInt(), // 10% for starting dictionary
        );
        _activeDownloads[packId] = updatedProgress;
        _emitProgress(updatedProgress);
      }
      
      try {
        await _installDictionaryPack(
          packId: packId,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          onProgress: onProgress,
        );
        
        print('CombinedLanguagePackService: ✅ Dictionary pack installation completed successfully');
      } catch (e) {
        print('CombinedLanguagePackService: ❌ Dictionary pack installation failed: $e');
        print('CombinedLanguagePackService: Error type: ${e.runtimeType}');
        rethrow; // Re-throw to stop the installation
      }
      
      // Update progress after dictionary
      print('');
      print('CombinedLanguagePackService: 📊 UPDATING PROGRESS AFTER DICTIONARY...');
      
      if (_activeDownloads.containsKey(packId)) {
        var currentProgress = _activeDownloads[packId]!.completeFile().copyWith(
          downloadedBytes: (progress.totalBytes * 0.7).toInt(), // 70% done after dictionary
          stageDescription: 'Dictionary installed successfully',
        );
        _activeDownloads[packId] = currentProgress;
        _emitProgress(currentProgress);
        print('CombinedLanguagePackService: Progress updated: ${currentProgress.progressPercent.toStringAsFixed(1)}%');
      } else {
        print('CombinedLanguagePackService: ⚠️ Warning: Pack ID $packId not found in active downloads');
      }
      
      // Step 3: Download ML Kit models if supported
      print('');
      print('CombinedLanguagePackService: 🤖 STEP 3 - HANDLING ML KIT MODELS...');
      
      if (mlKitSupported) {
        print('CombinedLanguagePackService: ML Kit supported, downloading models...');
        onProgress?.call('Downloading offline translation models...');
        
        // Update progress to show ML Kit download starting
        if (_activeDownloads.containsKey(packId)) {
          final updatedProgress = _activeDownloads[packId]!.copyWith(
            stageDescription: 'Downloading ML Kit translation models...',
            downloadedBytes: (progress.totalBytes * 0.7).toInt(), // Starting ML Kit at 70%
          );
          _activeDownloads[packId] = updatedProgress;
          _emitProgress(updatedProgress);
        }
        
        try {
          final modelResult = await _mlKitProvider.downloadModels(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            wifiOnly: wifiOnly,
            onProgress: (mlKitProgress) {
              // Update UI progress based on ML Kit download progress
              if (_activeDownloads.containsKey(packId)) {
                final currentProgress = _activeDownloads[packId]!;
                // ML Kit progress goes from 70% to 90% of total progress
                final overallProgress = 0.7 + (mlKitProgress * 0.2);
                final updatedProgress = currentProgress.copyWith(
                  stageDescription: mlKitProgress < 1.0 
                      ? 'Downloading ML Kit models... ${(mlKitProgress * 100).toStringAsFixed(0)}%'
                      : 'ML Kit models downloaded successfully',
                  downloadedBytes: (currentProgress.totalBytes * overallProgress).toInt(),
                  currentFile: mlKitProgress < 1.0 ? 'ml-kit-models' : 'installation-complete',
                );
                _activeDownloads[packId] = updatedProgress;
                _emitProgress(updatedProgress);
                print('CombinedLanguagePackService: ML Kit progress: ${(mlKitProgress * 100).toStringAsFixed(1)}% (Overall: ${(overallProgress * 100).toStringAsFixed(1)}%)');
              }
            },
          );
          
          print('CombinedLanguagePackService: ML Kit download result:');
          print('  - Success: ${modelResult.success}');
          print('  - Message: ${modelResult.message}');
          
          if (!modelResult.success) {
            print('CombinedLanguagePackService: ⚠️ ML Kit model download failed: ${modelResult.message}');
            onProgress?.call('Dictionary installed, ML Kit models failed to download');
            
            // Update progress with ML Kit failure
            if (_activeDownloads.containsKey(packId)) {
              final updatedProgress = _activeDownloads[packId]!.copyWith(
                stageDescription: 'ML Kit models failed - dictionary only',
                downloadedBytes: (progress.totalBytes * 0.85).toInt(), // 85% with partial success
              );
              _activeDownloads[packId] = updatedProgress;
              _emitProgress(updatedProgress);
            }
          } else {
            print('CombinedLanguagePackService: ✅ ML Kit models downloaded successfully');
            onProgress?.call('ML Kit models downloaded successfully');
            
            // Update progress with ML Kit success
            if (_activeDownloads.containsKey(packId)) {
              final updatedProgress = _activeDownloads[packId]!.copyWith(
                stageDescription: 'ML Kit models installed successfully',
                downloadedBytes: (progress.totalBytes * 0.9).toInt(), // 90% with ML Kit success
              );
              _activeDownloads[packId] = updatedProgress;
              _emitProgress(updatedProgress);
            }
          }
        } catch (e) {
          print('CombinedLanguagePackService: ❌ Exception during ML Kit download: $e');
          onProgress?.call('Dictionary installed, ML Kit models had an error');
        }
      } else {
        print('CombinedLanguagePackService: ML Kit not supported for $sourceLanguage-$targetLanguage');
        onProgress?.call('ML Kit not supported for this language pair, dictionary-only installation');
        
        // Update progress for ML Kit not supported
        if (_activeDownloads.containsKey(packId)) {
          final updatedProgress = _activeDownloads[packId]!.copyWith(
            stageDescription: 'ML Kit not supported - dictionary only',
            downloadedBytes: (progress.totalBytes * 0.85).toInt(), // 85% without ML Kit
          );
          _activeDownloads[packId] = updatedProgress;
          _emitProgress(updatedProgress);
        }
      }
      
      // Step 4: Register the combined pack as installed (bidirectional)
      print('');
      print('CombinedLanguagePackService: 📋 STEP 4 - REGISTERING LANGUAGE PACKS...');
      
      // Use the actual file size from the progress tracking
      final currentProgress = _activeDownloads[packId];
      int actualSizeBytes = currentProgress?.totalBytes ?? (50 * 1024 * 1024);
      
      print('CombinedLanguagePackService: Using actual file size from progress: $actualSizeBytes bytes (${(actualSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB)');
      
      try {
        print('CombinedLanguagePackService: Registering forward pack ($packId)...');
        print('CombinedLanguagePackService: Registration details:');
        print('  - Pack ID: $packId');
        print('  - Source: $sourceLanguage');
        print('  - Target: $targetLanguage');
        print('  - Size: $actualSizeBytes bytes (${(actualSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB)');
        
        await _packService.registerLanguagePack(
          packId: packId,
          name: '$sourceLanguage ↔ $targetLanguage Language Pack',
          description: 'Bidirectional dictionary and translation models',
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          packType: 'combined',
          version: '1.0.0',
          sizeBytes: actualSizeBytes,
          downloadUrl: '',
          checksum: '',
        );
        print('CombinedLanguagePackService: ✅ Forward pack registered successfully with actual size: ${(actualSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB');
        
        print('CombinedLanguagePackService: Marking forward pack as installed...');
        await _packService.markPackAsInstalled(packId);
        print('CombinedLanguagePackService: ✅ Forward pack marked as installed');
        
        // Bidirectional pack provides both directions in a single database
        
      } catch (e) {
        print('CombinedLanguagePackService: ❌ Error during pack registration: $e');
        print('CombinedLanguagePackService: Error type: ${e.runtimeType}');
        rethrow; // Re-throw to fail the installation
      }
      
      // Mark as completed
      print('');
      print('CombinedLanguagePackService: 🎉 STEP 5 - MARKING AS COMPLETED...');
      
      if (_activeDownloads.containsKey(packId)) {
        final completedProgress = _activeDownloads[packId]!.completeFile().copyWith(
          downloadedBytes: progress.totalBytes,
          status: DownloadStatus.completed,
          stageDescription: 'Installation completed successfully!',
        );
        _activeDownloads[packId] = completedProgress;
        _emitProgress(completedProgress);
        print('CombinedLanguagePackService: ✅ Progress marked as completed: 100%');
      } else {
        print('CombinedLanguagePackService: ⚠️ Warning: Pack ID $packId not found for completion');
      }
      
      onProgress?.call('Language pack installation completed!');
      print('CombinedLanguagePackService: Called onProgress for completion');
      
      print('');
      print('CombinedLanguagePackService: ✅✅✅ INSTALLATION COMPLETED SUCCESSFULLY ✅✅✅');
      
    } catch (e) {
      print('');
      print('CombinedLanguagePackService: ❌❌❌ INSTALLATION FAILED ❌❌❌');
      print('CombinedLanguagePackService: Error: $e');
      print('CombinedLanguagePackService: Error type: ${e.runtimeType}');
      print('CombinedLanguagePackService: Stack trace:');
      print(StackTrace.current);
      
      if (_activeDownloads.containsKey(packId)) {
        final failedProgress = _activeDownloads[packId]!.fail(e.toString());
        _activeDownloads[packId] = failedProgress;
        _emitProgress(failedProgress);
        print('CombinedLanguagePackService: Progress marked as failed');
      } else {
        print('CombinedLanguagePackService: ⚠️ Warning: Pack ID $packId not found for failure marking');
      }
      
      onProgress?.call('Installation failed: $e');
      print('CombinedLanguagePackService: Called onProgress for failure');
      
      rethrow;
    } finally {
      print('');
      print('CombinedLanguagePackService: 🧹 CLEANUP - Starting cleanup for $packId...');
      _cleanupDownload(packId);
      print('CombinedLanguagePackService: 🧹 CLEANUP - Cleanup completed');
    }
    
    print('********************************');
    print('CombinedLanguagePackService.installLanguagePack: EXIT');
    print('********************************');
    print('');
  }
  
  /// Cancel an installation
  Future<void> cancelInstallation(String packId) async {
    final cancelToken = _cancelTokens[packId];
    cancelToken?.cancel('Installation cancelled by user');
    
    final progress = _activeDownloads[packId];
    if (progress != null) {
      final cancelledProgress = progress.cancel();
      _activeDownloads[packId] = cancelledProgress;
      _emitProgress(cancelledProgress);
    }
    
    await _cleanupPartialInstallation(packId);
  }
  
  /// Check if a language pack is installed (checks both directions)
  Future<bool> isLanguagePackInstalled({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    
    // Check if bidirectional pack is installed
    return await _packService.isPackInstalled(packId);
  }
  
  /// Get installed language packs
  Future<List<LanguagePack>> getInstalledLanguagePacks() async {
    return await _packService.getInstalledPacks();
  }
  
  /// Remove a bidirectional language pack
  Future<void> removeLanguagePack({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    
    print('');
    print('🗑️ CombinedLanguagePackService.removeLanguagePack: STARTING REMOVAL');
    print('CombinedLanguagePackService.removeLanguagePack: Source: $sourceLanguage');
    print('CombinedLanguagePackService.removeLanguagePack: Target: $targetLanguage');
    print('CombinedLanguagePackService.removeLanguagePack: Bidirectional Pack ID: $packId');
    
    // Remove ML Kit models
    print('');
    print('CombinedLanguagePackService.removeLanguagePack: 🤖 REMOVING ML KIT MODELS...');
    try {
      // Note: ML Kit doesn't have a direct delete method
      // Models are managed by the system and will be cleaned up automatically
      print('CombinedLanguagePackService.removeLanguagePack: ML Kit models cleanup handled by system');
    } catch (e) {
      print('CombinedLanguagePackService.removeLanguagePack: ❌ Failed to remove ML Kit models: $e');
    }
    
    // Remove dictionary data and pack registrations
    print('');
    print('CombinedLanguagePackService.removeLanguagePack: 📚 REMOVING PACK REGISTRATIONS...');
    
    try {
      print('CombinedLanguagePackService.removeLanguagePack: Removing bidirectional pack ($packId)...');
      await _packService.removeLanguagePack(packId);
      print('CombinedLanguagePackService.removeLanguagePack: ✅ Bidirectional pack removed');
      
      // Clear any active downloads for this pack
      print('CombinedLanguagePackService.removeLanguagePack: 🧹 CLEARING ACTIVE DOWNLOADS...');
      if (_activeDownloads.containsKey(packId)) {
        _activeDownloads.remove(packId);
        print('CombinedLanguagePackService.removeLanguagePack: Cleared active download for $packId');
      }
      if (_cancelTokens.containsKey(packId)) {
        _cancelTokens[packId]?.cancel('Pack removed');
        _cancelTokens.remove(packId);
        print('CombinedLanguagePackService.removeLanguagePack: Cancelled and cleared cancel token for $packId');
      }
      print('CombinedLanguagePackService.removeLanguagePack: ✅ Active downloads cleared');
      
    } catch (e) {
      print('CombinedLanguagePackService.removeLanguagePack: ❌ Error removing pack registrations: $e');
      print('CombinedLanguagePackService.removeLanguagePack: Error type: ${e.runtimeType}');
      rethrow;
    }
    
    print('CombinedLanguagePackService.removeLanguagePack: ✅ REMOVAL COMPLETED SUCCESSFULLY');
    print('');
  }
  
  Future<void> _installDictionaryPack({
    required String packId,
    required String sourceLanguage,
    required String targetLanguage,
    Function(String message)? onProgress,
  }) async {
    print('');
    print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
    print('CombinedLanguagePackService._installDictionaryPack: ENTRY');
    print('CombinedLanguagePackService._installDictionaryPack: Pack ID: $packId');
    print('CombinedLanguagePackService._installDictionaryPack: Source: $sourceLanguage');
    print('CombinedLanguagePackService._installDictionaryPack: Target: $targetLanguage');
    print('CombinedLanguagePackService._installDictionaryPack: Repository: $_repository');
    print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
    
    try {
      // Try to get available language packs from GitHub
      print('');
      print('CombinedLanguagePackService._installDictionaryPack: 🔍 FETCHING FROM GITHUB...');
      
      final availablePacks = await _repository.getAvailableLanguagePacks();
      
      print('CombinedLanguagePackService._installDictionaryPack: ✅ GitHub fetch completed');
      print('CombinedLanguagePackService._installDictionaryPack: Found ${availablePacks.length} available packs');
      
      for (final pack in availablePacks) {
        print('CombinedLanguagePackService._installDictionaryPack: Available: ${pack.id} - ${pack.name}');
      }
      
      // Look for a matching dictionary pack
      print('');
      print('CombinedLanguagePackService._installDictionaryPack: 🔎 LOOKING FOR MATCHING PACK...');
      print('CombinedLanguagePackService._installDictionaryPack: Searching for: $sourceLanguage-$targetLanguage OR $targetLanguage-$sourceLanguage');
      
      LanguagePackManifest? matchingPack;
      for (final pack in availablePacks) {
        final parts = pack.id.split('-');
        final isMatch = parts.length >= 2 && 
               ((parts[0] == sourceLanguage && parts[1] == targetLanguage) ||
                (parts[0] == targetLanguage && parts[1] == sourceLanguage));
        print('CombinedLanguagePackService._installDictionaryPack: Checking ${pack.id}: parts=$parts, match=$isMatch');
        if (isMatch) {
          matchingPack = pack;
          break;
        }
      }
      
      print('CombinedLanguagePackService._installDictionaryPack: Matching pack result: ${matchingPack?.id}');
      
      if (matchingPack != null) {
        print('CombinedLanguagePackService._installDictionaryPack: ✅ Found matching pack: ${matchingPack.name}');
        onProgress?.call('Found ${matchingPack.name}, downloading...');
        
        print('CombinedLanguagePackService._installDictionaryPack: Starting dictionary file download...');
        await _downloadDictionaryFiles(matchingPack, onProgress, trackingPackId: packId);
        print('CombinedLanguagePackService._installDictionaryPack: ✅ Dictionary files downloaded successfully');
        
        // Update progress after download
        if (_activeDownloads.containsKey(packId)) {
          final currentProgress = _activeDownloads[packId]!;
          final updatedProgress = currentProgress.copyWith(
            downloadedBytes: (currentProgress.totalBytes * 0.8).toInt(), // 80% done after dictionary download
          );
          _activeDownloads[packId] = updatedProgress;
          _emitProgress(updatedProgress);
          print('CombinedLanguagePackService._installDictionaryPack: 📊 Progress updated to 80% after dictionary download');
        }
        
        onProgress?.call('Loading dictionary data...');
        print('CombinedLanguagePackService._installDictionaryPack: Dictionary data loading delegated to integration service');
        
        // Actually call the integration service to load the dictionary data
        try {
          // Get the downloaded file path
          final packDir = await _packService.getPackDirectory(matchingPack.id);
          final zipFilePath = path.join(packDir.path, '${matchingPack.id}.sqlite.zip');
          
          print('CombinedLanguagePackService._installDictionaryPack: ZIP file path: $zipFilePath');
          print('CombinedLanguagePackService._installDictionaryPack: ZIP file exists: ${await File(zipFilePath).exists()}');
          
          if (await File(zipFilePath).exists()) {
            print('CombinedLanguagePackService._installDictionaryPack: Calling integration service to process ZIP file...');
            
            // Create a manifest with dictionary file for the integration service
            final dictionaryManifest = LanguagePackManifest(
              id: matchingPack.id,
              name: matchingPack.name,
              language: matchingPack.language,
              version: matchingPack.version,
              description: matchingPack.description,
              totalSize: matchingPack.totalSize,
              files: matchingPack.files,
              supportedTargetLanguages: matchingPack.supportedTargetLanguages,
              sourceLanguage: matchingPack.sourceLanguage,
              targetLanguage: matchingPack.targetLanguage,
              packType: matchingPack.packType,
              releaseDate: matchingPack.releaseDate,
              author: matchingPack.author,
              license: matchingPack.license,
            );
            final result = await _integrationService.installLanguagePack(dictionaryManifest, zipFilePath);
            
            if (result.success) {
              print('CombinedLanguagePackService._installDictionaryPack: ✅ Dictionary data loaded successfully');
              print('CombinedLanguagePackService._installDictionaryPack: Dictionary installed: ${result.dictionaryInstalled}');
              onProgress?.call('Dictionary data loaded successfully');
            } else {
              print('CombinedLanguagePackService._installDictionaryPack: ⚠️ Dictionary installation completed with warnings');
              print('CombinedLanguagePackService._installDictionaryPack: Error: ${result.error}');
              onProgress?.call('Dictionary installation completed with warnings');
            }
          } else {
            print('CombinedLanguagePackService._installDictionaryPack: ❌ ZIP file not found at expected location');
            onProgress?.call('Dictionary file not found, using basic setup');
          }
        } catch (e) {
          print('CombinedLanguagePackService._installDictionaryPack: ❌ Error during dictionary data loading: $e');
          onProgress?.call('Dictionary installation failed, continuing with basic setup');
        }
        
      } else {
        print('CombinedLanguagePackService._installDictionaryPack: ⚠️ No matching dictionary pack found');
        onProgress?.call('No dictionary pack found for $sourceLanguage-$targetLanguage, using basic setup');
        
        print('CombinedLanguagePackService._installDictionaryPack: Creating basic pack entry for tracking');
      }
      
    } catch (e) {
      print('');
      print('CombinedLanguagePackService._installDictionaryPack: ❌ DICTIONARY INSTALLATION ERROR');
      print('CombinedLanguagePackService._installDictionaryPack: Error: $e');
      print('CombinedLanguagePackService._installDictionaryPack: Error type: ${e.runtimeType}');
      print('CombinedLanguagePackService._installDictionaryPack: Stack trace:');
      print(StackTrace.current);
      
      onProgress?.call('Dictionary installation completed with warnings');
      print('CombinedLanguagePackService._installDictionaryPack: Continuing despite error (non-fatal)');
      // Don't throw - let the combined installation continue with ML Kit
    }
    
    print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
    print('CombinedLanguagePackService._installDictionaryPack: EXIT');
    print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
    print('');
  }
  
  Future<void> _downloadDictionaryFiles(
    LanguagePackManifest manifest,
    Function(String message)? onProgress,
    {String? trackingPackId}
  ) async {
    print('');
    print('⬇️ CombinedLanguagePackService._downloadDictionaryFiles: STARTING FILE DOWNLOAD');
    print('CombinedLanguagePackService._downloadDictionaryFiles: Manifest ID: ${manifest.id}');
    print('CombinedLanguagePackService._downloadDictionaryFiles: Files to download: ${manifest.files.length}');
    
    for (final file in manifest.files) {
      print('CombinedLanguagePackService._downloadDictionaryFiles: File details:');
      print('  - Name: ${file.name}');
      print('  - Size: ${file.size} bytes');
      print('  - Type: ${file.type}');
      print('  - Download URL: ${file.downloadUrl}');
    }
    
    final packDir = await _packService.getPackDirectory(manifest.id);
    print('CombinedLanguagePackService._downloadDictionaryFiles: Pack directory: ${packDir.path}');
    print('CombinedLanguagePackService._downloadDictionaryFiles: Directory exists: ${await packDir.exists()}');
    
    onProgress?.call('Downloading dictionary files...');
    
    for (int i = 0; i < manifest.files.length; i++) {
      final file = manifest.files[i];
      print('');
      print('CombinedLanguagePackService._downloadDictionaryFiles: 📁 DOWNLOADING FILE ${i + 1}/${manifest.files.length}');
      print('CombinedLanguagePackService._downloadDictionaryFiles: File name: ${file.name}');
      
      onProgress?.call('Downloading ${file.name}...');
      
      final filePath = path.join(packDir.path, file.name);
      print('CombinedLanguagePackService._downloadDictionaryFiles: Target file path: $filePath');
      
      final cancelToken = _cancelTokens[manifest.id];
      print('CombinedLanguagePackService._downloadDictionaryFiles: Cancel token available: ${cancelToken != null}');
      
      try {
        await _repository.downloadPackFile(
          downloadUrl: file.downloadUrl,
          destinationPath: filePath,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            final percentage = total > 0 ? (received / total * 100).toStringAsFixed(1) : '0.0';
            print('CombinedLanguagePackService._downloadDictionaryFiles: Download progress: $percentage% ($received/$total bytes)');
            
            // Update UI progress
            final progressPackId = trackingPackId ?? manifest.id;
            if (_activeDownloads.containsKey(progressPackId)) {
              final currentProgress = _activeDownloads[progressPackId]!;
              // Calculate progress from 10% to 65% for dictionary download
              final baseProgress = currentProgress.totalBytes * 0.1; // Start at 10%
              final dictProgress = (received / total) * (currentProgress.totalBytes * 0.55); // 55% range for dictionary
              final totalProgress = baseProgress + dictProgress;
              
              final updatedProgress = currentProgress.copyWith(
                downloadedBytes: totalProgress.toInt(),
                currentFile: file.name,
                stageDescription: 'Downloading ${file.name} (${percentage}%)',
              );
              _activeDownloads[progressPackId] = updatedProgress;
              _emitProgress(updatedProgress);
              print('CombinedLanguagePackService._downloadDictionaryFiles: 📊 UI Progress updated: ${updatedProgress.progressPercent.toStringAsFixed(1)}%');
            } else {
              print('CombinedLanguagePackService._downloadDictionaryFiles: ⚠️ Warning: Pack ID $progressPackId not found in active downloads');
            }
          },
        );
        
        print('CombinedLanguagePackService._downloadDictionaryFiles: ✅ File downloaded successfully');
        
        // Check if file actually exists
        final downloadedFile = File(filePath);
        final fileExists = await downloadedFile.exists();
        final fileSize = fileExists ? await downloadedFile.length() : 0;
        print('CombinedLanguagePackService._downloadDictionaryFiles: Downloaded file exists: $fileExists');
        print('CombinedLanguagePackService._downloadDictionaryFiles: Downloaded file size: $fileSize bytes');
        
        // Verify checksum
        print('CombinedLanguagePackService._downloadDictionaryFiles: 🔐 VERIFYING CHECKSUM...');
        print('CombinedLanguagePackService._downloadDictionaryFiles: Expected checksum: ${file.checksum}');
        
        if (file.checksum.isNotEmpty) {
          final checksumValid = await _verifyFileChecksum(filePath, file.checksum);
          print('CombinedLanguagePackService._downloadDictionaryFiles: Checksum verification: ${checksumValid ? "✅ VALID" : "❌ INVALID"}');
          
          if (!checksumValid) {
            throw LanguagePackException('Checksum verification failed for ${file.name}');
          }
        } else {
          print('CombinedLanguagePackService._downloadDictionaryFiles: ⚠️ No checksum provided, skipping verification');
        }
        
      } catch (e) {
        print('CombinedLanguagePackService._downloadDictionaryFiles: ❌ ERROR DOWNLOADING FILE');
        print('CombinedLanguagePackService._downloadDictionaryFiles: Error: $e');
        print('CombinedLanguagePackService._downloadDictionaryFiles: Error type: ${e.runtimeType}');
        rethrow;
      }
    }
    
    // Save manifest
    print('');
    print('CombinedLanguagePackService._downloadDictionaryFiles: 💾 SAVING MANIFEST...');
    try {
      await _packService.savePackManifest(manifest.id, manifest);
      print('CombinedLanguagePackService._downloadDictionaryFiles: ✅ Manifest saved successfully');
    } catch (e) {
      print('CombinedLanguagePackService._downloadDictionaryFiles: ❌ Error saving manifest: $e');
      rethrow;
    }
    
    // Install the downloaded pack using the integration service
    print('');
    print('CombinedLanguagePackService._downloadDictionaryFiles: 🔧 INSTALLING DICTIONARY DATA...');
    onProgress?.call('Installing dictionary data...');
    
    try {
      print('CombinedLanguagePackService._downloadDictionaryFiles: Integration service: $_integrationService');
      print('CombinedLanguagePackService._downloadDictionaryFiles: Pack directory: ${packDir.path}');
      
      final installResult = await _integrationService.installLanguagePack(
        manifest,
        packDir.path,
      );
      
      print('CombinedLanguagePackService._downloadDictionaryFiles: Installation result:');
      print('  - Success: ${installResult.success}');
      print('  - Message: ${installResult.message}');
      
      if (installResult.success) {
        print('CombinedLanguagePackService._downloadDictionaryFiles: ✅ DICTIONARY INSTALLATION SUCCESSFUL');
        onProgress?.call('Dictionary installed successfully: ${installResult.message}');
      } else {
        print('CombinedLanguagePackService._downloadDictionaryFiles: ⚠️ DICTIONARY INSTALLATION HAD ISSUES');
        onProgress?.call('Dictionary files downloaded but installation had issues');
      }
      
    } catch (e) {
      print('CombinedLanguagePackService._downloadDictionaryFiles: ❌ ERROR DURING DICTIONARY INSTALLATION');
      print('CombinedLanguagePackService._downloadDictionaryFiles: Error: $e');
      print('CombinedLanguagePackService._downloadDictionaryFiles: Error type: ${e.runtimeType}');
      print('CombinedLanguagePackService._downloadDictionaryFiles: Stack trace:');
      print(StackTrace.current);
      rethrow;
    }
    
    print('CombinedLanguagePackService._downloadDictionaryFiles: ✅ DICTIONARY FILES DOWNLOAD AND INSTALL COMPLETED');
    print('');
  }
  
  Future<bool> _verifyFileChecksum(String filePath, String expectedChecksum) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString() == expectedChecksum;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> _cleanupPartialInstallation(String packId) async {
    try {
      final packDir = await _packService.getPackDirectory(packId);
      if (await packDir.exists()) {
        await packDir.delete(recursive: true);
      }
    } catch (e) {
      print('Failed to cleanup partial installation: $e');
    }
  }
  
  void _cleanupDownload(String packId) {
    _cancelTokens.remove(packId);
    
    // Check if download completed successfully
    final progress = _activeDownloads[packId];
    if (progress?.status == DownloadStatus.completed) {
      // For completed downloads, remove immediately to allow UI to show "installed" state
      print('CombinedLanguagePackService._cleanupDownload: Removing completed download $packId immediately');
      _activeDownloads.remove(packId);
    } else {
      // For failed or cancelled downloads, keep for a while for UI feedback
      Timer(const Duration(minutes: 5), () {
        _activeDownloads.remove(packId);
      });
    }
  }
  
  void _emitProgress(DownloadProgress progress) {
    print('CombinedLanguagePackService._emitProgress: 📢 EMITTING PROGRESS UPDATE');
    print('  - Pack ID: ${progress.packId}');
    print('  - Status: ${progress.status}');
    print('  - Progress: ${progress.progressPercent.toStringAsFixed(1)}%');
    print('  - Downloaded: ${progress.downloadedBytes}/${progress.totalBytes} bytes');
    print('  - Current file: ${progress.currentFile}');
    print('  - Stream closed: ${_progressController.isClosed}');
    print('  - Stream has listeners: ${_progressController.hasListener}');
    
    if (!_progressController.isClosed) {
      _progressController.add(progress);
      print('CombinedLanguagePackService._emitProgress: ✅ Progress emitted to stream');
    } else {
      print('CombinedLanguagePackService._emitProgress: ❌ Stream is closed, cannot emit progress');
    }
  }
  
  /// Get bidirectional dictionary service for lookups
  BidirectionalDictionaryService get bidirectionalDictionary => _bidirectionalService;

  /// Perform bidirectional dictionary lookup
  Future<BidirectionalLookupResult> lookupWord({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    return await _bidirectionalService.lookup(
      query: query,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  /// Search for partial matches in both directions
  Future<List<BidirectionalDictionaryEntry>> searchWords({
    required String query,
    required String sourceLanguage, 
    required String targetLanguage,
    int limit = 20,
  }) async {
    return await _bidirectionalService.search(
      query: query,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      limit: limit,
    );
  }


  /// Get statistics for a bidirectional pack
  Future<Map<String, int>> getPackStatistics({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    return await _bidirectionalService.getPackStatistics(packId);
  }

  /// Validate bidirectional pack structure
  Future<bool> validatePackStructure({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    return await _bidirectionalService.validatePackStructure(packId);
  }

  /// Clean up resources
  void dispose() {
    // Cancel all active downloads
    for (final cancelToken in _cancelTokens.values) {
      cancelToken.cancel('Service disposed');
    }
    
    _cancelTokens.clear();
    _activeDownloads.clear();
    _progressController.close();
    _bidirectionalService.dispose();
  }
}

/// Helper extension for language pack operations
extension LanguagePackHelpers on List<LanguagePackManifest> {
  LanguagePackManifest? get firstOrNull => isEmpty ? null : first;
}