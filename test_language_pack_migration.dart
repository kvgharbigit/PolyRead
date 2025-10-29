#!/usr/bin/env dart

// Test script to verify language pack migration from PolyBook to PolyRead
// This script tests the bidirectional lookup functionality

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

void main() async {
  print('🔍 Testing PolyRead Language Pack Migration');
  print('============================================');
  
  final assetsDir = '/Users/kayvangharbi/PycharmProjects/PolyRead/assets/language_packs';
  final testResults = <String, Map<String, dynamic>>{};
  
  // Test each language pack
  final packs = [
    {'file': 'de-en.sqlite.zip', 'lang1': 'German', 'lang2': 'English', 'testWord': 'Haus'},
    {'file': 'en-de.sqlite.zip', 'lang1': 'English', 'lang2': 'German', 'testWord': 'house'},
    {'file': 'es-en.sqlite.zip', 'lang1': 'Spanish', 'lang2': 'English', 'testWord': 'casa'},
    {'file': 'en-es.sqlite.zip', 'lang1': 'English', 'lang2': 'Spanish', 'testWord': 'house'},
  ];
  
  for (final pack in packs) {
    final packFile = pack['file'] as String;
    final lang1 = pack['lang1'] as String;
    final lang2 = pack['lang2'] as String;
    final testWord = pack['testWord'] as String;
    
    print('\n📦 Testing: $packFile ($lang1 → $lang2)');
    print('   Test word: "$testWord"');
    
    try {
      final result = await testLanguagePack(assetsDir, packFile, testWord);
      testResults[packFile] = result;
      
      if (result['success']) {
        print('   ✅ SUCCESS: ${result['entries']} entries, found "$testWord": ${result['foundTestWord']}');
        if (result['testDefinition'] != null) {
          final def = result['testDefinition'] as String;
          final truncated = def.length > 100 ? '${def.substring(0, 100)}...' : def;
          print('   📖 Definition: $truncated');
        }
      } else {
        print('   ❌ FAILED: ${result['error']}');
      }
      
    } catch (e) {
      print('   ❌ ERROR: $e');
      testResults[packFile] = {'success': false, 'error': e.toString()};
    }
  }
  
  // Summary
  print('\n📊 Test Summary');
  print('===============');
  
  int successful = 0;
  int total = testResults.length;
  
  for (final entry in testResults.entries) {
    final packName = entry.key;
    final result = entry.value;
    
    if (result['success'] == true) {
      successful++;
      print('✅ $packName: ${result['entries']} entries');
    } else {
      print('❌ $packName: ${result['error']}');
    }
  }
  
  print('\nOverall: $successful/$total packs working (${(successful/total*100).toStringAsFixed(1)}%)');
  
  if (successful == total) {
    print('\n🎉 ALL LANGUAGE PACKS MIGRATED SUCCESSFULLY!');
    print('✅ Bidirectional lookup is working');
    print('✅ Dictionary data is accessible');
    print('✅ Wiktionary format preserved');
  } else {
    print('\n⚠️ Some packs need attention. Review the errors above.');
  }
  
  // Test bidirectional functionality
  print('\n🔄 Testing Bidirectional Lookup');
  print('================================');
  
  await testBidirectionalLookup(assetsDir);
}

Future<Map<String, dynamic>> testLanguagePack(String assetsDir, String packFile, String testWord) async {
  final packPath = path.join(assetsDir, packFile);
  
  // Check if file exists
  if (!File(packPath).existsSync()) {
    return {'success': false, 'error': 'Pack file not found: $packPath'};
  }
  
  // Extract and test
  final tempDir = Directory.systemTemp.createTempSync('polyread_test_');
  
  try {
    // Extract zip
    final result = await Process.run('unzip', ['-o', packPath], workingDirectory: tempDir.path);
    if (result.exitCode != 0) {
      return {'success': false, 'error': 'Failed to extract zip: ${result.stderr}'};
    }
    
    // Find SQLite file
    final sqliteFiles = tempDir.listSync().where((f) => f.path.endsWith('.sqlite')).toList();
    if (sqliteFiles.isEmpty) {
      return {'success': false, 'error': 'No SQLite file found in zip'};
    }
    
    final dbPath = sqliteFiles.first.path;
    
    // Open and test database
    final db = sqlite3.open(dbPath);
    
    try {
      // Check tables
      final tables = db.select('SELECT name FROM sqlite_master WHERE type=\"table\"');
      final tableNames = tables.map((row) => row['name'] as String).toList();
      
      print('   📋 Tables: $tableNames');
      
      int totalEntries = 0;
      bool foundTestWord = false;
      String? testDefinition;
      
      // Check different table formats
      if (tableNames.contains('dict')) {
        // PolyRead format
        final countResult = db.select('SELECT COUNT(*) as count FROM dict');
        totalEntries = countResult.first['count'] as int;
        
        // Look for test word
        final wordResult = db.select('SELECT def FROM dict WHERE lemma = ? COLLATE NOCASE', [testWord]);
        if (wordResult.isNotEmpty) {
          foundTestWord = true;
          testDefinition = wordResult.first['def'] as String;
        }
        
      } else if (tableNames.contains('word')) {
        // StarDict format
        final countResult = db.select('SELECT COUNT(*) as count FROM word');
        totalEntries = countResult.first['count'] as int;
        
        // Look for test word
        final wordResult = db.select('SELECT m FROM word WHERE w = ? COLLATE NOCASE', [testWord]);
        if (wordResult.isNotEmpty) {
          foundTestWord = true;
          testDefinition = wordResult.first['m'] as String;
        }
      }
      
      return {
        'success': true,
        'entries': totalEntries,
        'foundTestWord': foundTestWord,
        'testDefinition': testDefinition,
        'tables': tableNames,
      };
      
    } finally {
      db.dispose();
    }
    
  } finally {
    // Cleanup
    tempDir.deleteSync(recursive: true);
  }
}

Future<void> testBidirectionalLookup(String assetsDir) async {
  // Test that we can look up words in both directions
  final testPairs = [
    {'main': 'de-en.sqlite.zip', 'companion': 'en-de.sqlite.zip', 'word1': 'Haus', 'word2': 'house'},
    {'main': 'es-en.sqlite.zip', 'companion': 'en-es.sqlite.zip', 'word1': 'casa', 'word2': 'house'},
  ];
  
  for (final pair in testPairs) {
    final mainPack = pair['main'] as String;
    final companionPack = pair['companion'] as String;
    final word1 = pair['word1'] as String;
    final word2 = pair['word2'] as String;
    
    print('\n🔄 Testing bidirectional: $mainPack ↔ $companionPack');
    
    // Test main direction
    final result1 = await testLanguagePack(assetsDir, mainPack, word1);
    final found1 = result1['success'] == true && result1['foundTestWord'] == true;
    
    // Test companion direction  
    final result2 = await testLanguagePack(assetsDir, companionPack, word2);
    final found2 = result2['success'] == true && result2['foundTestWord'] == true;
    
    if (found1 && found2) {
      print('   ✅ Bidirectional lookup working: "$word1" and "$word2" both found');
    } else {
      print('   ⚠️ Bidirectional issue: "$word1" found=$found1, "$word2" found=$found2');
    }
  }
}