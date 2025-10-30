// SQLite Import Service - Handles importing dictionary data from modern Wiktionary format SQLite files
// Unified single-format approach using modern Wiktionary schema (written_rep, sense, trans_list)

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:polyread/core/database/app_database.dart';

enum InsertResult { inserted, skipped, error }

class SqliteImportService {
  final AppDatabase _appDatabase;
  
  SqliteImportService(this._appDatabase);
  
  /// Import dictionary data from a modern Wiktionary format SQLite file
  Future<SqliteImportResult> importWiktionarySqlite({
    required String sqliteFilePath,
    required String sourceLanguage,
    required String targetLanguage,
    required String dictionaryName,
    Function(String message, int progress)? onProgress,
  }) async {
    print('');
    print('📚 Starting SQLite import: $dictionaryName');
    
    // File existence check with detailed logging
    final sqliteFile = File(sqliteFilePath);
    final fileExists = await sqliteFile.exists();
    if (!fileExists) {
      throw SqliteImportException('SQLite file not found: $sqliteFilePath');
    }
    
    final fileSize = await sqliteFile.length();
    print('📚 SQLite file: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB');
    
    Database? sourceDb;
    int importedCount = 0;
    
    try {
      onProgress?.call('Opening dictionary database...', 0);
      
      sourceDb = await openDatabase(
        sqliteFilePath,
        readOnly: true,
        // Remove version parameter to avoid PRAGMA user_version write operation
      );
      print('📚 Database opened successfully');
      
      onProgress?.call('Analyzing database structure...', 10);
      final sourceInfo = await _analyzeSourceDatabase(sourceDb);
      print('📚 Found ${(sourceInfo.totalEntries/1000).toStringAsFixed(0)}K entries');
      
      if (!sourceInfo.isValidWiktionary) {
        throw SqliteImportException('Invalid modern Wiktionary database format: ${sourceInfo.issues.join(", ")}');
      }
      
      onProgress?.call('Found ${sourceInfo.totalEntries} entries to import...', 20);
      
      if (sourceInfo.totalEntries == 0) {
        return SqliteImportResult(
          success: false,
          importedEntries: 0,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          dictionaryName: dictionaryName,
          message: 'No entries found in source database',
          error: 'Empty database',
        );
      }
      
      // Import entries in batches
      importedCount = await _importEntriesBatch(
        sourceDb: sourceDb,
        sourceInfo: sourceInfo,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        dictionaryName: dictionaryName,
        onProgress: (processed, total) {
          final progress = 20 + ((processed * 70) ~/ total);
          // Log progress every 100,000 entries to keep user informed without spam
          if (processed % 100000 == 0 || processed == total) {
            print('📚 Import progress: ${(processed/1000).toStringAsFixed(0)}K/${(total/1000).toStringAsFixed(0)}K entries ($progress%)');
          }
          onProgress?.call('Importing entries: $processed/$total', progress);
        },
      );
      
      print('📚 Import completed: ${(importedCount/1000).toStringAsFixed(0)}K entries');
      
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
      print('❌ Import failed: $e');
      
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
  
  /// Validate a modern Wiktionary format SQLite file before import
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
          ? 'Valid modern Wiktionary database with ${sourceInfo.totalEntries} entries'
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
      
      // Check for required dictionary tables
      const requiredTables = ['dictionary_entries'];
      final missingTables = requiredTables.where((table) => !tableNames.contains(table)).toList();
      
      if (missingTables.isNotEmpty) {
        issues.add('Missing required tables: ${missingTables.join(", ")}');
      }
      
      // Get entry count
      int totalEntries = 0;
      try {
        final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM dictionary_entries');
        totalEntries = countResult.first['count'] as int;
      } catch (e) {
        issues.add('Could not count entries: $e');
      }
      
      // Check table structure - only support modern Wiktionary format
      bool hasValidFormat = false;
      if (tableNames.contains('dictionary_entries')) {
        final columns = await db.rawQuery('PRAGMA table_info(dictionary_entries)');
        final columnNames = columns.map((c) => c['name'] as String).toList();
        
        // Check for required modern Wiktionary columns
        const requiredColumns = ['written_rep', 'trans_list', 'source_language', 'target_language'];
        const optionalColumns = ['sense', 'pos'];
        
        final missingRequired = requiredColumns.where((col) => !columnNames.contains(col)).toList();
        hasValidFormat = missingRequired.isEmpty;
        
        print('📊 Database schema analysis:');
        print('  Available columns: $columnNames');
        print('  Has modern Wiktionary format: $hasValidFormat');
        
        if (missingRequired.isNotEmpty) {
          issues.add('Missing required modern Wiktionary columns: ${missingRequired.join(", ")}');
        }
      }
      
      final isValid = issues.isEmpty && totalEntries > 0 && hasValidFormat;
      
      return SourceDatabaseInfo(
        tables: tableNames,
        totalEntries: totalEntries,
        issues: issues,
        isValidWiktionary: isValid,
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
    print('📚 Starting dictionary import: ${sourceInfo.totalEntries} entries');
    
    const batchSize = 500; // Reduced batch size to use less memory
    int offset = 0;
    int totalImported = 0;
    
    // Memory-efficient initial count check using count query
    final countQuery = _appDatabase.selectOnly(_appDatabase.dictionaryEntries)
      ..addColumns([_appDatabase.dictionaryEntries.id.count()])
      ..where(_appDatabase.dictionaryEntries.source.equals(dictionaryName));
    final initialCount = await countQuery.map((row) => row.read(_appDatabase.dictionaryEntries.id.count()) ?? 0).getSingle();
    print('📚 Initial entries: $initialCount');
    
    await _appDatabase.transaction(() async {
      while (true) {
        // Only log every 200th batch (100K entries) to reduce memory usage
        if ((offset ~/ batchSize) % 200 == 0) {
          print('📚 Processing batch ${(offset ~/ batchSize) + 1}...');
        }
        
        // Fetch batch from source database using modern Wiktionary format
        if (offset == 0) {
          print('📊 Using modern Wiktionary format query');
        }
        
        final batchResults = await sourceDb.rawQuery('''
          SELECT 
            written_rep,
            sense,
            trans_list,
            pos,
            source_language,
            target_language
          FROM dictionary_entries 
          LIMIT ? OFFSET ?
        ''', [batchSize, offset]);
        
        if (batchResults.isEmpty) {
          break;
        }
        
        // Log sample only for first batch (reduced logging)
        if (offset == 0) {
          print('📚 Sample entry: ${batchResults.first['written_rep']} -> ${batchResults.first['trans_list']}');
        }
        var batchInserted = 0;
        var batchSkipped = 0;
        var batchErrors = 0;
        
        for (int i = 0; i < batchResults.length; i++) {
          final row = batchResults[i];
          final result = await _insertDictionaryEntry(
            sourceDb: sourceDb,
            row: row,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            dictionaryName: dictionaryName,
            entryNumber: totalImported + i,
            sourceInfo: sourceInfo,
          );
          
          if (result == InsertResult.inserted) {
            batchInserted++;
            totalImported++;
          } else if (result == InsertResult.skipped) {
            batchSkipped++;
          } else {
            batchErrors++;
          }
        }
        
        // Log batch results every 100 batches (100K entries) for reasonable progress feedback
        if ((offset ~/ batchSize) % 100 == 0) {
          print('📚 Batch ${(offset ~/ batchSize) + 1}: ${(totalImported/1000).toStringAsFixed(0)}K entries imported');
        }
        
        offset += batchSize;
        
        // Call progress callback every 200 batches (100K entries) to reduce overhead
        if ((offset ~/ batchSize) % 200 == 0 || batchResults.length < batchSize) {
          onProgress?.call(totalImported, sourceInfo.totalEntries);
        }
        
        if (batchResults.length < batchSize) {
          break;
        }
      }
    });
    
    print('📚 Import transaction completed');
    
    // Memory-efficient verification using count query instead of loading all entries
    final verificationQuery = _appDatabase.selectOnly(_appDatabase.dictionaryEntries)
      ..addColumns([_appDatabase.dictionaryEntries.id.count()])
      ..where(_appDatabase.dictionaryEntries.source.equals(dictionaryName));
    final verificationCount = await verificationQuery.map((row) => row.read(_appDatabase.dictionaryEntries.id.count()) ?? 0).getSingle();
    
    print('📚 Import completed: ${(verificationCount/1000).toStringAsFixed(0)}K entries verified');
    
    return totalImported;
  }
  
  Future<InsertResult> _insertDictionaryEntry({
    required Database sourceDb,
    required Map<String, Object?> row,
    required String sourceLanguage,
    required String targetLanguage,
    required String dictionaryName,
    required int entryNumber,
    required SourceDatabaseInfo sourceInfo,
  }) async {
    try {
      final writtenRep = row['written_rep'] as String? ?? '';
      final sense = row['sense'] as String? ?? '';
      final transList = row['trans_list'] as String? ?? '';
      final pos = row['pos'] as String?;
      final rowSourceLanguage = row['source_language'] as String? ?? '';
      final rowTargetLanguage = row['target_language'] as String? ?? '';
      
      // Minimal logging for first entry only
      if (entryNumber == 0) {
        print('📚 Processing entries: "$writtenRep" ($rowSourceLanguage→$rowTargetLanguage)');
      }
      
      if (writtenRep.isEmpty || transList.isEmpty) {
        return InsertResult.skipped;
      }
      
      // Validate data
      if (transList.length > 200) {
        if (entryNumber < 3) {
          print('⚠️ Warning: Entry ${entryNumber + 1} has very long trans_list: "${transList.substring(0, 50)}..."');
        }
      }
      
      // Create dictionary entry using modern Wiktionary format
      final companion = DictionaryEntriesCompanion.insert(
        // Modern Wiktionary fields (primary data)
        writtenRep: writtenRep.toLowerCase(),
        sense: Value(sense),
        transList: transList,
        pos: Value(pos),
        sourceLanguage: rowSourceLanguage,
        targetLanguage: rowTargetLanguage,
        frequency: const Value(1000),
        pronunciation: const Value(null),
        examples: const Value(null),
        source: Value(dictionaryName),
        // Legacy compatibility fields (for backward compatibility)
        lemma: Value(writtenRep.toLowerCase()),
        definition: Value(sense ?? transList),
        partOfSpeech: Value(pos),
        languagePair: Value('$rowSourceLanguage-$rowTargetLanguage'),
      );
      
      // Minimal companion logging (first entry only)
      if (entryNumber == 0) {
        print('📚 Sample entry: "${writtenRep.toLowerCase()}" -> "$transList" ($rowSourceLanguage→$rowTargetLanguage)');
      }
      
      // Insert with minimal logging to prevent memory issues
      final insertResult = await _appDatabase.into(_appDatabase.dictionaryEntries).insert(
        companion,
        mode: InsertMode.insertOrIgnore, // Avoid duplicates
      );
      
      // Only log first few entries to verify format
      if (entryNumber < 2) {
        print('📚 Entry ${entryNumber + 1}: ${insertResult > 0 ? "inserted" : "skipped"}');
      }
      
      // Check if actually inserted (insertOrIgnore returns -1 for ignored duplicates)
      if (insertResult > 0) {
        return InsertResult.inserted;
      } else {
        return InsertResult.skipped;
      }
      
    } catch (e) {
      // Only log first few errors to prevent spam
      if (entryNumber < 5) {
        print('❌ Import error ${entryNumber + 1}: $e');
      }
      return InsertResult.error;
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