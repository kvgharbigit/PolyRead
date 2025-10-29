// Bidirectional Dictionary Service
// Handles lookups in single bidirectional language pack databases

import 'dart:io';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as path;

import '../models/bidirectional_dictionary_entry.dart';
import '../../../core/database/app_database.dart';

class BidirectionalDictionaryService {
  final AppDatabase _database;
  final Map<String, sqflite.Database> _packDatabases = {};

  BidirectionalDictionaryService(this._database);

  /// Open a bidirectional language pack database
  Future<sqflite.Database> _openPackDatabase(String packId) async {
    if (_packDatabases.containsKey(packId)) {
      return _packDatabases[packId]!;
    }

    // Get the pack file path
    final packPath = await _getPackDatabasePath(packId);
    if (packPath == null) {
      throw Exception('Language pack database not found: $packId');
    }

    // Open the database
    final database = await sqflite.openDatabase(packPath, readOnly: true);
    
    _packDatabases[packId] = database;
    return database;
  }

  /// Get the file path for a language pack database
  Future<String?> _getPackDatabasePath(String packId) async {
    // Check if pack is installed in app database
    final packRecord = await (_database.select(_database.languagePacks)
        ..where((tbl) => tbl.packId.equals(packId)))
        .getSingleOrNull();

    if (packRecord?.isInstalled != true) {
      return null;
    }

    // Construct the path to the extracted SQLite file
    final appDocDir = Directory.systemTemp; // Replace with actual app documents directory
    final packDir = Directory(path.join(appDocDir.path, 'language_packs', packId));
    final dbFile = File(path.join(packDir.path, '$packId.sqlite'));

    if (await dbFile.exists()) {
      return dbFile.path;
    }

    return null;
  }

  /// Perform bidirectional lookup
  Future<BidirectionalLookupResult> lookup({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    
    try {
      final database = await _openPackDatabase(packId);
      
      // Perform both forward and reverse lookups
      final forwardEntry = await _lookupDirection(
        database: database,
        query: query,
        direction: 'forward',
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      final reverseEntry = await _lookupDirection(
        database: database,
        query: query,
        direction: 'reverse',
        sourceLanguage: targetLanguage,
        targetLanguage: sourceLanguage,
      );

      return BidirectionalLookupResult(
        query: query,
        forwardEntry: forwardEntry,
        reverseEntry: reverseEntry,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    } catch (e) {
      print('BidirectionalDictionaryService: Lookup error for $query: $e');
      return BidirectionalLookupResult(
        query: query,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    }
  }

  /// Lookup in a specific direction
  Future<BidirectionalDictionaryEntry?> _lookupDirection({
    required sqflite.Database database,
    required String query,
    required String direction,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      // Query the bidirectional database
      final results = await database.query(
        'dictionary_entries',
        where: 'LOWER(lemma) = LOWER(?) AND direction = ?',
        whereArgs: [query, direction],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final row = results.first;
        return BidirectionalDictionaryEntry.fromDatabase(
          lemma: row['lemma'] as String,
          definition: row['definition'] as String,
          direction: row['direction'] as String,
          sourceLanguage: row['source_language'] as String,
          targetLanguage: row['target_language'] as String,
        );
      }

      return null;
    } catch (e) {
      print('BidirectionalDictionaryService: Direction lookup error: $e');
      return null;
    }
  }

  /// Search for partial matches in both directions
  Future<List<BidirectionalDictionaryEntry>> search({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
    int limit = 20,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    
    try {
      final database = await _openPackDatabase(packId);
      
      // Search in both directions  
      final results = await database.rawQuery(
        '''
        SELECT lemma, definition, direction, source_language, target_language
        FROM dictionary_entries 
        WHERE LOWER(lemma) LIKE LOWER(?) 
        ORDER BY 
          CASE WHEN LOWER(lemma) = LOWER(?) THEN 0 ELSE 1 END,
          LENGTH(lemma),
          lemma
        LIMIT ?
        ''',
        ['%$query%', query, limit],
      );

      return results.map((row) => BidirectionalDictionaryEntry.fromDatabase(
        lemma: row['lemma'] as String,
        definition: row['definition'] as String,
        direction: row['direction'] as String,
        sourceLanguage: row['source_language'] as String,
        targetLanguage: row['target_language'] as String,
      )).toList();
    } catch (e) {
      print('BidirectionalDictionaryService: Search error for $query: $e');
      return [];
    }
  }

  /// Get pack statistics
  Future<Map<String, int>> getPackStatistics(String packId) async {
    try {
      final database = await _openPackDatabase(packId);
      
      final results = await database.rawQuery(
        '''
        SELECT 
          direction,
          COUNT(*) as count
        FROM dictionary_entries 
        GROUP BY direction
        ''',
      );

      Map<String, int> stats = {
        'forward': 0,
        'reverse': 0,
        'total': 0,
      };

      for (final row in results) {
        final direction = row['direction'] as String;
        final count = row['count'] as int;
        stats[direction] = count;
        stats['total'] = stats['total']! + count;
      }

      return stats;
    } catch (e) {
      print('BidirectionalDictionaryService: Statistics error for $packId: $e');
      return {'forward': 0, 'reverse': 0, 'total': 0};
    }
  }

  /// Validate pack database structure
  Future<bool> validatePackStructure(String packId) async {
    try {
      final database = await _openPackDatabase(packId);
      
      // Check if required tables exist
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      
      final tableNames = tables.map((row) => row['name'] as String).toSet();
      
      final requiredTables = {'dictionary_entries', 'pack_metadata'};
      if (!requiredTables.every((table) => tableNames.contains(table))) {
        return false;
      }

      // Check schema version
      final metadata = await database.rawQuery(
        "SELECT value FROM pack_metadata WHERE key = 'schema_version'"
      );

      final schemaVersion = metadata.isNotEmpty ? metadata.first['value'] as String? : null;
      return schemaVersion == '2.0';
    } catch (e) {
      print('BidirectionalDictionaryService: Validation error for $packId: $e');
      return false;
    }
  }

  /// Close all open pack databases
  void dispose() {
    for (final database in _packDatabases.values) {
      database.close();
    }
    _packDatabases.clear();
  }
}