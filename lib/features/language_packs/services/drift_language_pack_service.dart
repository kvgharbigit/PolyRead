// Drift Language Pack Service - Manages language packs using Drift database
// Handles installation, tracking, and bundled dictionary + ML Kit downloads

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../models/language_pack_manifest.dart';

class DriftLanguagePackService {
  final AppDatabase _database;
  
  DriftLanguagePackService(this._database);
  
  /// Check if a language pack is installed
  Future<bool> isPackInstalled(String packId) async {
    final query = _database.select(_database.languagePacks)
      ..where((pack) => pack.packId.equals(packId) & pack.isInstalled.equals(true));
    
    final results = await query.get();
    return results.isNotEmpty;
  }
  
  /// Validate pack integrity and detect broken installations
  Future<PackValidationResult> validatePack(String packId) async {
    try {
      // Check database record
      final query = _database.select(_database.languagePacks)
        ..where((pack) => pack.packId.equals(packId));
      final results = await query.get();
      
      if (results.isEmpty) {
        return PackValidationResult(packId, false, 'Pack not found in database');
      }
      
      final pack = results.first;
      if (!pack.isInstalled) {
        return PackValidationResult(packId, false, 'Pack marked as not installed');
      }
      
      // Check if pack files exist
      final packDir = await getPackDirectory(packId);
      if (!await packDir.exists()) {
        return PackValidationResult(packId, false, 'Pack directory missing');
      }
      
      // Check manifest file
      final manifest = await loadPackManifest(packId);
      if (manifest == null) {
        return PackValidationResult(packId, false, 'Manifest file missing or corrupted');
      }
      
      // Verify pack files exist
      for (final file in manifest.files) {
        final filePath = path.join(packDir.path, file.name);
        final fileExists = await File(filePath).exists();
        if (!fileExists) {
          return PackValidationResult(packId, false, 'Required file missing: ${file.name}');
        }
        
        // Optional: Verify file size matches manifest
        final actualSize = await File(filePath).length();
        if (actualSize != file.size) {
          return PackValidationResult(packId, false, 'File size mismatch: ${file.name}');
        }
      }
      
      return PackValidationResult(packId, true, 'Pack is valid');
      
    } catch (e) {
      return PackValidationResult(packId, false, 'Validation error: $e');
    }
  }
  
  /// Check for and detect broken installations
  Future<List<String>> detectBrokenPacks() async {
    try {
      final installedPacks = await getInstalledPacks();
      final brokenPacks = <String>[];
      
      for (final pack in installedPacks) {
        try {
          final validation = await validatePack(pack.packId);
          if (!validation.isValid) {
            print('DriftLanguagePackService: Detected broken pack: ${pack.packId} - ${validation.error}');
            brokenPacks.add(pack.packId);
          }
        } catch (e) {
          print('DriftLanguagePackService: Error validating pack ${pack.packId}: $e');
          // If validation itself fails, consider the pack broken
          brokenPacks.add(pack.packId);
        }
      }
      
      return brokenPacks;
    } catch (e) {
      print('DriftLanguagePackService: Critical error in detectBrokenPacks: $e');
      // Return empty list rather than crashing the app
      return [];
    }
  }
  
  /// Get all installed language packs
  Future<List<LanguagePack>> getInstalledPacks() async {
    final query = _database.select(_database.languagePacks)
      ..where((pack) => pack.isInstalled.equals(true))
      ..orderBy([
        (pack) => OrderingTerm.desc(pack.lastUsedAt),
        (pack) => OrderingTerm.desc(pack.installedAt),
      ]);
    
    return await query.get();
  }
  
  /// Get available language packs for a specific language pair
  Future<List<LanguagePack>> getAvailablePacksForLanguages({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final query = _database.select(_database.languagePacks)
      ..where((pack) => 
        (pack.sourceLanguage.equals(sourceLanguage) & pack.targetLanguage.equals(targetLanguage)) |
        (pack.sourceLanguage.equals(targetLanguage) & pack.targetLanguage.equals(sourceLanguage))
      );
    
    return await query.get();
  }
  
  /// Register a new language pack for installation
  Future<void> registerLanguagePack({
    required String packId,
    required String name,
    required String description,
    required String sourceLanguage,
    required String targetLanguage,
    required String packType, // 'dictionary', 'combined'
    required String version,
    required int sizeBytes,
    required String downloadUrl,
    required String checksum,
  }) async {
    final pack = LanguagePacksCompanion(
      packId: Value(packId),
      name: Value(name),
      description: Value(description),
      sourceLanguage: Value(sourceLanguage),
      targetLanguage: Value(targetLanguage),
      packType: Value(packType),
      version: Value(version),
      sizeBytes: Value(sizeBytes),
      downloadUrl: Value(downloadUrl),
      checksum: Value(checksum),
      isInstalled: const Value(false),
      isActive: const Value(false),
    );
    
    // Use upsert pattern: try insert, if fails update existing
    try {
      await _database.into(_database.languagePacks).insert(pack);
      print('DriftLanguagePackService: Registered new pack: $packId');
    } catch (e) {
      // Pack already exists, update it
      final updated = await (_database.update(_database.languagePacks)
        ..where((p) => p.packId.equals(packId))
      ).write(pack);
      
      if (updated > 0) {
        print('DriftLanguagePackService: Updated existing pack: $packId');
      } else {
        print('DriftLanguagePackService: Warning - No pack found to update: $packId');
        throw LanguagePackException('Failed to register or update pack: $packId');
      }
    }
  }
  
  /// Mark a language pack as installed
  Future<void> markPackAsInstalled(String packId) async {
    final now = DateTime.now();
    
    await (_database.update(_database.languagePacks)
      ..where((pack) => pack.packId.equals(packId))
    ).write(LanguagePacksCompanion(
      isInstalled: const Value(true),
      isActive: const Value(true),
      installedAt: Value(now),
      lastUsedAt: Value(now),
    ));
  }
  
  /// Update pack usage time
  Future<void> updatePackUsage(String packId) async {
    await (_database.update(_database.languagePacks)
      ..where((pack) => pack.packId.equals(packId))
    ).write(LanguagePacksCompanion(
      lastUsedAt: Value(DateTime.now()),
    ));
  }
  
  /// Remove a language pack
  Future<void> removeLanguagePack(String packId) async {
    // Remove from database
    await (_database.delete(_database.languagePacks)
      ..where((pack) => pack.packId.equals(packId))
    ).go();
    
    // Remove files from storage
    await _deletePackFiles(packId);
  }
  
  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    final installedPacks = await getInstalledPacks();
    
    int totalSize = 0;
    final usageByLanguage = <String, int>{};
    final usageByType = <String, int>{};
    
    for (final pack in installedPacks) {
      totalSize += pack.sizeBytes;
      
      // Count by source language
      final lang = pack.sourceLanguage;
      usageByLanguage[lang] = (usageByLanguage[lang] ?? 0) + pack.sizeBytes;
      
      // Count by pack type
      usageByType[pack.packType] = (usageByType[pack.packType] ?? 0) + pack.sizeBytes;
    }
    
    return {
      'totalSize': totalSize,
      'packCount': installedPacks.length,
      'usageByLanguage': usageByLanguage,
      'usageByType': usageByType,
    };
  }
  
  /// Clean up unused packs (not used in 30 days)
  Future<int> cleanupUnusedPacks() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    
    final oldPacks = await (_database.select(_database.languagePacks)
      ..where((pack) => 
        pack.isInstalled.equals(true) & 
        pack.lastUsedAt.isSmallerThanValue(cutoffDate)
      )
    ).get();
    
    int freedBytes = 0;
    for (final pack in oldPacks) {
      await removeLanguagePack(pack.packId);
      freedBytes += pack.sizeBytes;
    }
    
    return freedBytes;
  }
  
  /// Get pack installation directory
  Future<Directory> getPackDirectory(String packId) async {
    final appDir = await getApplicationSupportDirectory();
    final packDir = Directory(path.join(appDir.path, 'language_packs', packId));
    
    if (!await packDir.exists()) {
      await packDir.create(recursive: true);
    }
    
    return packDir;
  }
  
  /// Save pack manifest to disk
  Future<void> savePackManifest(String packId, LanguagePackManifest manifest) async {
    final packDir = await getPackDirectory(packId);
    final manifestFile = File(path.join(packDir.path, 'manifest.json'));
    await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
  }
  
  /// Load pack manifest from disk
  Future<LanguagePackManifest?> loadPackManifest(String packId) async {
    try {
      final packDir = await getPackDirectory(packId);
      final manifestFile = File(path.join(packDir.path, 'manifest.json'));
      
      if (!await manifestFile.exists()) return null;
      
      final manifestJson = await manifestFile.readAsString();
      final manifestData = jsonDecode(manifestJson) as Map<String, dynamic>;
      return LanguagePackManifest.fromJson(manifestData);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> _deletePackFiles(String packId) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final packDir = Directory(path.join(appDir.path, 'language_packs', packId));
      
      if (await packDir.exists()) {
        await packDir.delete(recursive: true);
      }
    } catch (e) {
      print('Failed to delete pack files for $packId: $e');
    }
  }
}

/// Result of pack validation
class PackValidationResult {
  final String packId;
  final bool isValid;
  final String error;
  
  PackValidationResult(this.packId, this.isValid, this.error);
  
  @override
  String toString() => 'PackValidationResult($packId: ${isValid ? "Valid" : "Invalid - $error"})';
}

/// Exception for language pack operations
class LanguagePackException implements Exception {
  final String message;
  LanguagePackException(this.message);
  
  @override
  String toString() => 'LanguagePackException: $message';
}