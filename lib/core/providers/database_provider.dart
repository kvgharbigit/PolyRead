// Database Provider
// Riverpod provider for database access throughout the app

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/core/database/app_database.dart';

// Database instance provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  
  // Ensure proper disposal
  ref.onDispose(() {
    database.close();
  });
  
  return database;
});

// Individual table providers for easier access
final booksProvider = Provider((ref) => ref.watch(databaseProvider).books);
final readingProgressProvider = Provider((ref) => ref.watch(databaseProvider).readingProgress);
final vocabularyItemsProvider = Provider((ref) => ref.watch(databaseProvider).vocabularyItems);
final dictionaryEntriesProvider = Provider((ref) => ref.watch(databaseProvider).dictionaryEntries);
final languagePacksProvider = Provider((ref) => ref.watch(databaseProvider).languagePacks);
final userSettingsProvider = Provider((ref) => ref.watch(databaseProvider).userSettings);