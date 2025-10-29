// Language Pack Integration Service
// Connects downloaded language packs to translation and dictionary services
// Enhanced to work with DictionaryManagementService

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/services/dictionary_loader_service.dart';
import 'package:polyread/core/services/dictionary_management_service.dart';
import 'package:polyread/features/language_packs/models/language_pack_manifest.dart';
import 'package:polyread/core/services/error_service.dart';
import 'package:polyread/features/language_packs/services/zip_extraction_service.dart';
import 'package:polyread/features/language_packs/services/sqlite_import_service.dart';
import 'package:drift/drift.dart';

class LanguagePackIntegrationService {
  final AppDatabase _database;
  final DictionaryLoaderService _dictionaryLoader;
  final DictionaryManagementService _dictionaryManagementService;
  final ZipExtractionService _zipExtractor;
  final SqliteImportService _sqliteImporter;

  LanguagePackIntegrationService({
    required AppDatabase database,
    required DictionaryLoaderService dictionaryLoader,
    DictionaryManagementService? dictionaryManagementService,
    ZipExtractionService? zipExtractor,
    SqliteImportService? sqliteImporter,
  }) : _database = database,
       _dictionaryLoader = dictionaryLoader,
       _dictionaryManagementService = dictionaryManagementService ?? DictionaryManagementService(database),
       _zipExtractor = zipExtractor ?? ZipExtractionService(),
       _sqliteImporter = sqliteImporter ?? SqliteImportService(database);

  /// Install a downloaded language pack into the system
  Future<LanguagePackInstallationResult> installLanguagePack(LanguagePackManifest manifest, String downloadPath) async {
    try {
      print('');
      print('🔧 LanguagePackIntegrationService.installLanguagePack: STARTING INSTALLATION');
      print('🔧 LanguagePackIntegrationService: Pack ID: ${manifest.id}');
      print('🔧 LanguagePackIntegrationService: Pack name: ${manifest.name}');
      print('🔧 LanguagePackIntegrationService: Pack type: ${manifest.packType}');
      print('🔧 LanguagePackIntegrationService: Download path: $downloadPath');
      print('🔧 LanguagePackIntegrationService: Files: ${manifest.files.length}');
      
      for (final file in manifest.files) {
        print('🔧 LanguagePackIntegrationService: File: ${file.name} (${file.type})');
      }

      // 1. Validate pack files exist - handle both directory and direct file paths
      late bool isDirectory;
      if (await Directory(downloadPath).exists()) {
        isDirectory = true;
        print('🔧 LanguagePackIntegrationService: Download path is a directory');
      } else if (await File(downloadPath).exists()) {
        isDirectory = false;
        print('🔧 LanguagePackIntegrationService: Download path is a file');
      } else {
        print('🔧 LanguagePackIntegrationService: ❌ Path not found: $downloadPath');
        throw Exception('Language pack path not found: $downloadPath');
      }

      var dictionaryInstalled = false;
      var modelsInstalled = false;

      // 2. Load dictionary data if this is a dictionary pack
      print('🔧 LanguagePackIntegrationService: Checking pack type for dictionary loading...');
      print('🔧 LanguagePackIntegrationService: Pack type: "${manifest.packType}"');
      print('🔧 LanguagePackIntegrationService: Is dictionary pack? ${manifest.packType == 'dictionary' || manifest.packType == 'combined'}');
      
      if (manifest.packType == 'dictionary' || manifest.packType == 'combined') {
        print('🔧 LanguagePackIntegrationService: ✅ Loading dictionary data...');
        final result = await _loadDictionaryFromPack(manifest, downloadPath);
        dictionaryInstalled = result.success;
        
        print('🔧 LanguagePackIntegrationService: Dictionary loading result: ${result.success}');
        if (result.error != null) {
          print('🔧 LanguagePackIntegrationService: Dictionary loading error: ${result.error}');
        }
        
        if (result.success) {
          // Trigger dictionary management service to update availability status
          final availability = await _dictionaryManagementService.getAvailabilityStatus(
            sourceLanguage: manifest.sourceLanguage,
            targetLanguage: manifest.targetLanguage,
          );
          print('🔧 LanguagePackIntegrationService: Dictionary availability after installation: ${availability.isAvailable}');
        }
      } else {
        print('🔧 LanguagePackIntegrationService: ⚠️ Skipping dictionary loading - pack type is "${manifest.packType}"');
      }

      // 3. Install ML Kit models if this is a translation model pack
      if (manifest.packType == 'translation_model' || manifest.packType == 'combined') {
        modelsInstalled = await _installTranslationModels(manifest, downloadPath);
      }

      // 4. Update pack status in database
      await _updatePackStatus(manifest, isInstalled: true);

      print('Successfully installed language pack: ${manifest.name}');

      return LanguagePackInstallationResult(
        success: true,
        packId: manifest.id,
        dictionaryInstalled: dictionaryInstalled,
        modelsInstalled: modelsInstalled,
        message: 'Language pack ${manifest.name} installed successfully',
      );

    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to install language pack ${manifest.name}',
        details: e.toString(),
      );
      
      return LanguagePackInstallationResult(
        success: false,
        packId: manifest.id,
        dictionaryInstalled: false,
        modelsInstalled: false,
        message: 'Failed to install ${manifest.name}: $e',
        error: e.toString(),
      );
    }
  }

  /// Load dictionary data from a language pack
  Future<DictionaryLoadResult> _loadDictionaryFromPack(LanguagePackManifest manifest, String packPath) async {
    try {
      print('📚 _loadDictionaryFromPack: Loading dictionary from pack: ${manifest.name}');
      print('📚 _loadDictionaryFromPack: Pack path: $packPath');
      
      List<String> zipFilePaths = [];
      
      // Handle both directory and direct file path cases
      if (await Directory(packPath).exists()) {
        print('📚 _loadDictionaryFromPack: Pack path is a directory, searching for ZIP files...');
        final packDir = Directory(packPath);
        final zipFiles = await packDir.list().where((file) => 
          file is File && file.path.endsWith('.sqlite.zip')
        ).toList();
        zipFilePaths = zipFiles.map((f) => f.path).toList();
        print('📚 _loadDictionaryFromPack: Found ${zipFilePaths.length} ZIP files in directory');
      } else if (await File(packPath).exists() && packPath.endsWith('.sqlite.zip')) {
        print('📚 _loadDictionaryFromPack: Pack path is a direct ZIP file');
        zipFilePaths = [packPath];
      } else {
        print('📚 _loadDictionaryFromPack: ❌ Pack path is neither valid directory nor ZIP file');
      }
      
      if (zipFilePaths.isNotEmpty) {
        print('📚 _loadDictionaryFromPack: Processing ${zipFilePaths.length} SQLite ZIP file(s)...');
        
        var totalEntriesLoaded = 0;
        
        for (final zipFilePath in zipFilePaths) {
          print('📚 _loadDictionaryFromPack: Processing ZIP: $zipFilePath');
          final result = await _loadDictionaryFromSqliteZip(
            zipFilePath: zipFilePath,
            manifest: manifest,
          );
          
          print('📚 _loadDictionaryFromPack: ZIP processing result: success=${result.success}, entries=${result.entriesLoaded}');
          if (result.error != null) {
            print('📚 _loadDictionaryFromPack: ZIP processing error: ${result.error}');
          }
          
          if (result.success) {
            totalEntriesLoaded += result.entriesLoaded;
          }
        }
        
        print('📚 _loadDictionaryFromPack: Total entries loaded: $totalEntriesLoaded');
        
        if (totalEntriesLoaded > 0) {
          return DictionaryLoadResult(
            success: true,
            entriesLoaded: totalEntriesLoaded,
            message: 'Dictionary loaded successfully from SQLite files: $totalEntriesLoaded entries',
          );
        } else {
          return DictionaryLoadResult(
            success: false,
            entriesLoaded: 0,
            message: 'No entries were loaded from ZIP files',
            error: 'No entries were loaded from ZIP files',
          );
        }
      }
      
      // Fallback: Look for dictionary JSON file (legacy format)
      final dictionaryFile = File(path.join(packPath, 'dictionary.json'));
      
      if (await dictionaryFile.exists()) {
        print('Loading dictionary from JSON file: ${dictionaryFile.path}');
        
        // Read and parse dictionary JSON
        final jsonContent = await dictionaryFile.readAsString();
        final dictionaryData = jsonDecode(jsonContent) as Map<String, dynamic>;
        
        // Load entries into database
        final entriesLoaded = await _loadDictionaryEntries(dictionaryData, manifest);
        
        return DictionaryLoadResult(
          success: true,
          entriesLoaded: entriesLoaded,
          message: 'Dictionary loaded successfully from JSON: $entriesLoaded entries',
        );
      }
      
      print('No dictionary files found in pack');
      return DictionaryLoadResult(
        success: false,
        entriesLoaded: 0,
        message: 'No dictionary files (.sqlite.zip or dictionary.json) found in pack',
      );
      
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to load dictionary from pack ${manifest.name}',
        details: e.toString(),
      );
      
      return DictionaryLoadResult(
        success: false,
        entriesLoaded: 0,
        message: 'Failed to load dictionary: $e',
        error: e.toString(),
      );
    }
  }
  
  /// Load dictionary from SQLite ZIP file
  Future<DictionaryLoadResult> _loadDictionaryFromSqliteZip({
    required String zipFilePath,
    required LanguagePackManifest manifest,
  }) async {
    try {
      print('Processing SQLite ZIP: $zipFilePath');
      
      // Create temporary directory for extraction
      final tempDir = await Directory.systemTemp.createTemp('dictionary_import_');
      
      try {
        // Extract the SQLite file from ZIP
        final extractedSqlitePath = await _zipExtractor.extractDictionarySqlite(
          zipFilePath: zipFilePath,
          destinationDir: tempDir.path,
          onProgress: (message) => print('Extraction: $message'),
        );
        
        if (extractedSqlitePath == null) {
          throw Exception('No SQLite file found in ZIP archive');
        }
        
        print('Extracted SQLite file: $extractedSqlitePath');
        
        // Import the SQLite data into app database
        final importResult = await _sqliteImporter.importWiktionarySqlite(
          sqliteFilePath: extractedSqlitePath,
          sourceLanguage: manifest.sourceLanguage,
          targetLanguage: manifest.targetLanguage,
          dictionaryName: manifest.name,
          onProgress: (message, progress) => print('Import: $message ($progress%)'),
        );
        
        if (importResult.success) {
          print('Successfully imported ${importResult.importedEntries} entries');
          return DictionaryLoadResult(
            success: true,
            entriesLoaded: importResult.importedEntries,
            message: importResult.message ?? 'Import completed successfully',
          );
        } else {
          return DictionaryLoadResult(
            success: false,
            entriesLoaded: 0,
            message: importResult.message ?? 'Import failed',
            error: importResult.error ?? 'Unknown import error',
          );
        }
        
      } finally {
        // Clean up temporary directory
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          print('Warning: Failed to cleanup temp directory: $e');
        }
      }
      
    } catch (e) {
      print('Failed to load dictionary from SQLite ZIP: $e');
      return DictionaryLoadResult(
        success: false,
        entriesLoaded: 0,
        message: 'Failed to load dictionary from SQLite: $e',
        error: e.toString(),
      );
    }
  }

  /// Load dictionary entries from parsed JSON data
  Future<int> _loadDictionaryEntries(Map<String, dynamic> data, LanguagePackManifest manifest) async {
    final entries = data['entries'] as List<dynamic>? ?? [];
    final languagePair = '${manifest.sourceLanguage}-${manifest.targetLanguage}';
    
    print('Loading ${entries.length} dictionary entries for $languagePair');
    
    final batchEntries = <DictionaryEntriesCompanion>[];
    var totalInserted = 0;
    
    for (final entryData in entries) {
      final entry = entryData as Map<String, dynamic>;
      
      // Handle Wiktionary format: pipe-separated translations
      final translations = entry['translations'] as dynamic;
      final transList = translations is List 
          ? translations.join(' | ') 
          : translations?.toString() ?? entry['translation']?.toString() ?? '';
      
      batchEntries.add(DictionaryEntriesCompanion.insert(
        writtenRep: entry['word'] as String,
        lexentry: Value(entry['lexentry'] as String?),
        sense: Value(entry['definition'] as String? ?? entry['sense'] as String?),
        transList: transList,
        pos: Value(entry['pos'] as String?),
        domain: Value(entry['domain'] as String?),
        sourceLanguage: manifest.sourceLanguage,
        targetLanguage: manifest.targetLanguage,
        frequency: Value(entry['frequency'] as int? ?? 0),
        pronunciation: Value(entry['pronunciation'] as String?),
        examples: Value(entry['examples'] != null ? jsonEncode(entry['examples']) : null),
        source: Value(manifest.name),
      ));
      
      // Insert in batches of 100
      if (batchEntries.length >= 100) {
        await _insertDictionaryBatch(batchEntries);
        totalInserted += batchEntries.length;
        batchEntries.clear();
      }
    }
    
    // Insert remaining entries
    if (batchEntries.isNotEmpty) {
      await _insertDictionaryBatch(batchEntries);
      totalInserted += batchEntries.length;
    }
    
    print('Successfully loaded $totalInserted dictionary entries');
    return totalInserted;
  }

  /// Insert a batch of dictionary entries
  Future<void> _insertDictionaryBatch(List<DictionaryEntriesCompanion> entries) async {
    await _database.batch((batch) {
      for (final entry in entries) {
        batch.insert(_database.dictionaryEntries, entry);
      }
    });
  }

  /// Install translation models (placeholder for ML Kit integration)
  Future<bool> _installTranslationModels(LanguagePackManifest manifest, String packPath) async {
    try {
      print('Installing translation models for ${manifest.name}');
      
      // Check for ML Kit model files
      final modelsDir = Directory(path.join(packPath, 'models'));
      if (await modelsDir.exists()) {
        // TODO: Integrate with ML Kit model installation
        // For now, just log that models are available
        print('Translation models found in pack, ready for ML Kit integration');
        
        // Register language pair as available for translation
        await _registerLanguagePair(manifest);
        return true;
      } else {
        print('No translation models found in pack');
        return false;
      }
      
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to install translation models for ${manifest.name}',
        details: e.toString(),
      );
      return false;
    }
  }

  /// Register a language pair as available for translation
  Future<void> _registerLanguagePair(LanguagePackManifest manifest) async {
    // Update language pack record to mark as active
    await (_database.update(_database.languagePacks)
        ..where((pack) => pack.packId.equals(manifest.id)))
        .write(LanguagePacksCompanion(
          isActive: Value(true),
          lastUsedAt: Value(DateTime.now()),
        ));
  }

  /// Update language pack installation status
  Future<void> _updatePackStatus(LanguagePackManifest manifest, {required bool isInstalled}) async {
    final now = DateTime.now();
    
    // Use upsert to handle existing packs
    await (_database.update(_database.languagePacks)
        ..where((pack) => pack.packId.equals(manifest.id)))
        .write(LanguagePacksCompanion(
          name: Value(manifest.name),
          description: Value(manifest.description),
          sourceLanguage: Value(manifest.sourceLanguage),
          targetLanguage: Value(manifest.targetLanguage),
          packType: Value(manifest.packType),
          version: Value(manifest.version),
          sizeBytes: Value(manifest.totalSize),
          downloadUrl: Value(manifest.downloadUrl ?? ''),
          checksum: Value(manifest.checksum ?? ''),
          isInstalled: Value(isInstalled),
          isActive: Value(isInstalled),
          installedAt: Value(isInstalled ? now : null),
          lastUsedAt: Value(isInstalled ? now : null),
        ));
    
    // If no rows were updated, insert new record
    final existingPack = await (_database.select(_database.languagePacks)
        ..where((pack) => pack.packId.equals(manifest.id)))
        .getSingleOrNull();
    
    if (existingPack == null) {
      await _database.into(_database.languagePacks).insert(
        LanguagePacksCompanion.insert(
          packId: manifest.id,
          name: manifest.name,
          description: Value(manifest.description),
          sourceLanguage: manifest.sourceLanguage,
          targetLanguage: manifest.targetLanguage,
          packType: manifest.packType,
          version: manifest.version,
          sizeBytes: manifest.totalSize,
          downloadUrl: manifest.downloadUrl ?? '',
          checksum: manifest.checksum ?? '',
          isInstalled: Value(isInstalled),
          isActive: Value(isInstalled),
          installedAt: Value(isInstalled ? now : null),
          lastUsedAt: Value(isInstalled ? now : null),
        ),
      );
    }
  }

  /// Uninstall a language pack
  Future<void> uninstallLanguagePack(String packId) async {
    try {
      print('Uninstalling language pack: $packId');

      // Remove dictionary entries for this pack
      await (_database.delete(_database.dictionaryEntries)
          ..where((entry) => entry.source.equals(packId)))
          .go();

      // Update pack status
      await (_database.update(_database.languagePacks)
          ..where((pack) => pack.packId.equals(packId)))
          .write(LanguagePacksCompanion(
            isInstalled: Value(false),
            isActive: Value(false),
            installedAt: Value(null),
          ));

      print('Successfully uninstalled language pack: $packId');

    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to uninstall language pack $packId',
        details: e.toString(),
      );
      rethrow;
    }
  }

  /// Get list of installed language packs
  Future<List<LanguagePack>> getInstalledLanguagePacks() async {
    return await (_database.select(_database.languagePacks)
        ..where((pack) => pack.isInstalled.equals(true)))
        .get();
  }

  /// Get available language pairs for translation
  Future<List<String>> getAvailableLanguagePairs() async {
    final packs = await getInstalledLanguagePacks();
    final pairs = <String>{};
    
    for (final pack in packs) {
      pairs.add('${pack.sourceLanguage}-${pack.targetLanguage}');
      // Add reverse pair for bidirectional support
      pairs.add('${pack.targetLanguage}-${pack.sourceLanguage}');
    }
    
    return pairs.toList();
  }

  /// Check if a language pair is supported
  Future<bool> isLanguagePairSupported(String sourceLanguage, String targetLanguage) async {
    final pairs = await getAvailableLanguagePairs();
    return pairs.contains('$sourceLanguage-$targetLanguage');
  }

  /// Get dictionary management service for external use
  DictionaryManagementService get dictionaryManagementService => _dictionaryManagementService;

  /// Test dictionary functionality after language pack installation
  Future<DictionaryTestResult> testDictionaryAfterInstallation({
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    return await _dictionaryManagementService.testDictionary(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
}

// Result classes for language pack integration

class LanguagePackInstallationResult {
  final bool success;
  final String packId;
  final bool dictionaryInstalled;
  final bool modelsInstalled;
  final String message;
  final String? error;

  const LanguagePackInstallationResult({
    required this.success,
    required this.packId,
    required this.dictionaryInstalled,
    required this.modelsInstalled,
    required this.message,
    this.error,
  });
}

class DictionaryLoadResult {
  final bool success;
  final int entriesLoaded;
  final String message;
  final String? error;

  const DictionaryLoadResult({
    required this.success,
    required this.entriesLoaded,
    required this.message,
    this.error,
  });
}