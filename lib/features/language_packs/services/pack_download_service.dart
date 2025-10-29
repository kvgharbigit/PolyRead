// Language Pack Download Service - Manages pack downloads with progress tracking
// Handles concurrent downloads, storage limits, and validation

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/language_pack_manifest.dart';
import '../models/download_progress.dart';
import '../repositories/github_releases_repo.dart';
import '../services/storage_management_service.dart';

class PackDownloadService {
  final GitHubReleasesRepository _repository;
  final StorageManagementService _storageService;
  final int maxConcurrentDownloads;
  
  final Map<String, DownloadProgress> _activeDownloads = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final StreamController<DownloadProgress> _progressController = StreamController.broadcast();
  
  PackDownloadService({
    required GitHubReleasesRepository repository,
    required StorageManagementService storageService,
    this.maxConcurrentDownloads = 3,
  }) : _repository = repository,
       _storageService = storageService;
  
  /// Stream of download progress updates
  Stream<DownloadProgress> get progressStream => _progressController.stream;
  
  /// Get current download progress for a pack
  DownloadProgress? getDownloadProgress(String packId) {
    return _activeDownloads[packId];
  }
  
  /// Get all active downloads
  List<DownloadProgress> get activeDownloads => _activeDownloads.values.toList();
  
  /// Download a language pack
  Future<void> downloadLanguagePack({
    required LanguagePackManifest manifest,
    bool wifiOnly = true,
  }) async {
    if (_activeDownloads.containsKey(manifest.id)) {
      throw LanguagePackException('Download already in progress for ${manifest.id}');
    }
    
    // Check storage availability
    final hasSpace = await _storageService.checkSpaceAvailable(manifest.totalSize);
    if (!hasSpace) {
      throw LanguagePackException('Insufficient storage space for ${manifest.name}');
    }
    
    // Check network conditions if wifiOnly is enabled
    if (wifiOnly && !await _isWifiConnected()) {
      throw LanguagePackException('WiFi connection required for download');
    }
    
    // Initialize download progress
    final progress = DownloadProgress.initial(
      packId: manifest.id,
      packName: manifest.name,
      totalBytes: manifest.totalSize,
      totalFiles: manifest.files.length,
    );
    
    _activeDownloads[manifest.id] = progress;
    _cancelTokens[manifest.id] = CancelToken();
    _emitProgress(progress);
    
    try {
      await _performDownload(manifest);
    } catch (e) {
      final failedProgress = progress.fail(e.toString());
      _activeDownloads[manifest.id] = failedProgress;
      _emitProgress(failedProgress);
      rethrow;
    } finally {
      _cleanupDownload(manifest.id);
    }
  }
  
  /// Cancel a download
  Future<void> cancelDownload(String packId) async {
    final cancelToken = _cancelTokens[packId];
    if (cancelToken != null) {
      cancelToken.cancel('Download cancelled by user');
    }
    
    final progress = _activeDownloads[packId];
    if (progress != null) {
      final cancelledProgress = progress.cancel();
      _activeDownloads[packId] = cancelledProgress;
      _emitProgress(cancelledProgress);
    }
    
    // Clean up partial files
    await _cleanupPartialDownload(packId);
  }
  
  /// Pause a download (if supported)
  Future<void> pauseDownload(String packId) async {
    // For now, we'll treat pause as cancel
    // In a full implementation, this would require resumable downloads
    await cancelDownload(packId);
  }
  
  /// Check if a language pack is already downloaded
  Future<bool> isPackDownloaded(String packId) async {
    return await _storageService.isPackInstalled(packId);
  }
  
  /// Get download directory for language packs
  Future<Directory> getDownloadDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final downloadDir = Directory(path.join(appDir.path, 'language_packs'));
    
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    
    return downloadDir;
  }
  
  Future<void> _performDownload(LanguagePackManifest manifest) async {
    final downloadDir = await getDownloadDirectory();
    final packDir = Directory(path.join(downloadDir.path, manifest.id));
    
    // Create pack directory
    if (!await packDir.exists()) {
      await packDir.create(recursive: true);
    }
    
    var currentProgress = _activeDownloads[manifest.id]!.copyWith(
      status: DownloadStatus.downloading,
    );
    _activeDownloads[manifest.id] = currentProgress;
    _emitProgress(currentProgress);
    
    // Download each file
    int totalDownloaded = 0;
    
    for (int i = 0; i < manifest.files.length; i++) {
      final file = manifest.files[i];
      final cancelToken = _cancelTokens[manifest.id];
      
      if (cancelToken?.isCancelled == true) {
        throw LanguagePackException('Download cancelled');
      }
      
      final filePath = path.join(packDir.path, file.name);
      
      // Update progress for current file
      currentProgress = currentProgress.copyWith(
        currentFile: file.name,
      );
      _activeDownloads[manifest.id] = currentProgress;
      _emitProgress(currentProgress);
      
      // Download file with progress tracking
      await _repository.downloadPackFile(
        downloadUrl: file.downloadUrl,
        destinationPath: filePath,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          final fileProgress = currentProgress.updateFileProgress(
            fileName: file.name,
            fileDownloadedBytes: received,
            fileTotalBytes: total,
          );
          _activeDownloads[manifest.id] = fileProgress;
          _emitProgress(fileProgress);
        },
      );
      
      // Verify file checksum
      if (!await _verifyFileChecksum(filePath, file.checksum)) {
        throw LanguagePackException('Checksum verification failed for ${file.name}');
      }
      
      // Update progress after file completion
      totalDownloaded += file.size;
      currentProgress = currentProgress.completeFile().copyWith(
        downloadedBytes: totalDownloaded,
      );
      _activeDownloads[manifest.id] = currentProgress;
      _emitProgress(currentProgress);
    }
    
    // Save manifest file
    final manifestPath = path.join(packDir.path, 'manifest.json');
    final manifestFile = File(manifestPath);
    await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
    
    // Register installation with storage service
    await _storageService.registerPackInstallation(
      packId: manifest.id,
      version: manifest.version,
      totalSize: manifest.totalSize,
      files: manifest.files.map((f) => f.name).toList(),
    );
    
    // Mark download as completed
    final completedProgress = currentProgress.complete();
    _activeDownloads[manifest.id] = completedProgress;
    _emitProgress(completedProgress);
  }
  
  Future<bool> _verifyFileChecksum(String filePath, String expectedChecksum) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      final actualChecksum = digest.toString();
      
      return actualChecksum == expectedChecksum;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> _isWifiConnected() async {
    // In a real implementation, would check connectivity
    // For now, assume WiFi is always available
    return true;
  }
  
  Future<void> _cleanupPartialDownload(String packId) async {
    try {
      final downloadDir = await getDownloadDirectory();
      final packDir = Directory(path.join(downloadDir.path, packId));
      
      if (await packDir.exists()) {
        await packDir.delete(recursive: true);
      }
    } catch (e) {
      // Log error but don't throw
      print('Failed to cleanup partial download: $e');
    }
  }
  
  void _cleanupDownload(String packId) {
    _cancelTokens.remove(packId);
    // Keep progress for a while for UI display
    Timer(const Duration(minutes: 5), () {
      _activeDownloads.remove(packId);
    });
  }
  
  void _emitProgress(DownloadProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
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
  }
}