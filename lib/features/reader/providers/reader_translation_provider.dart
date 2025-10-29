// Reader Translation Provider
// Riverpod provider for the reader translation service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/reader/services/reader_translation_service.dart';
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/drift_dictionary_service.dart';
import 'package:polyread/features/translation/services/translation_cache_service.dart';
import 'package:polyread/features/vocabulary/services/vocabulary_service.dart';
import 'package:polyread/core/providers/database_provider.dart';

// Translation service dependencies
final dictionaryServiceProvider = Provider<DriftDictionaryService>((ref) {
  final database = ref.watch(databaseProvider);
  return DriftDictionaryService(database);
});

final translationCacheServiceProvider = Provider<TranslationCacheService>((ref) {
  // For now, return a mock implementation
  // TODO: Implement proper cache service
  return MockTranslationCacheService();
});

final translationServiceProvider = Provider<TranslationService>((ref) {
  final dictionaryService = ref.watch(dictionaryServiceProvider);
  final cacheService = ref.watch(translationCacheServiceProvider);
  
  return TranslationService(
    dictionaryService: dictionaryService,
    cacheService: cacheService,
  );
});

final vocabularyServiceProvider = Provider<VocabularyService>((ref) {
  final database = ref.watch(databaseProvider);
  return VocabularyService(database);
});

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

// Mock cache service for now
class MockTranslationCacheService implements TranslationCacheService {
  @override
  Future<void> initialize() async {}

  @override
  Future<dynamic> getCachedTranslation(dynamic request) async {
    return null; // No caching for now
  }

  @override
  Future<void> cacheTranslation(dynamic request, dynamic response) async {
    // No-op for now
  }

  @override
  Future<void> clearCache() async {}
}