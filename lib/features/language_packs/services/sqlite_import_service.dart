// SQLite Import Service - Handles importing dictionary data from downloaded SQLite files
// Provides data migration from Wiktionary SQLite files to app database

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:polyread/core/database/app_database.dart';

class SqliteImportService {
  final AppDatabase _appDatabase;
  
  SqliteImportService(this._appDatabase);
  
  /// Import dictionary data from a Wiktionary SQLite file
  Future<SqliteImportResult> importWiktionarySqlite({
    required String sqliteFilePath,
    required String sourceLanguage,
    required String targetLanguage,
    required String dictionaryName,
    Function(String message, int progress)? onProgress,
  }) async {
    if (!await File(sqliteFilePath).exists()) {
      throw SqliteImportException('SQLite file not found: $sqliteFilePath');
    }
    
    Database? sourceDb;
    int importedCount = 0;
    
    try {
      onProgress?.call('Opening dictionary database...', 0);
      
      // Open the source SQLite database
      sourceDb = await openDatabase(
        sqliteFilePath,
        readOnly: true,
        version: 1,
      );
      
      // Analyze source database structure
      onProgress?.call('Analyzing database structure...', 10);
      final sourceInfo = await _analyzeSourceDatabase(sourceDb);
      
      if (!sourceInfo.isValidWiktionary) {
        throw SqliteImportException('Invalid Wiktionary database format');
      }
      
      onProgress?.call('Found ${sourceInfo.totalEntries} entries to import...', 20);
      
      // Import entries in batches
      importedCount = await _importEntriesBatch(
        sourceDb: sourceDb,
        sourceInfo: sourceInfo,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        dictionaryName: dictionaryName,
        onProgress: (processed, total) {
          final progress = 20 + ((processed * 70) ~/ total);
          onProgress?.call('Importing entries: $processed/$total', progress);
        },
      );
      
      onProgress?.call('Import completed successfully', 100);
      
      return SqliteImportResult(
        success: true,
        importedEntries: importedCount,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        dictionaryName: dictionaryName,
        message: 'Successfully imported $importedCount dictionary entries',
      );
      
    } catch (e) {
      return SqliteImportResult(
        success: false,
        importedEntries: importedCount,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        dictionaryName: dictionaryName,
        message: 'Import failed: $e',
        error: e.toString(),
      );
    } finally {
      await sourceDb?.close();
    }
  }
  
  /// Validate a Wiktionary SQLite file before import
  Future<WiktionaryValidationResult> validateWiktionaryDatabase(String sqliteFilePath) async {
    if (!await File(sqliteFilePath).exists()) {
      return WiktionaryValidationResult(
        isValid: false,
        message: 'SQLite file not found',
      );
    }
    
    Database? db;
    try {
      db = await openDatabase(sqliteFilePath, readOnly: true);
      final sourceInfo = await _analyzeSourceDatabase(db);
      
      return WiktionaryValidationResult(
        isValid: sourceInfo.isValidWiktionary,
        message: sourceInfo.isValidWiktionary 
          ? 'Valid Wiktionary database with ${sourceInfo.totalEntries} entries'
          : 'Invalid database format: ${sourceInfo.issues.join(", ")}',
        totalEntries: sourceInfo.totalEntries,
        tables: sourceInfo.tables,
        issues: sourceInfo.issues,
      );
    } catch (e) {
      return WiktionaryValidationResult(
        isValid: false,
        message: 'Database validation failed: $e',
      );
    } finally {
      await db?.close();
    }
  }
  
  /// Clear all entries for a specific dictionary
  Future<void> clearDictionary(String dictionaryName) async {
    await (_appDatabase.delete(_appDatabase.dictionaryEntries)
      ..where((e) => e.source.equals(dictionaryName))).go();
  }
  
  /// Get import statistics for a dictionary
  Future<ImportStats> getDictionaryStats(String dictionaryName) async {
    final countResult = await _appDatabase.customSelect('''
      SELECT 
        source_language,
        target_language,
        COUNT(*) as entry_count,
        MIN(created_at) as first_import,
        MAX(created_at) as last_import
      FROM dictionary_entries 
      WHERE source = ?
      GROUP BY source_language, target_language
    ''', variables: [Variable(dictionaryName)]).get();
    
    final stats = <LanguagePairStats>[];
    for (final row in countResult) {
      stats.add(LanguagePairStats(
        sourceLanguage: row.data['source_language'] as String,
        targetLanguage: row.data['target_language'] as String,
        entryCount: row.data['entry_count'] as int,
        firstImport: DateTime.tryParse(row.data['first_import'] as String? ?? '') ?? DateTime.now(),
        lastImport: DateTime.tryParse(row.data['last_import'] as String? ?? '') ?? DateTime.now(),
      ));
    }
    
    final totalEntries = stats.fold(0, (sum, stat) => sum + stat.entryCount);
    
    return ImportStats(
      dictionaryName: dictionaryName,
      totalEntries: totalEntries,
      languagePairs: stats,
    );
  }
  
  // Private helper methods
  
  Future<SourceDatabaseInfo> _analyzeSourceDatabase(Database db) async {
    final issues = <String>[];
    
    try {
      // Get table list
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toList();
      
      // Check for required Wiktionary tables
      const requiredTables = ['entries'];
      final missingTables = requiredTables.where((table) => !tableNames.contains(table)).toList();
      
      if (missingTables.isNotEmpty) {
        issues.add('Missing required tables: ${missingTables.join(", ")}');
      }
      
      // Get entry count
      int totalEntries = 0;
      try {
        final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM entries');
        totalEntries = countResult.first['count'] as int;
      } catch (e) {
        issues.add('Could not count entries: $e');
      }
      
      // Check table structure
      if (tableNames.contains('entries')) {
        final columns = await db.rawQuery('PRAGMA table_info(entries)');
        final columnNames = columns.map((c) => c['name'] as String).toList();
        
        // Check for required Wiktionary columns
        const requiredColumns = ['word', 'part_of_speech', 'language', 'definitions'];
        final missingColumns = requiredColumns.where((col) => !columnNames.contains(col)).toList();
        
        if (missingColumns.isNotEmpty) {
          issues.add('Missing required columns in entries table: ${missingColumns.join(", ")}');
        }
      }
      
      return SourceDatabaseInfo(
        tables: tableNames,
        totalEntries: totalEntries,
        issues: issues,
        isValidWiktionary: issues.isEmpty && totalEntries > 0,
      );
      
    } catch (e) {
      issues.add('Database analysis failed: $e');
      return SourceDatabaseInfo(
        tables: [],
        totalEntries: 0,
        issues: issues,
        isValidWiktionary: false,
      );
    }
  }
  
  Future<int> _importEntriesBatch({
    required Database sourceDb,
    required SourceDatabaseInfo sourceInfo,
    required String sourceLanguage,
    required String targetLanguage,
    required String dictionaryName,
    Function(int processed, int total)? onProgress,
  }) async {
    const batchSize = 1000;
    int offset = 0;
    int totalImported = 0;
    
    await _appDatabase.transaction(() async {
      while (true) {
        // Fetch batch from source database
        final batchResults = await sourceDb.rawQuery('''
          SELECT 
            word,
            part_of_speech,
            language,
            definitions,
            etymology,
            pronunciations
          FROM entries 
          WHERE language IN (?, ?, ?)
          LIMIT ? OFFSET ?
        ''', [sourceLanguage, targetLanguage, '$sourceLanguage-$targetLanguage', batchSize, offset]);
        
        if (batchResults.isEmpty) break;
        
        // Convert and insert batch
        for (final row in batchResults) {
          await _insertDictionaryEntry(
            sourceDb: sourceDb,
            row: row,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            dictionaryName: dictionaryName,
          );
          totalImported++;
        }
        
        offset += batchSize;
        onProgress?.call(totalImported, sourceInfo.totalEntries);
        
        if (batchResults.length < batchSize) break;
      }
    });
    
    return totalImported;
  }
  
  Future<void> _insertDictionaryEntry({
    required Database sourceDb,
    required Map<String, Object?> row,
    required String sourceLanguage,
    required String targetLanguage,
    required String dictionaryName,
  }) async {
    try {
      final word = row['word'] as String? ?? '';
      final partOfSpeech = row['part_of_speech'] as String?;
      final definitions = row['definitions'] as String? ?? '';
      final etymology = row['etymology'] as String?;
      final pronunciations = row['pronunciations'] as String?;
      
      if (word.isEmpty || definitions.isEmpty) return;
      
      // Parse definitions (Wiktionary format may have multiple definitions separated by |)
      final definitionList = definitions.split('|').where((d) => d.trim().isNotEmpty).toList();
      final primaryDefinition = definitionList.isNotEmpty ? definitionList.first.trim() : definitions;
      
      // Create dictionary entry
      final companion = DictionaryEntriesCompanion.insert(
        writtenRep: word.toLowerCase(),
        sense: Value(primaryDefinition),
        transList: definitions, // Store all definitions
        pos: Value(partOfSpeech),
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        frequency: const Value(1000), // Default frequency
        pronunciation: Value(pronunciations),
        examples: Value(etymology), // Store etymology in examples field for now
        source: Value(dictionaryName),
      );
      
      await _appDatabase.into(_appDatabase.dictionaryEntries).insert(
        companion,
        mode: InsertMode.insertOrIgnore, // Avoid duplicates
      );
      
    } catch (e) {
      // Log error but continue with other entries
      print('SqliteImport: Failed to import entry ${row['word']}: $e');
    }
  }
}

// Data classes

class SqliteImportResult {
  final bool success;
  final int importedEntries;
  final String sourceLanguage;
  final String targetLanguage;
  final String dictionaryName;
  final String message;
  final String? error;
  
  const SqliteImportResult({
    required this.success,
    required this.importedEntries,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.dictionaryName,
    required this.message,
    this.error,
  });
}

class WiktionaryValidationResult {
  final bool isValid;
  final String message;
  final int totalEntries;
  final List<String> tables;
  final List<String> issues;
  
  const WiktionaryValidationResult({
    required this.isValid,
    required this.message,
    this.totalEntries = 0,
    this.tables = const [],
    this.issues = const [],
  });
}

class SourceDatabaseInfo {
  final List<String> tables;
  final int totalEntries;
  final List<String> issues;
  final bool isValidWiktionary;
  
  const SourceDatabaseInfo({
    required this.tables,
    required this.totalEntries,
    required this.issues,
    required this.isValidWiktionary,
  });
}

class ImportStats {
  final String dictionaryName;
  final int totalEntries;
  final List<LanguagePairStats> languagePairs;
  
  const ImportStats({
    required this.dictionaryName,
    required this.totalEntries,
    required this.languagePairs,
  });
}

class LanguagePairStats {
  final String sourceLanguage;
  final String targetLanguage;
  final int entryCount;
  final DateTime firstImport;
  final DateTime lastImport;
  
  const LanguagePairStats({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.entryCount,
    required this.firstImport,
    required this.lastImport,
  });
}

class SqliteImportException implements Exception {
  final String message;
  const SqliteImportException(this.message);
  
  @override
  String toString() => 'SqliteImportException: $message';
}