// Bidirectional Dictionary Service
// Handles lookups in single bidirectional language pack databases

import 'dart:io';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as path;
import 'package:drift/drift.dart';

import '../models/bidirectional_dictionary_entry.dart';
import '../../../core/database/app_database.dart';

class BidirectionalDictionaryService {
  final AppDatabase _database;
  final Map<String, sqflite.Database> _packDatabases = {};

  BidirectionalDictionaryService(this._database);

  /// Legacy method - no longer used but kept for compatibility
  Future<sqflite.Database?> _openPackDatabase(String packId) async {
    // This method is no longer used since we query the main app database directly
    throw UnimplementedError('Pack databases are no longer used - data is in main app database');
  }

  /// Check if a language pack is installed and has dictionary data
  Future<bool> _isPackInstalled(String packId) async {
    print('BidirectionalDictionaryService: Checking if pack $packId is installed...');
    
    // Check if pack is installed in app database
    final packRecord = await (_database.select(_database.languagePacks)
        ..where((tbl) => tbl.packId.equals(packId)))
        .getSingleOrNull();

    if (packRecord?.isInstalled != true) {
      print('BidirectionalDictionaryService: Pack $packId not found in database or not marked as installed');
      return false;
    }
    
    print('BidirectionalDictionaryService: Pack $packId found - sourceLanguage: ${packRecord!.sourceLanguage}, targetLanguage: ${packRecord.targetLanguage}');

    // Check if there are dictionary entries for this pack (bidirectional)
    // Check both forward (source->target) and reverse (target->source) directions
    final forwardEntryCount = await (_database.select(_database.dictionaryEntries)
        ..where((tbl) => tbl.sourceLanguage.equals(packRecord.sourceLanguage) &
                        tbl.targetLanguage.equals(packRecord.targetLanguage))
        ..limit(1))
        .get();

    final reverseEntryCount = await (_database.select(_database.dictionaryEntries)
        ..where((tbl) => tbl.sourceLanguage.equals(packRecord.targetLanguage) &
                        tbl.targetLanguage.equals(packRecord.sourceLanguage))
        ..limit(1))
        .get();

    print('BidirectionalDictionaryService: Forward entries (${packRecord.sourceLanguage}->${packRecord.targetLanguage}): ${forwardEntryCount.length}');
    print('BidirectionalDictionaryService: Reverse entries (${packRecord.targetLanguage}->${packRecord.sourceLanguage}): ${reverseEntryCount.length}');
    
    // Debug: Check what entries actually exist in the database for this pack
    final allEntries = await (_database.select(_database.dictionaryEntries)
        ..limit(10))
        .get();
    print('BidirectionalDictionaryService: Sample of first ${allEntries.length} entries in database:');
    for (final entry in allEntries) {
      print('  - "${entry.writtenRep}" (${entry.sourceLanguage}->${entry.targetLanguage}) source: "${entry.source}"');
    }
    
    // Debug: Check total count in database
    final totalEntries = await (_database.select(_database.dictionaryEntries)).get();
    print('BidirectionalDictionaryService: Total entries in database: ${totalEntries.length}');
    
    // Debug: Check entries by source name
    final packSourceEntries = await (_database.select(_database.dictionaryEntries)
        ..where((tbl) => tbl.source.like('%German%') | tbl.source.like('%English%') | tbl.source.like('%de%') | tbl.source.like('%en%')))
        .get();
    print('BidirectionalDictionaryService: Entries matching German/English keywords: ${packSourceEntries.length}');
    
    // Debug: Check distinct source values
    final distinctSources = await _database.customSelect(
      'SELECT DISTINCT source FROM dictionary_entries LIMIT 10'
    ).get();
    print('BidirectionalDictionaryService: Distinct source names in database:');
    for (final row in distinctSources) {
      print('  - "${row.data['source']}"');
    }

    final hasEntries = forwardEntryCount.isNotEmpty || reverseEntryCount.isNotEmpty;
    print('BidirectionalDictionaryService: Pack $packId ${hasEntries ? "HAS" : "DOES NOT HAVE"} dictionary entries');
    
    return hasEntries;
  }

  /// Perform bidirectional lookup using main app database
  Future<BidirectionalLookupResult> lookup({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    
    try {
      // Check if pack is installed
      if (!await _isPackInstalled(packId)) {
        print('BidirectionalDictionaryService: Pack $packId not installed or has no data');
        return BidirectionalLookupResult(
          query: query,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
      }
      
      // Perform forward lookup (source -> target)
      final forwardEntry = await _lookupInAppDatabase(
        query: query,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      // Perform reverse lookup (target -> source)
      final reverseEntry = await _lookupInAppDatabase(
        query: query,
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

  /// Lookup in app database for a specific language direction
  Future<BidirectionalDictionaryEntry?> _lookupInAppDatabase({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      // Query the main app database dictionary_entries table
      final entry = await (_database.select(_database.dictionaryEntries)
          ..where((tbl) => tbl.writtenRep.equals(query) &
                          tbl.sourceLanguage.equals(sourceLanguage) &
                          tbl.targetLanguage.equals(targetLanguage))
          ..limit(1))
          .getSingleOrNull();

      if (entry != null) {
        return BidirectionalDictionaryEntry.fromAppDatabase(
          lemma: entry.writtenRep,
          definition: entry.transList ?? '',
          sourceLanguage: entry.sourceLanguage,
          targetLanguage: entry.targetLanguage,
          pos: entry.pos,
          sense: entry.sense,
        );
      }

      return null;
    } catch (e) {
      print('BidirectionalDictionaryService: App database lookup error: $e');
      return null;
    }
  }

  /// Search for partial matches in both directions using app database
  Future<List<BidirectionalDictionaryEntry>> search({
    required String query,
    required String sourceLanguage,
    required String targetLanguage,
    int limit = 20,
  }) async {
    final packId = '$sourceLanguage-$targetLanguage';
    
    try {
      // Check if pack is installed
      if (!await _isPackInstalled(packId)) {
        return [];
      }
      
      // Search in forward direction (source->target) using LIKE operator
      final forwardEntries = await (_database.select(_database.dictionaryEntries)
          ..where((tbl) => tbl.writtenRep.like('%$query%') &
                          tbl.sourceLanguage.equals(sourceLanguage) &
                          tbl.targetLanguage.equals(targetLanguage))
          ..orderBy([(entry) => OrderingTerm(expression: entry.writtenRep)])
          ..limit(limit ~/ 2))
          .get();
      
      // Search in reverse direction (target->source) using LIKE operator
      final reverseEntries = await (_database.select(_database.dictionaryEntries)
          ..where((tbl) => tbl.writtenRep.like('%$query%') &
                          tbl.sourceLanguage.equals(targetLanguage) &
                          tbl.targetLanguage.equals(sourceLanguage))
          ..orderBy([(entry) => OrderingTerm(expression: entry.writtenRep)])
          ..limit(limit ~/ 2))
          .get();

      final entries = [...forwardEntries, ...reverseEntries];

      return entries.map((entry) => BidirectionalDictionaryEntry.fromAppDatabase(
        lemma: entry.writtenRep,
        definition: entry.transList ?? '',
        sourceLanguage: entry.sourceLanguage,
        targetLanguage: entry.targetLanguage,
        pos: entry.pos,
        sense: entry.sense,
      )).toList();
    } catch (e) {
      print('BidirectionalDictionaryService: Search error for $query: $e');
      return [];
    }
  }

  /// Get pack statistics from app database
  Future<Map<String, int>> getPackStatistics(String packId) async {
    try {
      print('BidirectionalDictionaryService: Getting statistics for pack $packId');
      
      // Parse pack ID to get languages
      final parts = packId.split('-');
      if (parts.length != 2) {
        throw Exception('Invalid pack ID format: $packId');
      }
      final sourceLanguage = parts[0];
      final targetLanguage = parts[1];
      
      print('BidirectionalDictionaryService: Parsed languages - source: $sourceLanguage, target: $targetLanguage');
      
      // Check if pack is installed
      if (!await _isPackInstalled(packId)) {
        print('BidirectionalDictionaryService: Pack $packId not installed, returning zero stats');
        return {'forward': 0, 'reverse': 0, 'total': 0};
      }
      
      // Count forward entries (source -> target)
      final forwardEntries = await (_database.select(_database.dictionaryEntries)
          ..where((tbl) => tbl.sourceLanguage.equals(sourceLanguage) &
                          tbl.targetLanguage.equals(targetLanguage)))
          .get();
      
      // Count reverse entries (target -> source)
      final reverseEntries = await (_database.select(_database.dictionaryEntries)
          ..where((tbl) => tbl.sourceLanguage.equals(targetLanguage) &
                          tbl.targetLanguage.equals(sourceLanguage)))
          .get();

      final forward = forwardEntries.length;
      final reverse = reverseEntries.length;
      final total = forward + reverse;

      print('BidirectionalDictionaryService: Pack $packId statistics - Forward: $forward, Reverse: $reverse, Total: $total');

      return {
        'forward': forward,
        'reverse': reverse,
        'total': total,
      };
    } catch (e) {
      print('BidirectionalDictionaryService: Statistics error for $packId: $e');
      return {'forward': 0, 'reverse': 0, 'total': 0};
    }
  }

  /// Validate pack structure by checking if data exists in app database
  Future<bool> validatePackStructure(String packId) async {
    try {
      // Simply check if pack is installed and has data
      return await _isPackInstalled(packId);
    } catch (e) {
      print('BidirectionalDictionaryService: Validation error for $packId: $e');
      return false;
    }
  }

  /// Dispose resources (no longer needed since we use main app database)
  void dispose() {
    // No resources to dispose since we use the main app database
    _packDatabases.clear();
  }
}