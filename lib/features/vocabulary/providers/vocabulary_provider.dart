// Vocabulary Provider - Riverpod provider for vocabulary service
// Connects vocabulary functionality to the cycling dictionary system

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/vocabulary/services/drift_vocabulary_service.dart';
import 'package:polyread/core/providers/database_provider.dart';

/// Vocabulary Service Provider
/// Creates and manages the vocabulary service with cycling dictionary integration
final vocabularyServiceProvider = Provider<DriftVocabularyService>((ref) {
  final database = ref.watch(databaseProvider);
  return DriftVocabularyService(database);
});