// File Service Provider
// Riverpod provider for file operations and storage management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/core/services/file_service.dart';

// File service provider
final fileServiceProvider = Provider<FileService>((ref) {
  final service = FileService();
  // Initialize in main.dart before runApp
  return service;
});

// Storage info provider
final storageInfoProvider = FutureProvider<StorageInfo>((ref) async {
  final service = ref.watch(fileServiceProvider);
  return await service.getStorageInfo();
});

// Storage usage state provider for reactive updates
final storageUsageProvider = StateNotifierProvider<StorageUsageNotifier, StorageUsageState>((ref) {
  final service = ref.watch(fileServiceProvider);
  return StorageUsageNotifier(service);
});

class StorageUsageNotifier extends StateNotifier<StorageUsageState> {
  final FileService _service;
  
  StorageUsageNotifier(this._service) : super(const StorageUsageState.loading()) {
    _loadStorageInfo();
  }
  
  Future<void> _loadStorageInfo() async {
    try {
      final info = await _service.getStorageInfo();
      state = StorageUsageState.loaded(info);
    } catch (e) {
      state = StorageUsageState.error(e.toString());
    }
  }
  
  Future<void> refresh() async {
    state = const StorageUsageState.loading();
    await _loadStorageInfo();
  }
  
  Future<void> cleanupCache() async {
    await _service.cleanupCache();
    await refresh();
  }
}

class StorageUsageState {
  final StorageInfo? info;
  final bool isLoading;
  final String? error;
  
  const StorageUsageState({
    this.info,
    this.isLoading = false,
    this.error,
  });
  
  const StorageUsageState.loading() : this(isLoading: true);
  const StorageUsageState.loaded(StorageInfo info) : this(info: info);
  const StorageUsageState.error(String error) : this(error: error);
}