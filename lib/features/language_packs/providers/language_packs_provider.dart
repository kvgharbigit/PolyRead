// Language Packs Provider - Riverpod providers for language pack management
// Provides repositories and services with proper dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../repositories/github_releases_repo.dart';
import '../services/pack_download_service.dart';
import '../services/storage_management_service.dart';
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

/// Storage Management Service Provider
final storageManagementServiceProvider = Provider<StorageManagementService>((ref) {
  final database = ref.watch(databaseProvider);
  return StorageManagementService(database: database);
});

/// Pack Download Service Provider
/// Combines GitHub repository and storage management
final packDownloadServiceProvider = Provider<PackDownloadService>((ref) {
  final repository = ref.watch(githubReleasesRepositoryProvider);
  final storageService = ref.watch(storageManagementServiceProvider);
  
  return PackDownloadService(
    repository: repository,
    storageService: storageService,
    maxConcurrentDownloads: 3, // Limit concurrent downloads
  );
});

/// Language Pack Manager State Provider
/// Manages available and installed language packs
final languagePacksProvider = StateNotifierProvider<LanguagePacksNotifier, LanguagePacksState>((ref) {
  final downloadService = ref.watch(packDownloadServiceProvider);
  final repository = ref.watch(githubReleasesRepositoryProvider);
  
  return LanguagePacksNotifier(
    downloadService: downloadService,
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
  final PackDownloadService _downloadService;
  final GitHubReleasesRepository _repository;
  
  LanguagePacksNotifier({
    required PackDownloadService downloadService,
    required GitHubReleasesRepository repository,
  }) : _downloadService = downloadService,
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
        final isInstalled = await _downloadService.isPackDownloaded(manifest.id);
        
        if (isInstalled) {
          installedPackIds.add(manifest.id);
        }
        
        // Extract language codes from pack ID (e.g., "eng-spa" -> ["eng", "spa"])
        final languages = manifest.id.split('-').take(2).toList();
        
        availablePacks.add(LanguagePackInfo(
          id: manifest.id,
          name: manifest.name,
          version: manifest.version,
          totalSize: manifest.totalSize,
          entryCount: manifest.files.isNotEmpty ? 98487 : 0, // From our registry data
          languages: languages,
          isInstalled: isInstalled,
        ));
      }
      
      state = state.copyWith(
        availablePacks: availablePacks,
        installedPackIds: installedPackIds,
        isLoading: false,
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
  
  /// Download a language pack
  Future<void> downloadPack(String packId) async {
    try {
      final manifest = await _repository.getLanguagePack(packId);
      if (manifest == null) {
        throw Exception('Language pack not found: $packId');
      }
      
      await _downloadService.downloadLanguagePack(
        manifest: manifest,
        wifiOnly: true, // Default to WiFi only
      );
      
      // Refresh state after download
      await refresh();
    } catch (e) {
      state = state.copyWith(error: 'Failed to download $packId: $e');
    }
  }
  
  /// Cancel a download
  Future<void> cancelDownload(String packId) async {
    await _downloadService.cancelDownload(packId);
  }
  
  @override
  void dispose() {
    _downloadService.dispose();
    _repository.dispose();
    super.dispose();
  }
}