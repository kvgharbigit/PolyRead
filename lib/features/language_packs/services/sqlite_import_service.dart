// SQLite Import Service - Handles importing dictionary data from cycling dictionary SQLite files
// Supports cycling dictionary schema (word_groups, meanings, target_reverse_lookup)

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:polyread/core/database/app_database.dart';

enum InsertResult { inserted, skipped, error }

class SqliteImportService {
  final AppDatabase _appDatabase;
  
  SqliteImportService(this._appDatabase);
  
  /// Import dictionary data from a cycling dictionary SQLite file
  Future<SqliteImportResult> importCyclingDictionary({
    required String sqlitePath,
    required String sourceLanguage,
    required String targetLanguage,
    Function(int imported, int total)? onProgress,
  }) async {
    final dictionaryName = '$sourceLanguage-$targetLanguage-cycling-dict';
    print('');
    print('📚 Starting SQLite import: $dictionaryName');
    
    // File existence check with detailed logging
    final sqliteFile = File(sqlitePath);
    final fileExists = await sqliteFile.exists();
    if (!fileExists) {
      throw SqliteImportException('SQLite file not found: $sqlitePath');
    }
    
    final fileSize = await sqliteFile.length();
    print('📚 SQLite file: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB');
    
    Database? sourceDb;
    int importedCount = 0;
    
    try {
      
      sourceDb = await openDatabase(
        sqlitePath,
        readOnly: true,
        // Remove version parameter to avoid PRAGMA user_version write operation
      );
      print('📚 Database opened successfully');
      
      // onProgress?.call(0, 1000); // Starting analysis
      final sourceInfo = await _analyzeSourceDatabase(sourceDb);
      print('📚 Found ${(sourceInfo.totalEntries/1000).toStringAsFixed(0)}K entries');
      
      if (!sourceInfo.isValidCyclingDictionary) {
        throw SqliteImportException('Invalid cycling dictionary format: ${sourceInfo.issues.join(", ")}');
      }
      
      // onProgress?.call(100, 1000); // Analysis complete
      
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
          // Log progress every 10,000 entries to keep user informed with detailed feedback
          if (processed % 10000 == 0 || processed == total) {
            print('📚 Import progress: ${(processed/1000).toStringAsFixed(0)}K/${(total/1000).toStringAsFixed(0)}K entries');
          }
          onProgress?.call(processed, total);
        },
      );
      
      print('📚 Import completed: ${(importedCount/1000).toStringAsFixed(0)}K entries');
      
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
  
  /// Validate a cycling dictionary SQLite file before import
  Future<CyclingDictionaryValidationResult> validateCyclingDictionary(String sqliteFilePath) async {
    if (!await File(sqliteFilePath).exists()) {
      return CyclingDictionaryValidationResult(
        isValid: false,
        message: 'SQLite file not found',
      );
    }
    
    Database? db;
    try {
      db = await openDatabase(sqliteFilePath, readOnly: true);
      final sourceInfo = await _analyzeSourceDatabase(db);
      
      return CyclingDictionaryValidationResult(
        isValid: sourceInfo.isValidCyclingDictionary,
        message: sourceInfo.isValidCyclingDictionary 
          ? 'Valid cycling dictionary with ${sourceInfo.totalEntries} word groups'
          : 'Invalid cycling dictionary format: ${sourceInfo.issues.join(", ")}',
        totalEntries: sourceInfo.totalEntries,
        tables: sourceInfo.tables,
        issues: sourceInfo.issues,
      );
    } catch (e) {
      return CyclingDictionaryValidationResult(
        isValid: false,
        message: 'Database validation failed: $e',
      );
    } finally {
      await db?.close();
    }
  }
  
  /// Clear all entries for a specific cycling dictionary (by language pair)
  Future<void> clearDictionary(String sourceLanguage, String targetLanguage) async {
    // Delete word groups for this language pair (cascades to meanings and reverse lookups)
    await (_appDatabase.delete(_appDatabase.wordGroups)
      ..where((wg) => wg.sourceLanguage.equals(sourceLanguage) & 
                      wg.targetLanguage.equals(targetLanguage))).go();
  }
  
  /// Get import statistics for cycling dictionary data
  Future<ImportStats> getDictionaryStats(String dictionaryName) async {
    // Get stats from cycling dictionary structure (word_groups table)
    final countResult = await _appDatabase.customSelect('''
      SELECT 
        source_language,
        target_language,
        COUNT(*) as entry_count,
        MIN(created_at) as first_import,
        MAX(created_at) as last_import
      FROM word_groups 
      GROUP BY source_language, target_language
    ''').get();
    
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
      
      print('📊 Available tables in database: $tableNames');
      
      // Check for required cycling dictionary tables
      const requiredTables = ['word_groups', 'meanings', 'target_reverse_lookup'];
      final missingTables = requiredTables.where((table) => !tableNames.contains(table)).toList();
      
      if (missingTables.isNotEmpty) {
        print('❌ Missing required tables: $missingTables');
        print('📋 Available tables: $tableNames');
        
        // If we have other tables, let's see their structure
        if (tableNames.isNotEmpty) {
          for (final tableName in tableNames.take(3)) { // Check first 3 tables
            try {
              final columns = await db.rawQuery('PRAGMA table_info($tableName)');
              final columnNames = columns.map((c) => c['name'] as String).toList();
              print('🔍 Table "$tableName" columns: $columnNames');
              
              // Check if this might be a legacy format
              if (columnNames.contains('written_rep') && columnNames.contains('trans_list')) {
                print('💡 Detected legacy Wiktionary format in table: $tableName');
              }
            } catch (e) {
              print('⚠️ Could not analyze table $tableName: $e');
            }
          }
        }
        
        issues.add('Missing required tables: ${missingTables.join(", ")}');
      } else {
        print('✅ All required cycling dictionary tables found');
      }
      
      // Get word group count (main entries)
      int totalEntries = 0;
      try {
        final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM word_groups');
        totalEntries = countResult.first['count'] as int;
      } catch (e) {
        issues.add('Could not count word groups: $e');
      }
      
      // Check table structure - validate cycling dictionary format
      bool hasValidFormat = false;
      if (tableNames.contains('word_groups') && tableNames.contains('meanings')) {
        // Check word_groups table columns
        final wgColumns = await db.rawQuery('PRAGMA table_info(word_groups)');
        final wgColumnNames = wgColumns.map((c) => c['name'] as String).toList();
        
        // Check meanings table columns
        final mColumns = await db.rawQuery('PRAGMA table_info(meanings)');
        final mColumnNames = mColumns.map((c) => c['name'] as String).toList();
        
        // Check for required cycling dictionary columns
        const requiredWgColumns = ['base_word', 'source_language', 'target_language'];
        const requiredMColumns = ['target_meaning', 'meaning_order', 'word_group_id'];
        
        final missingWg = requiredWgColumns.where((col) => !wgColumnNames.contains(col)).toList();
        final missingM = requiredMColumns.where((col) => !mColumnNames.contains(col)).toList();
        
        hasValidFormat = missingWg.isEmpty && missingM.isEmpty;
        
        print('📊 Cycling dictionary schema analysis:');
        print('  Word groups columns: $wgColumnNames');
        print('  Meanings columns: $mColumnNames');
        print('  Has valid cycling format: $hasValidFormat');
        
        if (missingWg.isNotEmpty) {
          issues.add('Missing required word_groups columns: ${missingWg.join(", ")}');
        }
        if (missingM.isNotEmpty) {
          issues.add('Missing required meanings columns: ${missingM.join(", ")}');
        }
      }
      
      final isValid = issues.isEmpty && totalEntries > 0 && hasValidFormat;
      
      return SourceDatabaseInfo(
        tables: tableNames,
        totalEntries: totalEntries,
        issues: issues,
        isValidCyclingDictionary: isValid,
      );
      
    } catch (e) {
      issues.add('Database analysis failed: $e');
      return SourceDatabaseInfo(
        tables: [],
        totalEntries: 0,
        issues: issues,
        isValidCyclingDictionary: false,
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
    
    // Memory-efficient initial count check using cycling dictionary tables
    final countQuery = _appDatabase.selectOnly(_appDatabase.wordGroups)
      ..addColumns([_appDatabase.wordGroups.id.count()])
      ..where(_appDatabase.wordGroups.sourceLanguage.equals(sourceLanguage) &
              _appDatabase.wordGroups.targetLanguage.equals(targetLanguage));
    final initialCount = await countQuery.map((row) => row.read(_appDatabase.wordGroups.id.count()) ?? 0).getSingle();
    print('📚 Initial word groups: $initialCount');
    
    await _appDatabase.transaction(() async {
      while (true) {
        // Only log every 40th batch (20K entries) to provide more frequent updates
        if ((offset ~/ batchSize) % 40 == 0) {
          print('📚 Processing batch ${(offset ~/ batchSize) + 1}...');
        }
        
        // Fetch batch from source database using cycling dictionary format
        if (offset == 0) {
          print('📊 Using cycling dictionary format - copying data directly');
        }
        
        final batchResults = await sourceDb.rawQuery('''
          SELECT 
            wg.id as source_wg_id,
            wg.base_word,
            wg.word_forms,
            wg.part_of_speech as wg_pos,
            wg.source_language,
            wg.target_language,
            m.id as source_m_id,
            m.meaning_order,
            m.target_meaning,
            m.context,
            m.part_of_speech as m_pos,
            m.is_primary
          FROM word_groups wg
          JOIN meanings m ON m.word_group_id = wg.id
          WHERE wg.source_language = ? AND wg.target_language = ?
          ORDER BY wg.id, m.meaning_order
          LIMIT ? OFFSET ?
        ''', [sourceLanguage, targetLanguage, batchSize, offset]);
        
        if (batchResults.isEmpty) {
          break;
        }
        
        // Log sample only for first batch (reduced logging)
        if (offset == 0) {
          print('📚 Sample entry: ${batchResults.first['base_word']} -> ${batchResults.first['target_meaning']}');
        }
        var batchInserted = 0;
        var batchSkipped = 0;
        var batchErrors = 0;
        
        for (int i = 0; i < batchResults.length; i++) {
          final row = batchResults[i];
          final result = await _insertCyclingDictionaryEntry(
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
        
        // Log batch results every 20 batches (10K entries) for detailed progress feedback
        if ((offset ~/ batchSize) % 20 == 0) {
          print('📚 Batch ${(offset ~/ batchSize) + 1}: ${(totalImported/1000).toStringAsFixed(0)}K entries imported');
        }
        
        offset += batchSize;
        
        // Call progress callback every 20 batches (10K entries) for responsive UI updates
        if ((offset ~/ batchSize) % 20 == 0 || batchResults.length < batchSize) {
          onProgress?.call(totalImported, sourceInfo.totalEntries);
        }
        
        if (batchResults.length < batchSize) {
          break;
        }
      }
    });
    
    print('📚 Import transaction completed');
    
    // Memory-efficient verification using cycling dictionary count
    final verificationQuery = _appDatabase.selectOnly(_appDatabase.wordGroups)
      ..addColumns([_appDatabase.wordGroups.id.count()])
      ..where(_appDatabase.wordGroups.sourceLanguage.equals(sourceLanguage) &
              _appDatabase.wordGroups.targetLanguage.equals(targetLanguage));
    final verificationCount = await verificationQuery.map((row) => row.read(_appDatabase.wordGroups.id.count()) ?? 0).getSingle();
    
    print('📚 Import completed: ${(verificationCount/1000).toStringAsFixed(0)}K entries verified');
    
    return totalImported;
  }
  
  Future<InsertResult> _insertCyclingDictionaryEntry({
    required Database sourceDb,
    required Map<String, Object?> row,
    required String sourceLanguage,
    required String targetLanguage,
    required String dictionaryName,
    required int entryNumber,
    required SourceDatabaseInfo sourceInfo,
  }) async {
    try {
      // This row comes from a JOIN of word_groups and meanings tables
      // We need to handle it as a combined entry, not determine table type
      
      final baseWord = row['base_word'] as String?;
      final wordForms = row['word_forms'] as String? ?? baseWord ?? '';
      final targetMeaning = row['target_meaning'] as String?;
      final meaningOrder = row['meaning_order'] as int? ?? 1;
      
      if (baseWord == null || baseWord.isEmpty || targetMeaning == null || targetMeaning.isEmpty) {
        return InsertResult.skipped;
      }
      
      // Step 1: Insert or get word group
      final wordGroupCompanion = WordGroupsCompanion.insert(
        baseWord: baseWord,
        wordForms: wordForms,
        partOfSpeech: Value(row['wg_pos'] as String? ?? row['part_of_speech'] as String?),
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      
      final wordGroupId = await _appDatabase.into(_appDatabase.wordGroups).insert(
        wordGroupCompanion,
        mode: InsertMode.insertOrIgnore,
      );
      
      // Step 2: Insert meaning
      final meaningCompanion = MeaningsCompanion.insert(
        wordGroupId: wordGroupId,
        meaningOrder: meaningOrder,
        targetMeaning: targetMeaning,
        context: Value(row['context'] as String?),
        partOfSpeech: Value(row['m_pos'] as String? ?? row['part_of_speech'] as String?),
        isPrimary: Value((row['is_primary'] as int? ?? 0) == 1),
      );
      
      final meaningId = await _appDatabase.into(_appDatabase.meanings).insert(
        meaningCompanion,
        mode: InsertMode.insertOrIgnore,
      );
      
      // Step 3: Create reverse lookup entry for target word search
      if (targetMeaning.isNotEmpty) {
        // Clean target meaning for reverse lookup (remove extra info)
        final cleanTargetMeaning = targetMeaning.split(',').first.split('(').first.trim().toLowerCase();
        
        if (cleanTargetMeaning.isNotEmpty) {
          final reverseLookupCompanion = TargetReverseLookupCompanion.insert(
            targetWord: cleanTargetMeaning,
            sourceWordGroupId: wordGroupId,
            sourceMeaningId: meaningId,
            lookupOrder: meaningOrder,
            qualityScore: Value(100 - ((meaningOrder - 1) * 10)), // Decrease quality for later meanings
          );
          
          await _appDatabase.into(_appDatabase.targetReverseLookup).insert(
            reverseLookupCompanion,
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
      
      return InsertResult.inserted;
      
    } catch (e) {
      // Only log first few errors to prevent spam
      if (entryNumber < 5) {
        print('Error inserting cycling dictionary entry $entryNumber: $e');
      }
      return InsertResult.error;
    }
  }

  // LEGACY METHOD - Remove after migration to cycling dictionary downloads
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
      
      // Insert into cycling dictionary format (WordGroups + Meanings)
      // For now, create a simple mapping - this would need more sophisticated processing
      // to properly group meanings and handle cycling
      
      // Create or find word group
      final wordGroupCompanion = WordGroupsCompanion.insert(
        baseWord: writtenRep.toLowerCase(),
        wordForms: writtenRep.toLowerCase(), // Simple case - would need better form processing
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        partOfSpeech: Value(pos),
      );
      
      final wordGroupId = await _appDatabase.into(_appDatabase.wordGroups)
          .insert(wordGroupCompanion, mode: InsertMode.insertOrIgnore);
      
      // Create meaning entry
      final meaningCompanion = MeaningsCompanion.insert(
        wordGroupId: wordGroupId,
        meaningOrder: 1, // Simple case - would need better meaning ordering
        targetMeaning: transList.split('|').first.trim(), // Take first translation
        context: Value(sense),
        partOfSpeech: Value(pos),
        isPrimary: Value(true), // Mark first meaning as primary
      );
      
      // Minimal companion logging (first entry only)
      if (entryNumber == 0) {
        print('📚 Sample entry: "${writtenRep.toLowerCase()}" -> "$transList" ($rowSourceLanguage→$rowTargetLanguage)');
      }
      
      // Insert meaning into cycling dictionary
      final meaningId = await _appDatabase.into(_appDatabase.meanings).insert(
        meaningCompanion,
        mode: InsertMode.insertOrIgnore, // Avoid duplicates
      );
      
      // Create reverse lookup entry for target language searches
      final translations = transList.split('|');
      for (int i = 0; i < translations.length && i < 3; i++) { // Limit to first 3 translations
        final targetWord = translations[i].trim().toLowerCase();
        if (targetWord.isNotEmpty) {
          final reverseLookupCompanion = TargetReverseLookupCompanion.insert(
            targetWord: targetWord,
            sourceWordGroupId: wordGroupId,
            sourceMeaningId: meaningId,
            lookupOrder: i + 1,
            qualityScore: Value(100 - (i * 10)), // Decrease quality for later translations
          );
          
          await _appDatabase.into(_appDatabase.targetReverseLookup).insert(
            reverseLookupCompanion,
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
      
      // Only log first few entries to verify format
      if (entryNumber < 2) {
        print('📚 Entry ${entryNumber + 1}: inserted into cycling dictionary');
      }
      
      return InsertResult.inserted;
      
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
  
  /// Alias for importedEntries to match expected API
  int get entriesImported => importedEntries;
}

class CyclingDictionaryValidationResult {
  final bool isValid;
  final String message;
  final int totalEntries;
  final List<String> tables;
  final List<String> issues;
  
  const CyclingDictionaryValidationResult({
    required this.isValid,
    required this.message,
    this.totalEntries = 0,
    this.tables = const [],
    this.issues = const [],
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
  final bool isValidCyclingDictionary;
  
  const SourceDatabaseInfo({
    required this.tables,
    required this.totalEntries,
    required this.issues,
    required this.isValidCyclingDictionary,
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