// Reader Translation Provider
// Riverpod provider for the reader translation service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/reader/services/reader_translation_service.dart';
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/cycling_dictionary_service.dart';
import 'package:polyread/features/vocabulary/providers/vocabulary_provider.dart';
import 'package:polyread/core/providers/database_provider.dart';

// Cycling dictionary service
final cyclingDictionaryServiceProvider = Provider<CyclingDictionaryService>((ref) {
  final database = ref.watch(databaseProvider);
  return CyclingDictionaryService(database);
});

final translationCacheServiceProvider = Provider<NoOpCacheService>((ref) {
  // TODO: Implement proper cache service integration with Drift
  // For now, use a no-op implementation to avoid database compatibility issues
  return NoOpCacheService();
});

final translationServiceProvider = Provider<TranslationService>((ref) {
  final dictionaryService = ref.watch(cyclingDictionaryServiceProvider);
  final cacheService = ref.watch(translationCacheServiceProvider);
  
  return TranslationService(
    dictionaryService: dictionaryService,
    cacheService: cacheService,
  );
});

// Vocabulary service temporarily disabled - type mismatch with database
// final vocabularyServiceProvider = Provider<VocabularyService>((ref) {
//   final database = ref.watch(databaseProvider);
//   return VocabularyService(database);
// });

// Main reader translation service provider
final readerTranslationServiceProvider = ChangeNotifierProvider<ReaderTranslationService>((ref) {
  final translationService = ref.watch(translationServiceProvider);
  final vocabularyService = ref.watch(vocabularyServiceProvider);
  final database = ref.watch(databaseProvider);

  final service = ReaderTranslationService(
    translationService: translationService,
    vocabularyService: vocabularyService,
    database: database,
  );

  // Initialize the service
  service.initialize();

  return service;
});

// Temporary no-op cache service until proper Drift integration
class NoOpCacheService {
  Future<void> initialize() async {}
  Future<dynamic> getCachedTranslation(dynamic request) async => null;
  Future<void> cacheTranslation(dynamic request, dynamic response) async {}
  Future<void> clearCache() async {}
  Future<void> dispose() async {}
  Future<dynamic> getStats() async => {
    'totalEntries': 0,
    'totalSize': 0,
    'oldestEntry': null,
    'newestEntry': null,
  };
}

