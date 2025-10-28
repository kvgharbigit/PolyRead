// GitHub Releases Repository - Downloads language packs from GitHub releases
// Fetches manifests and download URLs from GitHub API

import 'package:dio/dio.dart';
import '../models/language_pack_manifest.dart';

class GitHubReleasesRepository {
  final Dio _dio;
  final String owner;
  final String repository;
  final String? githubToken;
  
  GitHubReleasesRepository({
    required this.owner,
    required this.repository,
    this.githubToken,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    // Configure dio with GitHub API settings
    _dio.options.baseUrl = 'https://api.github.com';
    _dio.options.headers = {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'PolyRead-LanguagePacks/1.0',
      if (githubToken != null) 'Authorization': 'token $githubToken',
    };
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
  }
  
  /// Get all available language pack releases
  Future<List<LanguagePackManifest>> getAvailableLanguagePacks() async {
    try {
      final response = await _dio.get('/repos/$owner/$repository/releases');
      
      if (response.statusCode != 200) {
        throw LanguagePackException('Failed to fetch releases: ${response.statusCode}');
      }
      
      final releases = response.data as List<dynamic>;
      final manifests = <LanguagePackManifest>[];
      
      for (final release in releases) {
        try {
          final manifest = await _parseReleaseToManifest(release as Map<String, dynamic>);
          if (manifest != null) {
            manifests.add(manifest);
          }
        } catch (e) {
          // Skip invalid releases but continue processing others
          print('Skipping invalid release: $e');
        }
      }
      
      return manifests;
    } catch (e) {
      throw LanguagePackException('Failed to fetch language packs: $e');
    }
  }
  
  /// Get a specific language pack by ID
  Future<LanguagePackManifest?> getLanguagePack(String packId) async {
    try {
      final response = await _dio.get('/repos/$owner/$repository/releases/tags/$packId');
      
      if (response.statusCode == 404) {
        return null;
      }
      
      if (response.statusCode != 200) {
        throw LanguagePackException('Failed to fetch release: ${response.statusCode}');
      }
      
      return await _parseReleaseToManifest(response.data as Map<String, dynamic>);
    } catch (e) {
      throw LanguagePackException('Failed to fetch language pack $packId: $e');
    }
  }
  
  /// Download a language pack file
  Future<void> downloadPackFile({
    required String downloadUrl,
    required String destinationPath,
    required Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        downloadUrl,
        destinationPath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: const Duration(minutes: 30), // Longer timeout for large files
          headers: {
            // Remove authorization for direct download URLs
            'Authorization': null,
          },
        ),
      );
    } catch (e) {
      throw LanguagePackException('Failed to download file: $e');
    }
  }
  
  /// Check if a new version is available for a language pack
  Future<bool> isUpdateAvailable({
    required String packId,
    required String currentVersion,
  }) async {
    try {
      final latestPack = await getLanguagePack(packId);
      if (latestPack == null) return false;
      
      return _isNewerVersion(latestPack.version, currentVersion);
    } catch (e) {
      return false; // Assume no update if check fails
    }
  }
  
  /// Get release notes for a language pack version
  Future<String?> getReleaseNotes(String packId) async {
    try {
      final response = await _dio.get('/repos/$owner/$repository/releases/tags/$packId');
      
      if (response.statusCode != 200) return null;
      
      final release = response.data as Map<String, dynamic>;
      return release['body'] as String?;
    } catch (e) {
      return null;
    }
  }
  
  Future<LanguagePackManifest?> _parseReleaseToManifest(Map<String, dynamic> release) async {
    try {
      // Look for manifest.json in release assets
      final assets = release['assets'] as List<dynamic>;
      
      Map<String, dynamic>? manifestAsset;
      for (final asset in assets) {
        if (asset['name'] == 'manifest.json') {
          manifestAsset = asset as Map<String, dynamic>;
          break;
        }
      }
      
      if (manifestAsset == null) {
        print('No manifest.json found in release ${release['tag_name']}');
        return null;
      }
      
      // Download and parse manifest
      final manifestUrl = manifestAsset['browser_download_url'] as String;
      final manifestResponse = await _dio.get(manifestUrl);
      
      if (manifestResponse.statusCode != 200) {
        throw LanguagePackException('Failed to download manifest');
      }
      
      final manifestData = manifestResponse.data as Map<String, dynamic>;
      
      // Update download URLs to use GitHub release asset URLs
      final files = <LanguagePackFile>[];
      for (final fileData in manifestData['files'] as List<dynamic>) {
        final fileName = fileData['name'] as String;
        
        // Find matching asset
        String? downloadUrl;
        for (final asset in assets) {
          if (asset['name'] == fileName) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }
        
        if (downloadUrl == null) {
          print('Asset not found for file: $fileName');
          continue;
        }
        
        files.add(LanguagePackFile.fromJson({
          ...fileData as Map<String, dynamic>,
          'download_url': downloadUrl,
        }));
      }
      
      // Create manifest with updated file URLs
      return LanguagePackManifest.fromJson({
        ...manifestData,
        'files': files.map((f) => f.toJson()).toList(),
      });
    } catch (e) {
      throw LanguagePackException('Failed to parse release manifest: $e');
    }
  }
  
  bool _isNewerVersion(String newVersion, String currentVersion) {
    // Simple version comparison - assumes semantic versioning
    final newParts = newVersion.split('.').map(int.parse).toList();
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    
    // Pad shorter version with zeros
    while (newParts.length < currentParts.length) newParts.add(0);
    while (currentParts.length < newParts.length) currentParts.add(0);
    
    for (int i = 0; i < newParts.length; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }
    
    return false; // Versions are equal
  }
  
  void dispose() {
    _dio.close();
  }
}

class LanguagePackException implements Exception {
  final String message;
  const LanguagePackException(this.message);
  
  @override
  String toString() => 'LanguagePackException: $message';
}