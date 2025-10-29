// Simple test to verify dictionary setup functionality
// Run this to test if the dictionary initialization works

import 'package:flutter/material.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/services/dictionary_management_service.dart';
import 'package:polyread/core/services/dictionary_loader_service.dart';
import 'package:polyread/features/translation/services/drift_dictionary_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== Dictionary Setup Test ===');
  
  try {
    // Initialize database
    print('1. Initializing database...');
    final database = AppDatabase();
    
    // Create services
    print('2. Creating services...');
    final loaderService = DictionaryLoaderService(database);
    final dictionaryService = DriftDictionaryService(database);
    final managementService = DictionaryManagementService(database);
    
    // Check initial state
    print('3. Checking initial dictionary state...');
    final initialStats = await dictionaryService.getStats();
    print('   Initial entries: ${initialStats.totalEntries}');
    
    // Test availability check
    print('4. Testing availability check...');
    final available = await managementService.isDictionaryAvailable(
      sourceLanguage: 'en',
      targetLanguage: 'es',
    );
    print('   Dictionary available: $available');
    
    // Load sample dictionary if not available
    if (!available) {
      print('5. Loading sample dictionary...');
      await loaderService.loadSampleDictionary(forceReload: true);
      
      final afterStats = await dictionaryService.getStats();
      print('   Entries after loading: ${afterStats.totalEntries}');
    }
    
    // Test lookup functionality
    print('6. Testing word lookup...');
    final testWords = ['for', 'hello', 'book', 'autobiography'];
    
    for (final word in testWords) {
      final results = await dictionaryService.lookupWord(
        word: word,
        sourceLanguage: 'en',
        targetLanguage: 'es',
      );
      print('   "$word" -> ${results.length} results found');
      if (results.isNotEmpty) {
        print('     First result: ${results.first.definition}');
      }
    }
    
    // Test health report
    print('7. Generating health report...');
    final healthReport = await managementService.getHealthReport();
    print('   Dictionary healthy: ${healthReport.isHealthy}');
    print('   Available languages: ${healthReport.availableLanguages}');
    if (healthReport.issues.isNotEmpty) {
      print('   Issues: ${healthReport.issues}');
    }
    
    print('\n=== Test Complete ===');
    print('Dictionary setup test passed successfully!');
    
  } catch (e, stackTrace) {
    print('ERROR: Dictionary setup test failed: $e');
    print('Stack trace: $stackTrace');
  }
}