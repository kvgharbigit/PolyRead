// Language Pack Registry Service
// Fetches available language packs from GitHub registry and local registry

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class LanguagePackRegistryService {
  static const String _registryUrl = 'https://github.com/kvgharbigit/PolyRead/releases/download/language-packs-v2.0/comprehensive-registry.json';
  static const String _localRegistryPath = 'assets/language_packs/comprehensive-registry.json';
  
  final Dio _dio;
  
  LanguagePackRegistryService() : _dio = Dio() {
    // Configure Dio to handle GitHub redirects properly
    _dio.options.followRedirects = true;
    _dio.options.maxRedirects = 5;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }
  
  /// Get available language packs from registry (try remote first, fallback to local)
  Future<List<LanguagePackInfo>> getAvailableLanguagePacks() async {
    try {
      // Try to fetch from GitHub first
      final remoteRegistry = await _fetchRemoteRegistry();
      if (remoteRegistry != null) {
        print('LanguagePackRegistryService: Loaded registry from GitHub');
        return _parseLanguagePacks(remoteRegistry);
      }
    } catch (e) {
      print('LanguagePackRegistryService: Failed to fetch remote registry: $e');
    }
    
    try {
      // Fallback to local registry
      final localRegistry = await _fetchLocalRegistry();
      print('LanguagePackRegistryService: Loaded registry from local assets');
      return _parseLanguagePacks(localRegistry);
    } catch (e) {
      print('LanguagePackRegistryService: Failed to load local registry: $e');
      return _getHardcodedLanguagePacks();
    }
  }
  
  Future<Map<String, dynamic>?> _fetchRemoteRegistry() async {
    final response = await _dio.get(_registryUrl);
    if (response.statusCode == 200) {
      return response.data is String 
          ? jsonDecode(response.data) 
          : response.data;
    }
    return null;
  }
  
  Future<Map<String, dynamic>> _fetchLocalRegistry() async {
    final jsonString = await rootBundle.loadString(_localRegistryPath);
    return jsonDecode(jsonString);
  }
  
  List<LanguagePackInfo> _parseLanguagePacks(Map<String, dynamic> registry) {
    final packs = <LanguagePackInfo>[];
    final packsData = registry['packs'] as List? ?? [];
    
    for (final packData in packsData) {
      final pack = packData as Map<String, dynamic>;
      
      // Include main, bidirectional, and complete legacy packs (no companions) for UI display
      final packType = pack['pack_type'] as String?;
      final isHidden = pack['hidden'] == true;
      final packId = pack['id'] as String;
      
      // Use the most complete packs available (prefer legacy eng-spa over smaller es-en)
      // Include all non-companion packs that match our available files
      final availableFiles = ['de-en', 'eng-spa']; // Match actual GitHub files
      final shouldInclude = availableFiles.contains(packId) && packType != 'companion';
      
      if (shouldInclude) {
        packs.add(LanguagePackInfo(
          id: pack['id'] as String,
          name: pack['name'] as String,
          description: pack['description'] as String? ?? '',
          sourceLanguage: pack['source_language'] as String,
          targetLanguage: pack['target_language'] as String,
          entries: pack['entries'] as int? ?? 0,
          sizeBytes: pack['size_bytes'] as int? ?? 0,
          sizeMb: (pack['size_mb'] as num?)?.toDouble() ?? 0.0,
          downloadUrl: pack['download_url'] as String? ?? '',
          checksum: pack['checksum'] as String? ?? '',
          version: pack['version'] as String? ?? '1.0.0',
          packType: pack['pack_type'] as String? ?? 'main',
          isAvailable: true,
          priority: _determinePriority(pack),
        ));
      }
    }
    
    // Add coming soon packs that aren't in the registry yet
    packs.addAll(_getComingSoonPacks());
    
    return packs;
  }
  
  String _determinePriority(Map<String, dynamic> pack) {
    final sourceLanguage = pack['source_language'] as String;
    final targetLanguage = pack['target_language'] as String;
    
    // High priority: German, Spanish (already available)
    if ((sourceLanguage == 'de' && targetLanguage == 'en') ||
        (sourceLanguage == 'es' && targetLanguage == 'en')) {
      return 'high';
    }
    
    return 'medium';
  }
  
  List<LanguagePackInfo> _getComingSoonPacks() {
    return [
      LanguagePackInfo(
        id: 'fr-en',
        name: '🇫🇷 French ↔ 🇺🇸 English',
        description: 'Coming soon • High priority',
        sourceLanguage: 'fr',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
      LanguagePackInfo(
        id: 'it-en',
        name: '🇮🇹 Italian ↔ 🇺🇸 English',
        description: 'Coming soon • High priority',
        sourceLanguage: 'it',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
      LanguagePackInfo(
        id: 'pt-en',
        name: '🇵🇹 Portuguese ↔ 🇺🇸 English',
        description: 'Coming soon • Medium priority',
        sourceLanguage: 'pt',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
      LanguagePackInfo(
        id: 'ru-en',
        name: '🇷🇺 Russian ↔ 🇺🇸 English',
        description: 'Coming soon • Medium priority',
        sourceLanguage: 'ru',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
      LanguagePackInfo(
        id: 'ko-en',
        name: '🇰🇷 Korean ↔ 🇺🇸 English',
        description: 'Coming soon • Medium priority',
        sourceLanguage: 'ko',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
      LanguagePackInfo(
        id: 'ja-en',
        name: '🇯🇵 Japanese ↔ 🇺🇸 English',
        description: 'Coming soon • Medium priority',
        sourceLanguage: 'ja',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
      LanguagePackInfo(
        id: 'zh-en',
        name: '🇨🇳 Chinese ↔ 🇺🇸 English',
        description: 'Coming soon • Medium priority',
        sourceLanguage: 'zh',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
      LanguagePackInfo(
        id: 'ar-en',
        name: '🇸🇦 Arabic ↔ 🇺🇸 English',
        description: 'Coming soon • Medium priority',
        sourceLanguage: 'ar',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
      LanguagePackInfo(
        id: 'hi-en',
        name: '🇮🇳 Hindi ↔ 🇺🇸 English',
        description: 'Coming soon • Medium priority',
        sourceLanguage: 'hi',
        targetLanguage: 'en',
        entries: 0,
        sizeBytes: 0,
        sizeMb: 0.0,
        downloadUrl: '',
        checksum: '',
        version: '1.0.0',
        packType: 'coming-soon',
        isAvailable: false,
        priority: 'coming-soon',
      ),
    ];
  }
  
  List<LanguagePackInfo> _getHardcodedLanguagePacks() {
    print('LanguagePackRegistryService: Using hardcoded fallback language packs');
    return [
      LanguagePackInfo(
        id: 'de-en',
        name: '🇩🇪 German ↔ 🇺🇸 English',
        description: 'Wiktionary dictionary • 12,130 entries',
        sourceLanguage: 'de',
        targetLanguage: 'en',
        entries: 12130,
        sizeBytes: 823201,
        sizeMb: 0.8,
        downloadUrl: _registryUrl,
        checksum: '',
        version: '1.0.0',
        packType: 'main',
        isAvailable: true,
        priority: 'high',
      ),
      LanguagePackInfo(
        id: 'eng-spa',
        name: '🇪🇸 English ↔ Spanish',
        description: 'Complete Wiktionary dictionary • 11,598 entries',
        sourceLanguage: 'en',
        targetLanguage: 'es',
        entries: 11598,
        sizeBytes: 22272519,
        sizeMb: 21.2,
        downloadUrl: _registryUrl,
        checksum: '',
        version: '1.0.0',
        packType: 'legacy',
        isAvailable: true,
        priority: 'high',
      ),
    ]..addAll(_getComingSoonPacks());
  }
}

class LanguagePackInfo {
  final String id;
  final String name;
  final String description;
  final String sourceLanguage;
  final String targetLanguage;
  final int entries;
  final int sizeBytes;
  final double sizeMb;
  final String downloadUrl;
  final String checksum;
  final String version;
  final String packType;
  final bool isAvailable;
  final String priority;
  
  const LanguagePackInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.entries,
    required this.sizeBytes,
    required this.sizeMb,
    required this.downloadUrl,
    required this.checksum,
    required this.version,
    required this.packType,
    required this.isAvailable,
    required this.priority,
  });
  
  String get displayLabel => name;
  
  String get displayDescription {
    if (!isAvailable) return description;
    
    if (entries > 0) {
      return 'Wiktionary dictionary • ${entries.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} entries';
    }
    
    return description;
  }
}