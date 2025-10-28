// Language Pack Integration Service
// Connects downloaded language packs to translation and dictionary services

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/services/dictionary_loader_service.dart';
import 'package:polyread/features/language_packs/models/language_pack_manifest.dart';
import 'package:polyread/core/services/error_service.dart';

class LanguagePackIntegrationService {
  final AppDatabase _database;
  final DictionaryLoaderService _dictionaryLoader;

  LanguagePackIntegrationService({
    required AppDatabase database,
    required DictionaryLoaderService dictionaryLoader,
  }) : _database = database,
       _dictionaryLoader = dictionaryLoader;

  /// Install a downloaded language pack into the system
  Future<void> installLanguagePack(LanguagePackManifest manifest, String downloadPath) async {
    try {
      print('Installing language pack: ${manifest.name}');

      // 1. Validate pack files exist
      final packDir = Directory(downloadPath);
      if (!await packDir.exists()) {
        throw Exception('Language pack directory not found: $downloadPath');
      }

      // 2. Load dictionary data if this is a dictionary pack
      if (manifest.packType == 'dictionary' || manifest.packType == 'combined') {
        await _loadDictionaryFromPack(manifest, downloadPath);
      }

      // 3. Install ML Kit models if this is a translation model pack
      if (manifest.packType == 'translation_model' || manifest.packType == 'combined') {
        await _installTranslationModels(manifest, downloadPath);
      }

      // 4. Update pack status in database
      await _updatePackStatus(manifest, isInstalled: true);

      print('Successfully installed language pack: ${manifest.name}');

    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to install language pack ${manifest.name}',
        details: e.toString(),
      );
      rethrow;
    }
  }

  /// Load dictionary data from a language pack
  Future<void> _loadDictionaryFromPack(LanguagePackManifest manifest, String packPath) async {
    try {
      // Look for dictionary JSON file
      final dictionaryFile = File(path.join(packPath, 'dictionary.json'));
      
      if (await dictionaryFile.exists()) {
        print('Loading dictionary from ${dictionaryFile.path}');
        
        // Read and parse dictionary JSON
        final jsonContent = await dictionaryFile.readAsString();
        final dictionaryData = jsonDecode(jsonContent) as Map<String, dynamic>;
        
        // Load entries into database
        await _loadDictionaryEntries(dictionaryData, manifest);
      } else {
        print('No dictionary.json found in pack, skipping dictionary loading');
      }
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to load dictionary from pack ${manifest.name}',
        details: e.toString(),
      );
      // Don't rethrow - pack can still be partially useful
    }
  }

  /// Load dictionary entries from parsed JSON data
  Future<void> _loadDictionaryEntries(Map<String, dynamic> data, LanguagePackManifest manifest) async {
    final entries = data['entries'] as List<dynamic>? ?? [];
    final languagePair = '${manifest.sourceLanguage}-${manifest.targetLanguage}';
    
    print('Loading ${entries.length} dictionary entries for $languagePair');
    
    final batchEntries = <DictionaryEntriesCompanion>[];
    
    for (final entryData in entries) {
      final entry = entryData as Map<String, dynamic>;
      
      batchEntries.add(DictionaryEntriesCompanion.insert(
        lemma: entry['word'] as String,
        definition: entry['translation'] as String,
        partOfSpeech: Value(entry['pos'] as String?),
        languagePair: languagePair,
        frequency: entry['frequency'] as int? ?? 0,
        pronunciation: Value(entry['pronunciation'] as String?),
        examples: Value(entry['examples'] != null ? jsonEncode(entry['examples']) : null),
        synonyms: Value(entry['synonyms'] != null ? jsonEncode(entry['synonyms']) : null),
        source: Value(manifest.name),
      ));
      
      // Insert in batches of 100
      if (batchEntries.length >= 100) {
        await _insertDictionaryBatch(batchEntries);
        batchEntries.clear();
      }
    }
    
    // Insert remaining entries
    if (batchEntries.isNotEmpty) {
      await _insertDictionaryBatch(batchEntries);
    }
    
    print('Successfully loaded ${entries.length} dictionary entries');
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
  Future<void> _installTranslationModels(LanguagePackManifest manifest, String packPath) async {
    try {
      print('Installing translation models for ${manifest.name}');
      
      // Check for ML Kit model files
      final modelsDir = Directory(path.join(packPath, 'models'));
      if (await modelsDir.exists()) {
        // TODO: Integrate with ML Kit model installation
        // For now, just log that models are available
        print('Translation models found in pack, ready for ML Kit integration');
      }
      
      // Register language pair as available for translation
      await _registerLanguagePair(manifest);
      
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to install translation models for ${manifest.name}',
        details: e.toString(),
      );
    }
  }

  /// Register a language pair as available for translation
  Future<void> _registerLanguagePair(LanguagePackManifest manifest) async {
    // Update language pack record to mark as active
    await (_database.update(_database.languagePacks)
        ..where((pack) => pack.packId.equals(manifest.id)))
        .write(const LanguagePacksCompanion(
          isActive: Value(true),
          lastUsedAt: Value.absent(),
        ));
  }

  /// Update language pack installation status
  Future<void> _updatePackStatus(LanguagePackManifest manifest, {required bool isInstalled}) async {
    final now = DateTime.now();
    
    await _database.into(_database.languagePacks).insertOnConflictUpdate(
      LanguagePacksCompanion.insert(
        packId: manifest.id,
        name: manifest.name,
        description: Value(manifest.description),
        sourceLanguage: manifest.sourceLanguage,
        targetLanguage: manifest.targetLanguage,
        packType: manifest.packType,
        version: manifest.version,
        sizeBytes: manifest.totalSize,
        downloadUrl: manifest.downloadUrl,
        checksum: manifest.checksum,
        isInstalled: isInstalled,
        isActive: isInstalled,
        installedAt: Value(isInstalled ? now : null),
        lastUsedAt: Value(isInstalled ? now : null),
      ),
    );
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
          .write(const LanguagePacksCompanion(
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
}