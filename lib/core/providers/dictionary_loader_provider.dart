// Dictionary Loader Provider
// Riverpod provider for dictionary loading service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/providers/database_provider.dart';
import 'package:polyread/core/services/dictionary_loader_service.dart';

final dictionaryLoaderProvider = Provider<DictionaryLoaderService>((ref) {
  final database = ref.watch(databaseProvider);
  return DictionaryLoaderService(database);
});

/// Provider for dictionary initialization state
final dictionaryInitializationProvider = FutureProvider<void>((ref) async {
  // No automatic dictionary loading - users must download real dictionaries
  return;
});

/// Provider for dictionary statistics
final dictionaryStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final loaderService = ref.watch(dictionaryLoaderProvider);
  return await loaderService.getDictionaryStats();
});