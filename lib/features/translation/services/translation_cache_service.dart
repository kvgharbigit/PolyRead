// Translation Cache Service - Caches translation results for performance
// Uses SQLite for persistent caching with size limits

import 'package:sqflite/sqflite.dart';
import '../models/translation_request.dart';
import '../models/translation_response.dart' as response_model;

class TranslationCacheService {
  static const String _tableName = 'translation_cache';
  static const int _maxCacheEntries = 10000;
  static const int _maxCacheAgeDays = 30;
  
  final Database _database;
  
  TranslationCacheService(this._database);
  
  /// Initialize cache table
  Future<void> initialize() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cache_key TEXT NOT NULL UNIQUE,
        source_text TEXT NOT NULL,
        source_language TEXT NOT NULL,
        target_language TEXT NOT NULL,
        translated_text TEXT,
        dictionary_entries TEXT, -- JSON encoded
        provider_id TEXT NOT NULL,
        source_type TEXT NOT NULL, -- dictionary, ml_kit, server
        latency_ms INTEGER NOT NULL,
        success INTEGER NOT NULL,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        last_accessed INTEGER NOT NULL,
        access_count INTEGER DEFAULT 1
      )
    ''');
    
    // Create index for faster lookups
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_cache_key 
      ON $_tableName(cache_key)
    ''');
    
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_cache_created 
      ON $_tableName(created_at)
    ''');
    
    await _database.execute('''
      CREATE INDEX IF NOT EXISTS idx_cache_accessed 
      ON $_tableName(last_accessed)
    ''');
  }
  
  /// Get cached translation if available
  Future<response_model.TranslationResponse?> getCachedTranslation(
    TranslationRequest request,
  ) async {
    try {
      final results = await _database.query(
        _tableName,
        where: 'cache_key = ?',
        whereArgs: [request.cacheKey],
        limit: 1,
      );
      
      if (results.isEmpty) return null;
      
      final row = results.first;
      
      // Update access tracking
      await _database.update(
        _tableName,
        {
          'last_accessed': DateTime.now().millisecondsSinceEpoch,
          'access_count': (row['access_count'] as int) + 1,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      
      // Convert back to response_model.TranslationResponse
      return _responseFromCacheRow(request, row);
    } catch (e) {
      // If cache lookup fails, just return null
      return null;
    }
  }
  
  /// Cache a translation result
  Future<void> cacheTranslation(
    TranslationRequest request,
    response_model.TranslationResponse response,
  ) async {
    if (response.error != null || response.source == response_model.TranslationSource.cache) {
      return; // Don't cache failures or already cached results
    }
    
    try {
      await _database.insert(
        _tableName,
        {
          'cache_key': request.cacheKey,
          'source_text': request.text,
          'source_language': request.sourceLanguage,
          'target_language': request.targetLanguage,
          'translated_text': response.translatedText,
          'dictionary_entries': '', // Legacy field - no longer used in cycling system
          'provider_id': response.providerId ?? 'unknown',
          'source_type': response.source.name,
          'latency_ms': response.responseTime?.inMilliseconds ?? 0,
          'success': response.error == null ? 1 : 0,
          'error_message': response.error,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'last_accessed': DateTime.now().millisecondsSinceEpoch,
          'access_count': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Clean up cache if it gets too large
      await _cleanupCache();
    } catch (e) {
      // Cache failures shouldn't break translation
      print('Failed to cache translation: $e');
    }
  }
  
  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      final countResult = await _database.rawQuery('''
        SELECT COUNT(*) as total_entries FROM $_tableName
      ''');
      
      final sizeResult = await _database.rawQuery('''
        SELECT 
          SUM(LENGTH(source_text) + LENGTH(translated_text) + LENGTH(dictionary_entries)) as total_size
        FROM $_tableName
      ''');
      
      final ageResult = await _database.rawQuery('''
        SELECT 
          MIN(created_at) as oldest,
          MAX(created_at) as newest
        FROM $_tableName
      ''');
      
      final totalEntries = countResult.first['total_entries'] as int;
      final totalSize = sizeResult.first['total_size'] as int? ?? 0;
      final oldest = ageResult.first['oldest'] as int?;
      final newest = ageResult.first['newest'] as int?;
      
      return {
        'totalEntries': totalEntries,
        'totalSize': totalSize,
        'oldestEntry': oldest != null ? DateTime.fromMillisecondsSinceEpoch(oldest) : null,
        'newestEntry': newest != null ? DateTime.fromMillisecondsSinceEpoch(newest) : null,
      };
    } catch (e) {
      return {
        'totalEntries': 0,
        'totalSize': 0,
        'oldestEntry': null,
        'newestEntry': null,
      };
    }
  }
  
  /// Clear entire cache
  Future<void> clearCache() async {
    try {
      await _database.delete(_tableName);
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }
  
  /// Clear old cache entries
  Future<void> clearOldEntries({int maxAgeDays = _maxCacheAgeDays}) async {
    try {
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: maxAgeDays))
          .millisecondsSinceEpoch;
      
      await _database.delete(
        _tableName,
        where: 'created_at < ?',
        whereArgs: [cutoffTime],
      );
    } catch (e) {
      print('Failed to clear old cache entries: $e');
    }
  }
  
  /// Clean up resources
  Future<void> dispose() async {
    // Nothing to dispose for cache service
  }
  
  Future<void> _cleanupCache() async {
    try {
      // Check current cache size
      final count = await _database.rawQuery('''
        SELECT COUNT(*) as count FROM $_tableName
      ''');
      
      final currentCount = count.first['count'] as int;
      
      if (currentCount <= _maxCacheEntries) return;
      
      // Remove least recently accessed entries
      final entriesToRemove = currentCount - _maxCacheEntries;
      
      await _database.rawDelete('''
        DELETE FROM $_tableName 
        WHERE id IN (
          SELECT id FROM $_tableName 
          ORDER BY last_accessed ASC 
          LIMIT ?
        )
      ''', [entriesToRemove]);
      
    } catch (e) {
      print('Failed to cleanup cache: $e');
    }
  }
  
  response_model.TranslationResponse _responseFromCacheRow(
    TranslationRequest request,
    Map<String, dynamic> row,
  ) {
    final sourceType = response_model.TranslationSource.values.firstWhere(
      (source) => source.name == row['source_type'],
      orElse: () => response_model.TranslationSource.cache,
    );
    
    return response_model.TranslationResponse(
      request: request,
      translatedText: row['translated_text'] as String? ?? '',
      source: sourceType,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      providerId: row['provider_id'] as String?,
      error: row['error_message'] as String?,
    );
  }
  
  // Dictionary entries encoding removed - cache now stores simple translation results
}