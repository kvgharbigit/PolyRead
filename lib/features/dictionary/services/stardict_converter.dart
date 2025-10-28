// StarDict to SQLite Converter
// Advanced dictionary processing for converting StarDict format to optimized SQLite

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
// import 'package:crypto/crypto.dart'; // TODO: Use for validation if needed

class StarDictConverter {
  static const String _dictionaryTableSchema = '''
    CREATE TABLE IF NOT EXISTS dictionary_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT NOT NULL,
      word_lower TEXT NOT NULL,
      definition TEXT NOT NULL,
      pronunciation TEXT,
      part_of_speech TEXT,
      examples TEXT,
      synonyms TEXT,
      etymology TEXT,
      frequency_rank INTEGER,
      source_dict TEXT,
      created_at INTEGER NOT NULL,
      UNIQUE(word_lower, source_dict)
    )
  ''';

  static const String _ftsTableSchema = '''
    CREATE VIRTUAL TABLE IF NOT EXISTS dictionary_fts USING fts5(
      word,
      word_lower,
      definition,
      synonyms,
      content='dictionary_entries',
      content_rowid='id'
    )
  ''';

  static const String _metadataTableSchema = '''
    CREATE TABLE IF NOT EXISTS dictionary_metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const String _indexesSchema = '''
    CREATE INDEX IF NOT EXISTS idx_word_lower ON dictionary_entries(word_lower);
    CREATE INDEX IF NOT EXISTS idx_frequency ON dictionary_entries(frequency_rank);
    CREATE INDEX IF NOT EXISTS idx_pos ON dictionary_entries(part_of_speech);
  ''';

  Future<ConversionResult> convertStarDict({
    required String stardictPath,
    required String outputPath,
    required String dictionaryName,
    String sourceLanguage = 'en',
    String targetLanguage = 'es',
    bool enableFullTextSearch = true,
    bool calculateFrequency = true,
    Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ConversionResult(
      dictionaryName: dictionaryName,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    try {
      onProgress?.call(0.0, 'Validating StarDict files...');
      
      // Validate StarDict files
      final stardictFiles = await _validateStarDictFiles(stardictPath);
      result.inputFiles = stardictFiles.values.map((f) => path.basename(f.path)).toList();

      onProgress?.call(0.1, 'Reading dictionary metadata...');
      
      // Read IFO file for metadata
      final metadata = await _readIfoFile(stardictFiles['ifo']!);
      result.metadata = metadata;

      onProgress?.call(0.2, 'Parsing dictionary index...');
      
      // Parse IDX file for word index
      final wordIndex = await _parseIdxFile(stardictFiles['idx']!);
      result.totalEntries = wordIndex.length;

      onProgress?.call(0.3, 'Creating SQLite database...');
      
      // Create and setup database
      final db = await _createDatabase(outputPath);
      
      onProgress?.call(0.4, 'Converting dictionary entries...');
      
      // Convert dictionary data
      final conversionStats = await _convertDictionaryData(
        db: db,
        dictFile: stardictFiles['dict']!,
        synFile: stardictFiles['syn'],
        wordIndex: wordIndex,
        metadata: metadata,
        dictionaryName: dictionaryName,
        enableFrequency: calculateFrequency,
        onProgress: (progress) {
          onProgress?.call(0.4 + (progress * 0.5), 'Converting entries...');
        },
      );

      result.successfulEntries = conversionStats.successfulEntries;
      result.failedEntries = conversionStats.failedEntries;
      result.duplicateEntries = conversionStats.duplicateEntries;

      if (enableFullTextSearch) {
        onProgress?.call(0.9, 'Building full-text search index...');
        await _buildFtsIndex(db);
      }

      onProgress?.call(0.95, 'Finalizing database...');
      
      // Store metadata and finalize
      await _storeMetadata(db, metadata, result);
      await _optimizeDatabase(db);
      await db.close();

      stopwatch.stop();
      result.conversionTimeMs = stopwatch.elapsedMilliseconds;
      result.isSuccess = true;
      result.outputFilePath = outputPath;

      onProgress?.call(1.0, 'Conversion completed successfully!');

    } catch (e, stackTrace) {
      result.isSuccess = false;
      result.errorMessage = e.toString();
      result.stackTrace = stackTrace.toString();
      
      // Clean up partial database on error
      try {
        final file = File(outputPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      
      onProgress?.call(0.0, 'Conversion failed: ${e.toString()}');
    }

    return result;
  }

  Future<Map<String, File>> _validateStarDictFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw Exception('StarDict directory does not exist: $directoryPath');
    }

    final files = <String, File>{};
    
    await for (final entity in directory.list()) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        final baseName = path.basenameWithoutExtension(entity.path);
        
        switch (extension) {
          case '.ifo':
            files['ifo'] = entity;
            break;
          case '.idx':
            files['idx'] = entity;
            break;
          case '.dict':
            files['dict'] = entity;
            break;
          case '.syn':
            files['syn'] = entity;
            break;
        }
      }
    }

    // Validate required files
    if (!files.containsKey('ifo')) {
      throw Exception('Missing required .ifo file');
    }
    if (!files.containsKey('idx')) {
      throw Exception('Missing required .idx file');
    }
    if (!files.containsKey('dict')) {
      throw Exception('Missing required .dict file');
    }

    return files;
  }

  Future<Map<String, String>> _readIfoFile(File ifoFile) async {
    final metadata = <String, String>{};
    final lines = await ifoFile.readAsLines();

    for (final line in lines) {
      if (line.contains('=')) {
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          metadata[key] = value;
        }
      }
    }

    // Validate required metadata
    if (!metadata.containsKey('wordcount')) {
      throw Exception('Missing wordcount in .ifo file');
    }
    if (!metadata.containsKey('idxfilesize')) {
      throw Exception('Missing idxfilesize in .ifo file');
    }

    return metadata;
  }

  Future<List<StarDictIndexEntry>> _parseIdxFile(File idxFile) async {
    final bytes = await idxFile.readAsBytes();
    final entries = <StarDictIndexEntry>[];
    
    int offset = 0;
    while (offset < bytes.length) {
      // Read word (null-terminated string)
      final wordBytes = <int>[];
      while (offset < bytes.length && bytes[offset] != 0) {
        wordBytes.add(bytes[offset]);
        offset++;
      }
      
      if (wordBytes.isEmpty) break;
      
      // Skip null terminator
      offset++;
      
      if (offset + 8 > bytes.length) break;
      
      // Read data offset (4 bytes, big-endian)
      final dataOffset = ByteData.sublistView(bytes, offset, offset + 4)
          .getUint32(0, Endian.big);
      offset += 4;
      
      // Read data size (4 bytes, big-endian)
      final dataSize = ByteData.sublistView(bytes, offset, offset + 4)
          .getUint32(0, Endian.big);
      offset += 4;
      
      final word = utf8.decode(wordBytes);
      entries.add(StarDictIndexEntry(
        word: word,
        dataOffset: dataOffset,
        dataSize: dataSize,
      ));
    }

    return entries;
  }

  Future<Database> _createDatabase(String outputPath) async {
    // Ensure directory exists
    final directory = Directory(path.dirname(outputPath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Delete existing database
    final file = File(outputPath);
    if (await file.exists()) {
      await file.delete();
    }

    final db = await openDatabase(
      outputPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(_dictionaryTableSchema);
        await db.execute(_metadataTableSchema);
        await db.execute(_ftsTableSchema);
        await db.execute(_indexesSchema);
      },
    );

    return db;
  }

  Future<ConversionStats> _convertDictionaryData({
    required Database db,
    required File dictFile,
    File? synFile,
    required List<StarDictIndexEntry> wordIndex,
    required Map<String, String> metadata,
    required String dictionaryName,
    bool enableFrequency = true,
    Function(double progress)? onProgress,
  }) async {
    final stats = ConversionStats();
    final dictBytes = await dictFile.readAsBytes();
    
    // Read synonym data if available
    Map<String, String>? synonyms;
    if (synFile != null) {
      synonyms = await _parseSynFile(synFile);
    }

    // Calculate frequency ranks if enabled
    Map<String, int>? frequencyRanks;
    if (enableFrequency) {
      frequencyRanks = _calculateFrequencyRanks(wordIndex);
    }

    await db.transaction((txn) async {
      for (int i = 0; i < wordIndex.length; i++) {
        final entry = wordIndex[i];
        
        try {
          // Extract definition from dict file
          final definition = _extractDefinition(
            dictBytes,
            entry.dataOffset,
            entry.dataSize,
            metadata,
          );

          if (definition.isEmpty) {
            stats.failedEntries++;
            continue;
          }

          // Parse definition components
          final parsedDef = _parseDefinition(definition);
          
          // Get synonyms for this word
          final wordSynonyms = synonyms?[entry.word.toLowerCase()] ?? '';
          
          // Get frequency rank
          final frequencyRank = frequencyRanks?[entry.word.toLowerCase()];

          // Insert into database
          await txn.insert(
            'dictionary_entries',
            {
              'word': entry.word,
              'word_lower': entry.word.toLowerCase(),
              'definition': parsedDef.definition,
              'pronunciation': parsedDef.pronunciation,
              'part_of_speech': parsedDef.partOfSpeech,
              'examples': parsedDef.examples.join('\n'),
              'synonyms': wordSynonyms,
              'etymology': parsedDef.etymology,
              'frequency_rank': frequencyRank,
              'source_dict': dictionaryName,
              'created_at': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          stats.successfulEntries++;
          
        } catch (e) {
          stats.failedEntries++;
          print('Failed to process word "${entry.word}": $e');
        }

        // Report progress
        if (i % 100 == 0) {
          onProgress?.call(i / wordIndex.length);
        }
      }
    });

    return stats;
  }

  String _extractDefinition(
    Uint8List dictBytes,
    int offset,
    int size,
    Map<String, String> metadata,
  ) {
    if (offset + size > dictBytes.length) {
      return '';
    }

    final dataBytes = dictBytes.sublist(offset, offset + size);
    
    // Handle different data types based on sametypesequence
    final sameTypeSequence = metadata['sametypesequence'] ?? 'm';
    
    if (sameTypeSequence == 'm') {
      // Plain text definition
      return utf8.decode(dataBytes, allowMalformed: true);
    } else if (sameTypeSequence == 'h') {
      // HTML definition
      return utf8.decode(dataBytes, allowMalformed: true);
    } else {
      // Handle other formats or multiple data types
      return _parseMultiTypeData(dataBytes, sameTypeSequence);
    }
  }

  String _parseMultiTypeData(Uint8List dataBytes, String typeSequence) {
    // Simplified parser for multi-type data
    // In production, implement full StarDict type parsing
    
    final result = StringBuffer();
    int offset = 0;
    
    for (final typeChar in typeSequence.split('')) {
      if (offset >= dataBytes.length) break;
      
      switch (typeChar) {
        case 'm': // Plain text
          final text = utf8.decode(dataBytes.sublist(offset), allowMalformed: true);
          result.write(text);
          offset = dataBytes.length; // Consume rest
          break;
          
        case 'h': // HTML
          final html = utf8.decode(dataBytes.sublist(offset), allowMalformed: true);
          result.write(_stripHtml(html));
          offset = dataBytes.length; // Consume rest
          break;
          
        case 't': // Phonetic string
          // Find null terminator
          final endIndex = dataBytes.indexOf(0, offset);
          if (endIndex != -1) {
            final phonetic = utf8.decode(dataBytes.sublist(offset, endIndex));
            result.write('[$phonetic] ');
            offset = endIndex + 1;
          }
          break;
          
        default:
          // Skip unknown types
          break;
      }
    }
    
    return result.toString();
  }

  String _stripHtml(String html) {
    // Simple HTML tag removal
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  ParsedDefinition _parseDefinition(String definition) {
    final parsed = ParsedDefinition();
    
    // Extract pronunciation (typically in brackets or slashes)
    final pronunciationRegex = RegExp(r'[\[/]([^[\]/]+)[\]/]');
    final pronunciationMatch = pronunciationRegex.firstMatch(definition);
    if (pronunciationMatch != null) {
      parsed.pronunciation = pronunciationMatch.group(1);
    }

    // Extract part of speech (typically abbreviated at the beginning)
    final posRegex = RegExp(r'\b(n\.|v\.|adj\.|adv\.|prep\.|conj\.|int\.)\b');
    final posMatch = posRegex.firstMatch(definition);
    if (posMatch != null) {
      parsed.partOfSpeech = _expandPartOfSpeech(posMatch.group(1)!);
    }

    // Extract examples (typically after "e.g." or in quotes)
    final exampleRegex = RegExp(r'(?:e\.g\.|example:)\s*([^.]+)');
    final exampleMatches = exampleRegex.allMatches(definition);
    for (final match in exampleMatches) {
      parsed.examples.add(match.group(1)?.trim() ?? '');
    }

    // Clean definition text
    String cleanDef = definition
        .replaceAll(pronunciationRegex, '')
        .replaceAll(posRegex, '')
        .replaceAll(exampleRegex, '')
        .trim();
    
    parsed.definition = cleanDef;
    
    return parsed;
  }

  String _expandPartOfSpeech(String abbrev) {
    switch (abbrev) {
      case 'n.': return 'noun';
      case 'v.': return 'verb';
      case 'adj.': return 'adjective';
      case 'adv.': return 'adverb';
      case 'prep.': return 'preposition';
      case 'conj.': return 'conjunction';
      case 'int.': return 'interjection';
      default: return abbrev;
    }
  }

  Future<Map<String, String>> _parseSynFile(File synFile) async {
    final synonyms = <String, String>{};
    final bytes = await synFile.readAsBytes();
    
    int offset = 0;
    while (offset < bytes.length) {
      // Read synonym word
      final wordBytes = <int>[];
      while (offset < bytes.length && bytes[offset] != 0) {
        wordBytes.add(bytes[offset]);
        offset++;
      }
      
      if (wordBytes.isEmpty) break;
      offset++; // Skip null terminator
      
      if (offset + 4 > bytes.length) break;
      
      // Read original word index
      final originalIndex = ByteData.sublistView(bytes, offset, offset + 4)
          .getUint32(0, Endian.big);
      offset += 4;
      
      final synonymWord = utf8.decode(wordBytes);
      synonyms[synonymWord.toLowerCase()] = synonymWord;
    }
    
    return synonyms;
  }

  Map<String, int> _calculateFrequencyRanks(List<StarDictIndexEntry> entries) {
    // Simple frequency calculation based on word length and common patterns
    final frequencyMap = <String, int>{};
    
    for (int i = 0; i < entries.length; i++) {
      final word = entries[i].word.toLowerCase();
      
      // Assign frequency rank based on heuristics
      int rank = i + 1; // Default to index-based rank
      
      // Boost common short words
      if (word.length <= 3) {
        rank = (rank * 0.1).round();
      } else if (word.length <= 5) {
        rank = (rank * 0.5).round();
      }
      
      // Boost words without special characters
      if (RegExp(r'^[a-z]+$').hasMatch(word)) {
        rank = (rank * 0.8).round();
      }
      
      frequencyMap[word] = rank;
    }
    
    return frequencyMap;
  }

  Future<void> _buildFtsIndex(Database db) async {
    await db.execute('''
      INSERT INTO dictionary_fts(dictionary_fts) VALUES('rebuild')
    ''');
  }

  Future<void> _storeMetadata(
    Database db,
    Map<String, String> metadata,
    ConversionResult result,
  ) async {
    await db.insert('dictionary_metadata', {
      'key': 'dictionary_name',
      'value': result.dictionaryName,
    });
    
    await db.insert('dictionary_metadata', {
      'key': 'source_language',
      'value': result.sourceLanguage,
    });
    
    await db.insert('dictionary_metadata', {
      'key': 'target_language',
      'value': result.targetLanguage,
    });
    
    await db.insert('dictionary_metadata', {
      'key': 'total_entries',
      'value': result.totalEntries.toString(),
    });
    
    await db.insert('dictionary_metadata', {
      'key': 'successful_entries',
      'value': result.successfulEntries.toString(),
    });
    
    await db.insert('dictionary_metadata', {
      'key': 'conversion_time_ms',
      'value': result.conversionTimeMs.toString(),
    });
    
    await db.insert('dictionary_metadata', {
      'key': 'created_at',
      'value': DateTime.now().toIso8601String(),
    });

    // Store original StarDict metadata
    for (final entry in metadata.entries) {
      await db.insert('dictionary_metadata', {
        'key': 'stardict_${entry.key}',
        'value': entry.value,
      });
    }
  }

  Future<void> _optimizeDatabase(Database db) async {
    await db.execute('ANALYZE');
    await db.execute('VACUUM');
  }
}

// Data classes
class StarDictIndexEntry {
  final String word;
  final int dataOffset;
  final int dataSize;

  StarDictIndexEntry({
    required this.word,
    required this.dataOffset,
    required this.dataSize,
  });
}

class ParsedDefinition {
  String definition = '';
  String? pronunciation;
  String? partOfSpeech;
  List<String> examples = [];
  String? etymology;
}

class ConversionStats {
  int successfulEntries = 0;
  int failedEntries = 0;
  int duplicateEntries = 0;
}

class ConversionResult {
  final String dictionaryName;
  final String sourceLanguage;
  final String targetLanguage;
  
  bool isSuccess = false;
  String? errorMessage;
  String? stackTrace;
  String? outputFilePath;
  
  List<String> inputFiles = [];
  Map<String, String> metadata = {};
  int totalEntries = 0;
  int successfulEntries = 0;
  int failedEntries = 0;
  int duplicateEntries = 0;
  int conversionTimeMs = 0;

  ConversionResult({
    required this.dictionaryName,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  double get successRate => totalEntries > 0 ? successfulEntries / totalEntries : 0.0;
  
  Map<String, dynamic> toJson() {
    return {
      'dictionaryName': dictionaryName,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
      'outputFilePath': outputFilePath,
      'inputFiles': inputFiles,
      'metadata': metadata,
      'totalEntries': totalEntries,
      'successfulEntries': successfulEntries,
      'failedEntries': failedEntries,
      'duplicateEntries': duplicateEntries,
      'conversionTimeMs': conversionTimeMs,
      'successRate': successRate,
    };
  }
}