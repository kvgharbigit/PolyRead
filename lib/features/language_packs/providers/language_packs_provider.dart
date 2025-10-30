// Language Packs Provider - Riverpod providers for language pack management
// Provides repositories and services with proper dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../repositories/github_releases_repo.dart';
import '../services/combined_language_pack_service.dart';
import '../models/download_progress.dart';
import '../../../core/utils/constants.dart';
import '../../../core/providers/database_provider.dart';

/// GitHub Releases Repository Provider
/// Configured to use the correct repository (kvgharbigit/PolyRead)
final githubReleasesRepositoryProvider = Provider<GitHubReleasesRepository>((ref) {
  return GitHubReleasesRepository(
    owner: AppConstants.githubOwner,
    repository: AppConstants.githubRepository,
    dio: Dio(), // Fresh Dio instance for language pack downloads
  );
});

/// Combined Language Pack Service Provider
/// Handles both dictionary and ML Kit model downloads in one action
final combinedLanguagePackServiceProvider = Provider<CombinedLanguagePackService>((ref) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(githubReleasesRepositoryProvider);
  
  return CombinedLanguagePackService(database, repository);
});

/// Download Progress Stream Provider
/// Provides real-time download progress updates for UI consumption
final downloadProgressStreamProvider = StreamProvider<DownloadProgress>((ref) {
  final combinedService = ref.watch(combinedLanguagePackServiceProvider);
  return combinedService.progressStream;
});

/// Language Pack Manager State Provider
/// Manages available and installed language packs
final languagePacksProvider = StateNotifierProvider<LanguagePacksNotifier, LanguagePacksState>((ref) {
  final combinedService = ref.watch(combinedLanguagePackServiceProvider);
  final repository = ref.watch(githubReleasesRepositoryProvider);
  
  return LanguagePacksNotifier(
    combinedService: combinedService,
    repository: repository,
  );
});

/// Language Packs State
class LanguagePacksState {
  final List<LanguagePackInfo> availablePacks;
  final List<String> installedPackIds;
  final bool isLoading;
  final String? error;
  
  const LanguagePacksState({
    this.availablePacks = const [],
    this.installedPackIds = const [],
    this.isLoading = false,
    this.error,
  });
  
  LanguagePacksState copyWith({
    List<LanguagePackInfo>? availablePacks,
    List<String>? installedPackIds,
    bool? isLoading,
    String? error,
  }) {
    return LanguagePacksState(
      availablePacks: availablePacks ?? this.availablePacks,
      installedPackIds: installedPackIds ?? this.installedPackIds,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Language Pack Information
class LanguagePackInfo {
  final String id;
  final String name;
  final String version;
  final int totalSize;
  final int entryCount;
  final List<String> languages;
  final bool isInstalled;
  
  const LanguagePackInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.totalSize,
    required this.entryCount,
    required this.languages,
    required this.isInstalled,
  });
}

/// Language Packs State Notifier
class LanguagePacksNotifier extends StateNotifier<LanguagePacksState> {
  final CombinedLanguagePackService _combinedService;
  final GitHubReleasesRepository _repository;
  
  LanguagePacksNotifier({
    required CombinedLanguagePackService combinedService,
    required GitHubReleasesRepository repository,
  }) : _combinedService = combinedService,
       _repository = repository,
       super(const LanguagePacksState()) {
    _loadLanguagePacks();
  }
  
  /// Load available language packs from GitHub releases
  Future<void> _loadLanguagePacks() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final manifests = await _repository.getAvailableLanguagePacks();
      final availablePacks = <LanguagePackInfo>[];
      final installedPackIds = <String>[];
      
      for (final manifest in manifests) {
        // Extract languages from manifest ID (e.g., "en-es" -> en, es)
        final parts = manifest.id.split('-');
        final sourceLanguage = parts.isNotEmpty ? parts[0] : 'en';
        final targetLanguage = parts.length > 1 ? parts[1] : 'es';
        
        final isInstalled = await _combinedService.isLanguagePackInstalled(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        if (isInstalled) {
          installedPackIds.add(manifest.id);
        }
        
        // Extract language codes from pack ID (e.g., "eng-spa" -> ["eng", "spa"])
        final languages = manifest.id.split('-').take(2).toList();
        
        // Get entry count from manifest metadata or estimate based on language pair
        final entryCount = _getEstimatedEntryCount(manifest.id, manifest.metadata);
        
        availablePacks.add(LanguagePackInfo(
          id: manifest.id,
          name: manifest.name,
          version: manifest.version,
          totalSize: manifest.totalSize,
          entryCount: entryCount,
          languages: languages,
          isInstalled: isInstalled,
        ));
      }
      
      state = state.copyWith(
        availablePacks: availablePacks,
        installedPackIds: installedPackIds,
        isLoading: false,
        error: null, // Clear any previous errors on successful load
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load language packs: $e',
      );
    }
  }
  
  /// Refresh language packs list
  Future<void> refresh() async {
    await _loadLanguagePacks();
  }
  
  // Mutex to prevent concurrent state updates
  bool _isUpdating = false;
  
  /// Update only the installed packs list (lightweight refresh after installation)
  Future<void> _updateInstalledPacksOnly() async {
    // Prevent concurrent updates that could cause race conditions
    if (_isUpdating) {
      print('LanguagePacksProvider: Update already in progress, skipping...');
      return;
    }
    
    _isUpdating = true;
    try {
      print('LanguagePacksProvider: Starting _updateInstalledPacksOnly...');
      
      // Small delay to ensure database transaction is committed
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Take snapshot of current state to avoid race conditions
      final currentAvailablePacks = List<LanguagePackInfo>.from(state.availablePacks);
      final installedPackIds = <String>[];
      
      // Update the installed status for existing available packs
      final updatedAvailablePacks = <LanguagePackInfo>[];
      
      for (final pack in currentAvailablePacks) {
        final parts = pack.id.split('-');
        final sourceLanguage = parts.isNotEmpty ? parts[0] : 'en';
        final targetLanguage = parts.length > 1 ? parts[1] : 'es';
        
        print('LanguagePacksProvider: Checking installation status for ${pack.id} ($sourceLanguage-$targetLanguage)');
        
        final isInstalled = await _combinedService.isLanguagePackInstalled(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        print('LanguagePacksProvider: Pack ${pack.id} installed status: $isInstalled');
        
        if (isInstalled) {
          installedPackIds.add(pack.id);
        }
        
        // Create updated pack info with new installed status
        updatedAvailablePacks.add(LanguagePackInfo(
          id: pack.id,
          name: pack.name,
          version: pack.version,
          totalSize: pack.totalSize,
          entryCount: pack.entryCount,
          languages: pack.languages,
          isInstalled: isInstalled,
        ));
      }
      
      // Atomic state update to prevent race conditions
      if (mounted) {
        state = state.copyWith(
          availablePacks: updatedAvailablePacks,
          installedPackIds: installedPackIds,
          error: null,
        );
      }
      
      print('LanguagePacksProvider: Updated installed packs: $installedPackIds');
      print('LanguagePacksProvider: _updateInstalledPacksOnly completed successfully');
      
    } catch (e) {
      print('LanguagePacksProvider: Error updating installed packs: $e');
      print('LanguagePacksProvider: Error stack trace: ${StackTrace.current}');
      // Don't set error state since this is a minor refresh operation
    } finally {
      _isUpdating = false;
    }
  }
  
  /// Download a language pack (dictionary + ML Kit models)
  Future<void> downloadPack(String packId) async {
    try {
      // Extract languages from pack ID
      final parts = packId.split('-');
      
      if (parts.length < 2) {
        throw Exception('Invalid pack ID format: $packId');
      }
      
      final sourceLanguage = parts[0];
      final targetLanguage = parts[1];
      
      await _combinedService.installLanguagePack(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        wifiOnly: true,
        onProgress: (message) {
          // Keep minimal progress logging
          print('Language pack download: $message');
        },
      );
      
      // Clear any previous error state since installation succeeded
      if (mounted) {
        state = state.copyWith(error: null);
      }
      
      // Simple state update - prevent infinite rebuilds
      print('LanguagePacksProvider: Installation completed, updating state...');
      
      // Add the pack ID directly to installed list with race condition protection
      if (mounted && !_isUpdating) {
        final currentIds = List<String>.from(state.installedPackIds);
        if (!currentIds.contains(packId)) {
          currentIds.add(packId);
          state = state.copyWith(
            installedPackIds: currentIds,
            error: null,
          );
          print('LanguagePacksProvider: Added $packId to installed packs: $currentIds');
        }
      }
      
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: 'Failed to download $packId: $e');
      }
      rethrow; // Re-throw to propagate to UI
    }
  }
  
  /// Force check installed packs directly from database (fallback)
  Future<void> _forceCheckInstalledPacks(String packId) async {
    try {
      print('LanguagePacksProvider: Force checking database for pack: $packId');
      
      // Longer delay to ensure database commit
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Direct database check
      final installedPacks = await _combinedService.getInstalledLanguagePacks();
      final installedPackIds = installedPacks.map((pack) => pack.packId).toList();
      
      print('LanguagePacksProvider: Database contains installed packs: $installedPackIds');
      
      if (installedPackIds.contains(packId)) {
        print('LanguagePacksProvider: Pack $packId confirmed installed in database');
        
        // Update state to include the newly installed pack
        final currentIds = state.installedPackIds.toList();
        if (!currentIds.contains(packId)) {
          currentIds.add(packId);
          
          state = state.copyWith(
            installedPackIds: currentIds,
            error: null,
          );
          
          print('LanguagePacksProvider: Force updated installed packs: $currentIds');
        }
      } else {
        print('LanguagePacksProvider: Pack $packId NOT found in database - installation may have failed');
      }
      
    } catch (e) {
      print('LanguagePacksProvider: Error in force check: $e');
    }
  }
  
  /// Cancel a download
  Future<void> cancelDownload(String packId) async {
    await _combinedService.cancelInstallation(packId);
  }
  
  /// Get estimated entry count for a language pack
  int _getEstimatedEntryCount(String packId, Map<String, dynamic> metadata) {
    // First check if manifest contains actual entry count
    if (metadata.containsKey('entry_count')) {
      return metadata['entry_count'] as int;
    }
    
    // Fallback to known entry counts for Vuizur v2.1 system
    final knownCounts = {
      'es-en': 2172196,  // Spanish-English Vuizur Wiktionary v2.1 (total entries)
      // Future Vuizur language pairs will be added here
    };
    
    return knownCounts[packId] ?? 50000; // Default estimate for unknown packs
  }
  
  @override
  void dispose() {
    _combinedService.dispose();
    _repository.dispose();
    super.dispose();
  }
}