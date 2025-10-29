// Language Packs Provider - Riverpod providers for language pack management
// Provides repositories and services with proper dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../repositories/github_releases_repo.dart';
import '../services/combined_language_pack_service.dart';
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
  
  return CombinedLanguagePackService(
    database: database,
    repository: repository,
  );
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
  
  /// Download a language pack (dictionary + ML Kit models)
  Future<void> downloadPack(String packId) async {
    print('');
    print('++++++++++++++++++++++++++++++++++++++++++++');
    print('LanguagePacksProvider.downloadPack: ENTRY POINT');
    print('LanguagePacksProvider.downloadPack: Pack ID: $packId');
    print('LanguagePacksProvider.downloadPack: Current state: isLoading=${state.isLoading}, error=${state.error}');
    print('LanguagePacksProvider.downloadPack: Available packs: ${state.availablePacks.length}');
    print('LanguagePacksProvider.downloadPack: Installed pack IDs: ${state.installedPackIds}');
    print('++++++++++++++++++++++++++++++++++++++++++++');
    
    try {
      // Extract languages from pack ID
      final parts = packId.split('-');
      print('LanguagePacksProvider.downloadPack: Step 1 - Pack ID parts: $parts');
      
      if (parts.length < 2) {
        print('LanguagePacksProvider.downloadPack: ❌ VALIDATION ERROR - Invalid pack ID format: $packId');
        throw Exception('Invalid pack ID format: $packId');
      }
      
      final sourceLanguage = parts[0];
      final targetLanguage = parts[1];
      print('LanguagePacksProvider.downloadPack: Step 2 - Extracted languages:');
      print('  - Source: $sourceLanguage');
      print('  - Target: $targetLanguage');
      
      print('LanguagePacksProvider.downloadPack: Step 3 - Calling combinedService.installLanguagePack...');
      print('LanguagePacksProvider.downloadPack: Service instance: $_combinedService');
      
      await _combinedService.installLanguagePack(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        wifiOnly: true,
        onProgress: (message) {
          print('LanguagePacksProvider.downloadPack: 📝 PROGRESS - $message');
        },
      );
      
      print('');
      print('LanguagePacksProvider.downloadPack: Step 4 - ✅ Installation completed successfully');
      
      // Refresh state after download
      print('LanguagePacksProvider.downloadPack: Step 5 - Refreshing provider state...');
      await refresh();
      print('LanguagePacksProvider.downloadPack: Step 6 - State refresh completed');
      print('LanguagePacksProvider.downloadPack: New state: isLoading=${state.isLoading}, error=${state.error}');
      print('LanguagePacksProvider.downloadPack: New installed pack IDs: ${state.installedPackIds}');
      
    } catch (e) {
      print('');
      print('LanguagePacksProvider.downloadPack: ❌❌❌ DOWNLOAD FAILED ❌❌❌');
      print('LanguagePacksProvider.downloadPack: Error: $e');
      print('LanguagePacksProvider.downloadPack: Error type: ${e.runtimeType}');
      print('LanguagePacksProvider.downloadPack: Stack trace:');
      print(StackTrace.current);
      
      print('LanguagePacksProvider.downloadPack: Setting error state...');
      state = state.copyWith(error: 'Failed to download $packId: $e');
      print('LanguagePacksProvider.downloadPack: Error state set: ${state.error}');
      
      rethrow; // Re-throw to propagate to UI
    }
    
    print('++++++++++++++++++++++++++++++++++++++++++++');
    print('LanguagePacksProvider.downloadPack: EXIT POINT');
    print('++++++++++++++++++++++++++++++++++++++++++++');
    print('');
  }
  
  /// Cancel a download
  Future<void> cancelDownload(String packId) async {
    await _combinedService.cancelInstallation(packId);
  }
  
  @override
  void dispose() {
    _combinedService.dispose();
    _repository.dispose();
    super.dispose();
  }
}