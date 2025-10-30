// Combined Language Pack Service - Downloads dictionary + ML Kit models together
// Simplifies user experience by bundling both resources in one action

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/dictionary_loader_service.dart';
import '../../../core/services/language_pack_integration_service.dart';
import '../../translation/providers/ml_kit_provider.dart';
import '../models/language_pack_manifest.dart';
import '../models/download_progress.dart';
import '../repositories/github_releases_repo.dart' hide LanguagePackException;
import 'drift_language_pack_service.dart';
import 'bidirectional_dictionary_service.dart';
import '../models/bidirectional_dictionary_entry.dart';

class CombinedLanguagePackService {
  final AppDatabase _database;
  final DriftLanguagePackService _packService;
  final BidirectionalDictionaryService _bidirectionalService;
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
      print('🧹 Cleared failed download for $packId');
    }
  }
  
  /// Clear any stale download state for a pack (force cleanup)
  void clearAnyDownloadState(String packId) {
    print('🧹 Force clearing download state for $packId');
    if (_activeDownloads.containsKey(packId)) {
      _activeDownloads.remove(packId);
    }
    if (_cancelTokens.containsKey(packId)) {
      _cancelTokens[packId]?.cancel('Forced cleanup');
      _cancelTokens.remove(packId);
    }
  }
  
  /// Check and repair any broken installations on startup
  Future<void> validateAndRepairOnStartup() async {
    try {
      print('🔍 Checking for broken installations...');
      final brokenPacks = await _packService.detectBrokenPacks();
      
      if (brokenPacks.isNotEmpty) {
        print('⚠️ Found ${brokenPacks.length} broken packs');
        
        // Auto-repair broken packs by clearing their installation status
        for (final packId in brokenPacks) {
          try {
            print('🔧 Auto-repairing: $packId');
            
            // Mark as not installed so user can reinstall cleanly
            final updateCount = await (_database.update(_database.languagePacks)
              ..where((pack) => pack.packId.equals(packId)))
              .write(LanguagePacksCompanion(
                isInstalled: Value(false),
                isActive: Value(false),
              ));
              
            if (updateCount > 0) {
              print('✅ Marked $packId for clean reinstall');
            } else {
              print('⚠️ Pack $packId not found for repair');
            }
          } catch (e) {
            print('❌ Failed to auto-repair $packId: $e');
            // Continue with other packs even if one fails
          }
        }
      } else {
        print('✅ No broken installations detected');
      }
    } catch (e) {
      print('❌ Error during startup validation: $e');
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
    
    print('🚀 Installing language pack: $packId');
    
    // Check if pack is already installed
    try {
      final isInstalled = await _packService.isPackInstalled(packId);
      if (isInstalled) {
        print('🔄 Pack already installed - reinstalling');
        await removeLanguagePack(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
      }
    } catch (e) {
      print('⚠️ Error checking installation status: $e');
    }
    
    // Clear any stale download state
    if (_activeDownloads.containsKey(packId)) {
      clearAnyDownloadState(packId);
    }
    
    // Get file size from GitHub
    int actualTotalBytes = 50 * 1024 * 1024; // fallback
    try {
      final manifests = await _repository.getAvailableLanguagePacks();
      final manifest = manifests.firstWhere((m) => m.id == packId);
      actualTotalBytes = manifest.totalSize;
    } catch (e) {
      print('⚠️ Could not get pack size from GitHub: $e');
    }
    
    // Helper function to update progress with simple phase tracking
    void updateProgress(double percent, String phase) {
      if (!_activeDownloads.containsKey(packId)) return;
      
      final currentProgress = _activeDownloads[packId]!;
      final updatedProgress = currentProgress.copyWith(
        downloadedBytes: (actualTotalBytes * percent / 100).toInt(),
        stageDescription: phase,
      );
      
      _activeDownloads[packId] = updatedProgress;
      _emitProgress(updatedProgress);
      // Reduced logging to prevent memory issues
    }
    
    // Initialize progress
    final progress = DownloadProgress.initial(
      packId: packId,
      packName: '$sourceLanguage ↔ $targetLanguage Language Pack',
      totalBytes: actualTotalBytes,
      totalFiles: 4, // Setup, Download, Install, Complete
    ).copyWith(
      stageDescription: 'Starting installation...',
    );
    
    _activeDownloads[packId] = progress;
    _cancelTokens[packId] = CancelToken();
    _emitProgress(progress);
    
    print('📊 Progress tracking initialized');
    
    try {
      onProgress?.call('Starting language pack installation...');
      
      // Phase 1: Setup (0-10%)
      updateProgress(5.0, 'Checking ML Kit support...');
      
      bool mlKitSupported = false;
      try {
        mlKitSupported = await _mlKitProvider.supportsLanguagePair(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        print('🤖 ML Kit supported: $mlKitSupported');
      } catch (e) {
        print('⚠️ Error checking ML Kit: $e');
        mlKitSupported = false;
      }
      
      updateProgress(10.0, 'Setup complete');
      
      // Phase 2: Dictionary Installation (10-90%)
      updateProgress(15.0, 'Starting dictionary download...');
      onProgress?.call('Downloading dictionary data...');
      
      await _installDictionaryPack(
        packId: packId,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        onProgress: onProgress,
        stepProgressCallback: (stepProgress, description) {
          // Map dictionary progress to 15-90% range (stepProgress is 0.0-1.0)
          final overallProgress = 15.0 + (stepProgress * 75.0);
          updateProgress(overallProgress, description);
        },
      );
      
      updateProgress(90.0, 'Dictionary installed successfully');
      
      // Phase 3: ML Kit Models (90-95%)
      if (mlKitSupported) {
        updateProgress(92.0, 'Starting ML Kit download...');
        onProgress?.call('Downloading offline translation models...');
        
        try {
          final modelResult = await _mlKitProvider.downloadModels(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            wifiOnly: wifiOnly,
            onProgress: (mlKitProgress) {
              final description = mlKitProgress < 1.0 
                  ? 'Downloading ML Kit models... ${(mlKitProgress * 100).toStringAsFixed(0)}%'
                  : 'ML Kit models downloaded successfully';
              updateProgress(92.0 + (mlKitProgress * 3.0), description);
            },
          );
          
          if (!modelResult.success) {
            print('⚠️ ML Kit failed: ${modelResult.message}');
            onProgress?.call('Dictionary installed, ML Kit models failed');
          }
        } catch (e) {
          print('❌ ML Kit error: $e');
        }
      } else {
        print('🤖 ML Kit not supported for this language pair');
        onProgress?.call('Dictionary-only installation completed');
      }
      
      updateProgress(95.0, 'ML Kit complete');
      
      // Phase 4: Registration and Completion (95-100%)
      updateProgress(97.0, 'Registering language pack...');
      
      final currentProgress = _activeDownloads[packId];
      int actualSizeBytes = currentProgress?.totalBytes ?? (50 * 1024 * 1024);
      
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
      
      await _packService.markPackAsInstalled(packId);
      
      updateProgress(100.0, 'Installation completed successfully!');
      
      // Mark as completed
      if (_activeDownloads.containsKey(packId)) {
        final completedProgress = _activeDownloads[packId]!.copyWith(
          status: DownloadStatus.completed,
        );
        _activeDownloads[packId] = completedProgress;
        _emitProgress(completedProgress);
      }
      
      onProgress?.call('Language pack installation completed!');
      print('✅ Language pack installation completed successfully');
      
    } catch (e) {
      print('❌ Language pack installation failed: $e');
      
      if (_activeDownloads.containsKey(packId)) {
        final failedProgress = _activeDownloads[packId]!.fail(e.toString());
        _activeDownloads[packId] = failedProgress;
        _emitProgress(failedProgress);
      }
      
      onProgress?.call('Installation failed: $e');
      rethrow;
    } finally {
      _cleanupDownload(packId);
    }
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
    Function(double stepProgress, String description)? stepProgressCallback,
  }) async {
    print('📚 Installing dictionary pack: $packId');
    
    try {
      final availablePacks = await _repository.getAvailableLanguagePacks();
      
      // Find matching pack
      LanguagePackManifest? matchingPack;
      for (final pack in availablePacks) {
        final parts = pack.id.split('-');
        final isMatch = parts.length >= 2 && 
               ((parts[0] == sourceLanguage && parts[1] == targetLanguage) ||
                (parts[0] == targetLanguage && parts[1] == sourceLanguage));
        if (isMatch) {
          matchingPack = pack;
          break;
        }
      }
      
      if (matchingPack != null) {
        print('✅ Found matching pack: ${matchingPack.name}');
        onProgress?.call('Found ${matchingPack.name}, downloading...');
        
        await _downloadDictionaryFiles(
          matchingPack, 
          onProgress, 
          trackingPackId: packId,
          stepProgressCallback: stepProgressCallback,
        );
        
        onProgress?.call('Dictionary data loaded successfully');
      } else {
        print('⚠️ No matching dictionary pack found');
        onProgress?.call('No dictionary pack found for $sourceLanguage-$targetLanguage');
      }
      
    } catch (e) {
      print('❌ Dictionary installation error: $e');
      onProgress?.call('Dictionary installation completed with warnings');
      // Don't throw - let the combined installation continue with ML Kit
    }
  }
  
  Future<void> _downloadDictionaryFiles(
    LanguagePackManifest manifest,
    Function(String message)? onProgress,
    {String? trackingPackId, Function(double stepProgress, String description)? stepProgressCallback}
  ) async {
    print('📦 Downloading ${manifest.files.length} files for ${manifest.id}');
    
    final packDir = await _packService.getPackDirectory(manifest.id);
    
    onProgress?.call('Downloading dictionary files...');
    
    for (int i = 0; i < manifest.files.length; i++) {
      final file = manifest.files[i];
      print('📁 Downloading file ${i + 1}/${manifest.files.length}: ${file.name}');
      
      onProgress?.call('Downloading ${file.name}...');
      
      final filePath = path.join(packDir.path, file.name);
      final cancelToken = _cancelTokens[trackingPackId ?? manifest.id];
      
      try {
        await _repository.downloadPackFile(
          downloadUrl: file.downloadUrl,
          destinationPath: filePath,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            final percentage = total > 0 ? (received / total * 100).toStringAsFixed(1) : '0.0';
            final downloadProgress = total > 0 ? received / total : 0.0;
            
            // Calculate progress for this file within the download phase (0.0-0.2)
            final fileBaseProgress = (i / manifest.files.length) * 0.2;
            final fileProgressRange = 0.2 / manifest.files.length;
            final stepProgress = fileBaseProgress + (downloadProgress * fileProgressRange);
            
            stepProgressCallback?.call(stepProgress, 'Downloading ${file.name} ($percentage%)');
            
            // Reduced logging to prevent memory issues
          },
        );
        
        // Verify checksum
        if (file.checksum.isNotEmpty) {
          print('🔐 Verifying checksum for ${file.name}...');
        }
        
        if (file.checksum.isNotEmpty) {
          final checksumValid = await _verifyFileChecksum(filePath, file.checksum);
          
          if (!checksumValid) {
            throw LanguagePackException('Checksum verification failed for ${file.name}');
          }
        }
        
      } catch (e) {
        print('❌ Error downloading ${file.name}: $e');
        rethrow;
      }
    }
    
    // Save manifest
    try {
      await _packService.savePackManifest(manifest.id, manifest);
      print('💾 Manifest saved');
    } catch (e) {
      print('❌ Error saving manifest: $e');
      rethrow;
    }
    
    // Install the downloaded pack using the integration service
    onProgress?.call('Installing dictionary data...');
    
    try {
      final installResult = await _integrationService.installLanguagePack(
        manifest,
        packDir.path,
        progressCallback: (message, progress) {
          // Map integration service progress (0-100%) to step progress (0.2-1.0)
          final installProgress = 0.2 + (progress / 100 * 0.8);
          stepProgressCallback?.call(installProgress, message);
        },
      );
      
      if (installResult.success) {
        print('✅ Dictionary installation completed');
        onProgress?.call('Dictionary installed successfully');
      } else {
        print('⚠️ Dictionary installation had issues');
        onProgress?.call('Dictionary files downloaded but installation had issues');
      }
      
    } catch (e) {
      print('❌ Dictionary installation error: $e');
      rethrow;
    }
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
      print('🧹 Cleaning up completed download: $packId');
      _activeDownloads.remove(packId);
    } else {
      // For failed or cancelled downloads, keep for a while for UI feedback
      Timer(const Duration(minutes: 5), () {
        _activeDownloads.remove(packId);
      });
    }
  }
  
  void _emitProgress(DownloadProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
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