// Language Pack Registry Service
// Fetches available language packs from GitHub registry and local registry

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class LanguagePackRegistryService {
  static const String _registryUrl = 'https://github.com/kvgharbigit/PolyRead/releases/download/language-packs-v2.1/comprehensive-registry.json';
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
    
    // Keep track of which actual files we've found in registry
    final foundPacks = <String>{};
    
    for (final packData in packsData) {
      final pack = packData as Map<String, dynamic>;
      
      final packType = pack['pack_type'] as String?;
      final isHidden = pack['hidden'] == true;
      final packId = pack['id'] as String;
      
      // Include all non-companion packs
      final shouldInclude = packType != 'companion' && !isHidden;
      
      if (shouldInclude) {
        foundPacks.add(packId);
        
        // Use registry data directly
        packs.add(LanguagePackInfo(
          id: packId,
          name: pack['name'] as String? ?? '$packId Dictionary',
          description: pack['description'] as String? ?? 'Bidirectional dictionary • Wiktionary source',
          sourceLanguage: pack['source_language'] as String? ?? packId.split('-')[0],
          targetLanguage: pack['target_language'] as String? ?? packId.split('-')[1], 
          entries: pack['entries'] as int? ?? 0,
          sizeBytes: pack['size_bytes'] as int? ?? 0,
          sizeMb: (pack['size_mb'] as num?)?.toDouble() ?? 0.0,
          downloadUrl: pack['download_url'] as String? ?? 'https://github.com/kvgharbigit/PolyRead/releases/download/language-packs-v2.1/$packId.sqlite.zip',
          checksum: pack['checksum'] as String? ?? '',
          version: pack['version'] as String? ?? '2.0.0',
          packType: pack['pack_type'] as String? ?? 'main',
          isAvailable: true,
          priority: 'high',
        ));
      }
    }
    
    // Registry should now be comprehensive - no need for fallback missing packs
    // final missingPacks = ['de-en', 'es-en'].where((pack) => !foundPacks.contains(pack)).toList();
    // for (final packId in missingPacks) {
    //   final parts = packId.split('-');
    //   final sourceCode = parts[0];
    //   final targetCode = parts[1];
    //   
    //   packs.add(LanguagePackInfo(
    //     id: packId,
    //     name: '${_getLanguageName(sourceCode)} ↔ ${_getLanguageName(targetCode)}',
    //     description: 'Bidirectional dictionary • Wiktionary source',
    //     sourceLanguage: sourceCode,
    //     targetLanguage: targetCode,
    //     entries: packId == 'de-en' ? 30492 : 29548, // Known entry counts
    //     sizeBytes: packId == 'de-en' ? 1609110 : 1487456, // Actual GitHub file sizes
    //     sizeMb: packId == 'de-en' ? 1.6 : 1.5,
    //     downloadUrl: 'https://github.com/kvgharbigit/PolyRead/releases/download/language-packs-v2.0/$packId.sqlite.zip',
    //     checksum: '',
    //     version: '2.0.0',
    //     packType: 'main',
    //     isAvailable: true,
    //     priority: 'high',
    //   ));
    // }
    
    // Registry now contains all available packs - no coming soon needed
    
    return packs;
  }
  
  String _getLanguageName(String code) {
    switch (code) {
      case 'de': return '🇩🇪 German';
      case 'en': return '🇺🇸 English';
      case 'es': return '🇪🇸 Spanish';
      case 'fr': return '🇫🇷 French';
      case 'it': return '🇮🇹 Italian';
      case 'pt': return '🇵🇹 Portuguese';
      case 'ru': return '🇷🇺 Russian';
      default: return code.toUpperCase();
    }
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
  
  
  List<LanguagePackInfo> _getHardcodedLanguagePacks() {
    print('LanguagePackRegistryService: Using hardcoded fallback language packs');
    return [
      LanguagePackInfo(
        id: 'es-en',
        name: '🇪🇸 Spanish ↔ 🇺🇸 English',
        description: 'Vuizur Wiktionary • 1,086,098 entries',
        sourceLanguage: 'es',
        targetLanguage: 'en',
        entries: 1086098,
        sizeBytes: 77522254, // Actual GitHub file size (74MB)
        sizeMb: 74.0,
        downloadUrl: 'https://github.com/kvgharbigit/PolyRead/releases/download/language-packs-v2.1/es-en.sqlite.zip',
        checksum: '',
        version: '2.1.0',
        packType: 'main',
        isAvailable: true,
        priority: 'high',
      ),
    ];
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