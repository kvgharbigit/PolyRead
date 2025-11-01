// Storage Management Service - Manages language pack storage with quota limits
// Implements LRU eviction and storage tracking

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/language_pack_manifest.dart';
import '../models/download_progress.dart';

class StorageManagementService {
  static const String _tableName = 'language_pack_installations';
  static const int _defaultStorageLimitMB = 51200;
  
  final Database _database;
  final int storageLimitBytes;
  
  StorageManagementService({
    required Database database,
    int storageLimitMB = _defaultStorageLimitMB,
  }) : _database = database,
       storageLimitBytes = storageLimitMB * 1024 * 1024;
  
  /// Initialize storage management tables
  Future<void> initialize() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        pack_id TEXT PRIMARY KEY,
        version TEXT NOT NULL,
        installed_at INTEGER NOT NULL,
        last_used INTEGER NOT NULL,
        total_size INTEGER NOT NULL,
        installed_files TEXT NOT NULL, -- JSON array of file names
        status TEXT NOT NULL
      )
    ''');
    
    // Create indexes for performance
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_pack_last_used 
      ON $_tableName(last_used)
    ''');
    
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_pack_size 
      ON $_tableName(total_size)
    ''');
  }
  
  /// Check if there's enough space for a download
  Future<bool> checkSpaceAvailable(int requiredBytes) async {
    final currentUsage = await getTotalUsage();
    final availableSpace = storageLimitBytes - currentUsage;
    
    if (requiredBytes <= availableSpace) {
      return true;
    }
    
    // Try to free up space by removing least recently used packs
    final freedSpace = await _freeUpSpace(requiredBytes - availableSpace);
    return freedSpace >= (requiredBytes - availableSpace);
  }
  
  /// Get current storage quota information
  Future<StorageQuota> getStorageQuota() async {
    final installations = await getAllInstallations();
    final packUsage = <String, int>{};
    
    for (final installation in installations) {
      packUsage[installation.packId] = installation.totalSize;
    }
    
    return StorageQuota.create(
      totalLimitBytes: storageLimitBytes,
      packUsage: packUsage,
    );
  }
  
  /// Register a new language pack installation
  Future<void> registerPackInstallation({
    required String packId,
    required String version,
    required int totalSize,
    required List<String> files,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await _database.insert(
      _tableName,
      {
        'pack_id': packId,
        'version': version,
        'installed_at': now,
        'last_used': now,
        'total_size': totalSize,
        'installed_files': files.join(','),
        'status': PackInstallationStatus.installed.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  /// Update last used time for a language pack
  Future<void> updatePackUsage(String packId) async {
    await _database.update(
      _tableName,
      {'last_used': DateTime.now().millisecondsSinceEpoch},
      where: 'pack_id = ?',
      whereArgs: [packId],
    );
  }
  
  /// Check if a language pack is installed
  Future<bool> isPackInstalled(String packId) async {
    final results = await _database.query(
      _tableName,
      where: 'pack_id = ? AND status = ?',
      whereArgs: [packId, PackInstallationStatus.installed.name],
    );
    
    return results.isNotEmpty;
  }
  
  /// Get all installed language packs
  Future<List<LanguagePackInstallation>> getAllInstallations() async {
    final results = await _database.query(
      _tableName,
      orderBy: 'last_used DESC',
    );
    
    return results.map((row) => LanguagePackInstallation.fromMap(row)).toList();
  }
  
  /// Get installation info for a specific pack
  Future<LanguagePackInstallation?> getPackInstallation(String packId) async {
    final results = await _database.query(
      _tableName,
      where: 'pack_id = ?',
      whereArgs: [packId],
    );
    
    if (results.isEmpty) return null;
    return LanguagePackInstallation.fromMap(results.first);
  }
  
  /// Remove a language pack installation
  Future<void> removeLanguagePack(String packId) async {
    // Remove from database
    await _database.delete(
      _tableName,
      where: 'pack_id = ?',
      whereArgs: [packId],
    );
    
    // Remove files from storage
    await _deletePackFiles(packId);
  }
  
  /// Get total storage usage
  Future<int> getTotalUsage() async {
    final result = await _database.rawQuery('''
      SELECT SUM(total_size) as total_usage FROM $_tableName
      WHERE status = ?
    ''', [PackInstallationStatus.installed.name]);
    
    return result.first['total_usage'] as int? ?? 0;
  }
  
  /// Get storage usage by language
  Future<Map<String, int>> getUsageByLanguage() async {
    final installations = await getAllInstallations();
    final usageByLang = <String, int>{};
    
    for (final installation in installations) {
      // Extract language from pack ID (assuming format like "en-es-v1.0")
      final language = installation.packId.split('-').first;
      usageByLang[language] = (usageByLang[language] ?? 0) + installation.totalSize;
    }
    
    return usageByLang;
  }
  
  /// Force cleanup of unused storage
  Future<int> cleanupUnusedStorage() async {
    final cutoffTime = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    
    final oldPacks = await _database.query(
      _tableName,
      where: 'last_used < ?',
      whereArgs: [cutoffTime],
      orderBy: 'last_used ASC',
    );
    
    int freedBytes = 0;
    for (final pack in oldPacks) {
      final packId = pack['pack_id'] as String;
      final size = pack['total_size'] as int;
      
      await removeLanguagePack(packId);
      freedBytes += size;
    }
    
    return freedBytes;
  }
  
  /// Validate storage integrity
  Future<List<String>> validateStorageIntegrity() async {
    final issues = <String>[];
    final installations = await getAllInstallations();
    
    for (final installation in installations) {
      try {
        final packExists = await _packDirectoryExists(installation.packId);
        if (!packExists) {
          issues.add('Pack directory missing for ${installation.packId}');
          
          // Mark as corrupted
          await _database.update(
            _tableName,
            {'status': PackInstallationStatus.corrupted.name},
            where: 'pack_id = ?',
            whereArgs: [installation.packId],
          );
        }
      } catch (e) {
        issues.add('Error validating ${installation.packId}: $e');
      }
    }
    
    return issues;
  }
  
  /// Get corrupted language packs
  Future<List<LanguagePackInstallation>> getCorruptedPacks() async {
    final results = await _database.query(
      _tableName,
      where: 'status = ?',
      whereArgs: [PackInstallationStatus.corrupted.name],
    );
    
    return results.map((row) => LanguagePackInstallation.fromMap(row)).toList();
  }
  
  Future<int> _freeUpSpace(int requiredBytes) async {
    // Get least recently used packs
    final candidates = await _database.query(
      _tableName,
      where: 'status = ?',
      whereArgs: [PackInstallationStatus.installed.name],
      orderBy: 'last_used ASC',
    );
    
    int freedBytes = 0;
    
    for (final candidate in candidates) {
      if (freedBytes >= requiredBytes) break;
      
      final packId = candidate['pack_id'] as String;
      final size = candidate['total_size'] as int;
      
      await removeLanguagePack(packId);
      freedBytes += size;
    }
    
    return freedBytes;
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
  
  Future<bool> _packDirectoryExists(String packId) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final packDir = Directory(path.join(appDir.path, 'language_packs', packId));
      return await packDir.exists();
    } catch (e) {
      return false;
    }
  }
}