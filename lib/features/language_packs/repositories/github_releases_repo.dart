// GitHub Releases Repository - Downloads language packs from GitHub releases
// Fetches manifests and download URLs from GitHub API

import 'dart:convert';
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
  
  /// Get all available language pack releases from registry
  Future<List<LanguagePackManifest>> getAvailableLanguagePacks() async {
    print('GitHubReleasesRepository: Starting getAvailableLanguagePacks...');
    print('GitHubReleasesRepository: Owner: $owner, Repository: $repository');
    
    try {
      // Get the specific language packs release
      final releaseUrl = '/repos/$owner/$repository/releases/tags/language-packs-v2.0';
      print('GitHubReleasesRepository: Fetching release from: $releaseUrl');
      
      final response = await _dio.get(releaseUrl);
      print('GitHubReleasesRepository: Release response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('GitHubReleasesRepository: ERROR - Failed to fetch release: ${response.statusCode}');
        throw LanguagePackException('Failed to fetch language packs release: ${response.statusCode}');
      }
      
      final release = response.data as Map<String, dynamic>;
      print('GitHubReleasesRepository: Release name: ${release['name']}');
      
      // Find the registry file in the release assets
      final assets = release['assets'] as List<dynamic>;
      
      final registryAsset = assets.firstWhere(
        (asset) => asset['name'] == 'comprehensive-registry.json',
        orElse: () => null,
      );
      
      if (registryAsset == null) {
        print('GitHubReleasesRepository: ERROR - Registry file not found in release');
        throw LanguagePackException('Registry file not found in release');
      }
      
      // Download and parse the registry file
      final registryResponse = await _dio.get(registryAsset['browser_download_url']);
      
      if (registryResponse.statusCode != 200) {
        print('GitHubReleasesRepository: ERROR - Failed to download registry: ${registryResponse.statusCode}');
        throw LanguagePackException('Failed to download registry: ${registryResponse.statusCode}');
      }
      
      // Parse JSON if it's a string
      final registryData = registryResponse.data;
      
      final registry = registryData is String 
          ? jsonDecode(registryData) as Map<String, dynamic>
          : registryData as Map<String, dynamic>;
      
      
      final packsData = registry['packs'];
      
      if (packsData == null) {
        print('GitHubReleasesRepository: ERROR - No packs found in registry');
        throw LanguagePackException('No packs found in registry');
      }
      
      // Handle both Map and List formats
      List<Map<String, dynamic>> packsList;
      if (packsData is Map<String, dynamic>) {
        packsList = packsData.entries.map((entry) {
          final packData = entry.value as Map<String, dynamic>;
          packData['id'] = entry.key;
          return packData;
        }).toList();
      } else if (packsData is List<dynamic>) {
        packsList = packsData.cast<Map<String, dynamic>>();
      } else {
        print('GitHubReleasesRepository: ERROR - Unknown packs format: ${packsData.runtimeType}');
        throw LanguagePackException('Unknown packs format in registry');
      }
      
      final manifests = <LanguagePackManifest>[];
      
      // Only include the most complete packs available
      final readyPacks = ['de-en', 'eng-spa']; // Use larger eng-spa (11,598 entries vs es-en 4,497 entries)
      for (final packData in packsList) {
        final packId = packData['id'] as String?;
        
        if (packId == null) {
          continue;
        }
        
        // Only include packs that actually exist and are available
        if (readyPacks.contains(packId)) {
          manifests.add(_createManifestFromRegistry(packId, packData, release));
        }
      }
      
      print('GitHubReleasesRepository: Found ${manifests.length} available language packs');
      
      return manifests;
    } catch (e) {
      print('GitHubReleasesRepository: ERROR - Failed to get available language packs: $e');
      print('GitHubReleasesRepository: Error type: ${e.runtimeType}');
      throw LanguagePackException('Failed to get available language packs: $e');
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
  
  /// Create a manifest from registry data
  LanguagePackManifest _createManifestFromRegistry(
    String packId, 
    Map<String, dynamic> packData, 
    Map<String, dynamic> release
  ) {
    final assets = release['assets'] as List<dynamic>;
    
    // Find the corresponding .sqlite.zip file
    final sqliteAsset = assets.firstWhere(
      (asset) => asset['name'] == '$packId.sqlite.zip',
      orElse: () => null,
    );
    
    if (sqliteAsset == null) {
      throw LanguagePackException('SQLite file not found for pack $packId');
    }
    
    // Extract language codes from pack ID (e.g., "eng-spa" -> ["eng", "spa"])
    final languages = packId.split('-');
    final sourceLanguage = languages.isNotEmpty ? languages[0] : 'unknown';
    final targetLanguage = languages.length > 1 ? languages[1] : 'unknown';
    
    // Convert 3-letter codes to 2-letter codes
    final sourceCode = _convertLanguageCode(sourceLanguage);
    final targetCode = _convertLanguageCode(targetLanguage);
    
    return LanguagePackManifest(
      id: '$sourceCode-$targetCode',
      name: '$sourceCode ↔ $targetCode Dictionary (Bidirectional)',
      language: sourceCode,
      version: packData['version'] ?? '2.0.0',
      description: packData['description'] ?? 'Single bidirectional dictionary with optimized lookup for both $sourceCode ↔ $targetCode directions',
      totalSize: sqliteAsset['size'] ?? 0,
      files: [
        LanguagePackFile(
          name: '$packId.sqlite.zip',
          path: '$packId.sqlite.zip',
          type: LanguagePackFileType.dictionary,
          size: sqliteAsset['size'] ?? 0,
          checksum: packData['checksum'] ?? '',
          downloadUrl: sqliteAsset['browser_download_url'],
        ),
      ],
      supportedTargetLanguages: [targetCode, sourceCode], // Bidirectional support
      releaseDate: DateTime.parse(release['published_at']),
      author: 'PolyRead Team',
      license: 'CC BY-SA 4.0',
    );
  }
  
  /// Convert 3-letter language codes to 2-letter codes
  String _convertLanguageCode(String code) {
    switch (code) {
      case 'eng': return 'en';
      case 'spa': return 'es';
      case 'fra': return 'fr';
      case 'deu': return 'de';
      case 'ita': return 'it';
      case 'por': return 'pt';
      case 'rus': return 'ru';
      default: return code;
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