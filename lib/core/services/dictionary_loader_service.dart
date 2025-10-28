// Dictionary Loader Service
// Loads dictionary data into the database for translation lookups

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/services/error_service.dart';

class DictionaryLoaderService {
  final AppDatabase _database;
  
  DictionaryLoaderService(this._database);
  
  /// Load sample dictionary data for testing
  Future<void> loadSampleDictionary() async {
    try {
      // Check if dictionary data already exists
      final existingCount = await (_database.select(_database.dictionaryEntries)
          ..limit(1)).get();
      
      if (existingCount.isNotEmpty) {
        print('Dictionary data already loaded');
        return;
      }
      
      // Sample English-Spanish dictionary entries
      final sampleEntries = _generateSampleDictionary();
      
      // Insert in batches for better performance
      const batchSize = 100;
      for (int i = 0; i < sampleEntries.length; i += batchSize) {
        final batch = sampleEntries.sublist(
          i,
          (i + batchSize).clamp(0, sampleEntries.length),
        );
        
        await _database.batch((batch) {
          for (final entry in sampleEntries) {
            batch.insert(_database.dictionaryEntries, entry);
          }
        });
      }
      
      print('Loaded ${sampleEntries.length} dictionary entries');
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to load dictionary data',
        details: e.toString(),
      );
      rethrow;
    }
  }
  
  /// Generate sample dictionary entries for testing
  List<DictionaryEntriesCompanion> _generateSampleDictionary() {
    final entries = <DictionaryEntriesCompanion>[];
    
    // English-Spanish basic vocabulary
    final basicVocab = {
      'hello': {
        'definition': 'hola',
        'pos': 'interjection',
        'examples': ['Hello, how are you?', 'She said hello to everyone.'],
        'synonyms': ['hi', 'greetings'],
      },
      'world': {
        'definition': 'mundo',
        'pos': 'noun',
        'examples': ['The world is beautiful.', 'Travel around the world.'],
        'synonyms': ['earth', 'globe', 'planet'],
      },
      'book': {
        'definition': 'libro',
        'pos': 'noun',
        'examples': ['I am reading a book.', 'This book is interesting.'],
        'synonyms': ['novel', 'text', 'publication'],
      },
      'read': {
        'definition': 'leer',
        'pos': 'verb',
        'examples': ['I like to read.', 'Can you read this?'],
        'synonyms': ['peruse', 'study', 'browse'],
      },
      'language': {
        'definition': 'idioma, lengua',
        'pos': 'noun',
        'examples': ['Spanish is a beautiful language.', 'Learn a new language.'],
        'synonyms': ['tongue', 'dialect', 'speech'],
      },
      'learning': {
        'definition': 'aprendizaje',
        'pos': 'noun',
        'examples': ['Learning is fun.', 'The learning process takes time.'],
        'synonyms': ['education', 'study', 'training'],
      },
      'house': {
        'definition': 'casa',
        'pos': 'noun',
        'examples': ['My house is big.', 'Welcome to our house.'],
        'synonyms': ['home', 'residence', 'dwelling'],
      },
      'water': {
        'definition': 'agua',
        'pos': 'noun',
        'examples': ['Drink water every day.', 'The water is clean.'],
        'synonyms': ['liquid', 'H2O'],
      },
      'food': {
        'definition': 'comida',
        'pos': 'noun',
        'examples': ['The food is delicious.', 'Healthy food is important.'],
        'synonyms': ['meal', 'nourishment', 'cuisine'],
      },
      'time': {
        'definition': 'tiempo',
        'pos': 'noun',
        'examples': ['What time is it?', 'Time flies quickly.'],
        'synonyms': ['moment', 'period', 'duration'],
      },
      'good': {
        'definition': 'bueno',
        'pos': 'adjective',
        'examples': ['This is good.', 'Have a good day.'],
        'synonyms': ['excellent', 'great', 'fine'],
      },
      'bad': {
        'definition': 'malo',
        'pos': 'adjective',
        'examples': ['That is bad.', 'Bad weather today.'],
        'synonyms': ['poor', 'awful', 'terrible'],
      },
      'big': {
        'definition': 'grande',
        'pos': 'adjective',
        'examples': ['A big house.', 'The elephant is big.'],
        'synonyms': ['large', 'huge', 'enormous'],
      },
      'small': {
        'definition': 'pequeño',
        'pos': 'adjective',
        'examples': ['A small car.', 'The mouse is small.'],
        'synonyms': ['little', 'tiny', 'minute'],
      },
      'love': {
        'definition': 'amor',
        'pos': 'noun',
        'examples': ['Love is beautiful.', 'I love reading.'],
        'synonyms': ['affection', 'adoration', 'devotion'],
      },
      'work': {
        'definition': 'trabajo',
        'pos': 'noun',
        'examples': ['I go to work.', 'Work is important.'],
        'synonyms': ['job', 'employment', 'labor'],
      },
      'school': {
        'definition': 'escuela',
        'pos': 'noun',
        'examples': ['Children go to school.', 'The school is nearby.'],
        'synonyms': ['academy', 'institution', 'college'],
      },
      'friend': {
        'definition': 'amigo',
        'pos': 'noun',
        'examples': ['He is my friend.', 'Friends are important.'],
        'synonyms': ['companion', 'buddy', 'pal'],
      },
      'family': {
        'definition': 'familia',
        'pos': 'noun',
        'examples': ['I love my family.', 'Family comes first.'],
        'synonyms': ['relatives', 'kin', 'household'],
      },
      'computer': {
        'definition': 'computadora',
        'pos': 'noun',
        'examples': ['I use a computer.', 'The computer is fast.'],
        'synonyms': ['PC', 'laptop', 'machine'],
      },
      'phone': {
        'definition': 'teléfono',
        'pos': 'noun',
        'examples': ['Answer the phone.', 'My phone is ringing.'],
        'synonyms': ['telephone', 'mobile', 'cell'],
      },
    };
    
    // Create dictionary entries
    for (final entry in basicVocab.entries) {
      final word = entry.key;
      final data = entry.value;
      
      entries.add(DictionaryEntriesCompanion.insert(
        lemma: word,
        definition: data['definition'] as String,
        partOfSpeech: Value(data['pos'] as String),
        languagePair: 'en-es',
        frequency: Value(word.length < 5 ? 1000 : 500), // Simple frequency heuristic
        examples: Value(jsonEncode(data['examples'])),
        synonyms: Value(jsonEncode(data['synonyms'])),
        source: const Value('PolyRead Sample Dictionary'),
      ));
    }
    
    // Add reverse dictionary (Spanish-English)
    for (final entry in basicVocab.entries) {
      final englishWord = entry.key;
      final spanishDefinition = entry.value['definition'] as String;
      final pos = entry.value['pos'] as String;
      
      // Handle multiple Spanish translations
      final spanishWords = spanishDefinition.split(', ');
      for (final spanishWord in spanishWords) {
        entries.add(DictionaryEntriesCompanion.insert(
          lemma: spanishWord,
          definition: englishWord,
          partOfSpeech: Value(pos),
          languagePair: 'es-en',
          frequency: Value(spanishWord.length < 5 ? 1000 : 500),
          examples: Value(jsonEncode(['Ejemplo: $spanishWord.'])),
          synonyms: Value(jsonEncode([])),
          source: const Value('PolyRead Sample Dictionary'),
        ));
      }
    }
    
    return entries;
  }
  
  /// Load dictionary from JSON file (for future language pack integration)
  Future<void> loadDictionaryFromJson(String jsonPath, String languagePair) async {
    try {
      // This would read from language pack files
      // Implementation depends on language pack format
      print('Loading dictionary from $jsonPath for $languagePair');
      // TODO: Implement JSON dictionary loading
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to load dictionary from JSON',
        details: e.toString(),
      );
      rethrow;
    }
  }
  
  /// Clear all dictionary data
  Future<void> clearDictionary() async {
    try {
      await _database.delete(_database.dictionaryEntries).go();
      print('Dictionary data cleared');
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to clear dictionary data',
        details: e.toString(),
      );
      rethrow;
    }
  }
  
  /// Get dictionary statistics
  Future<Map<String, int>> getDictionaryStats() async {
    try {
      final totalEntries = await (_database.selectOnly(_database.dictionaryEntries)
          ..addColumns([_database.dictionaryEntries.id.count()]))
          .getSingle();
      
      final languagePairs = await (_database.selectOnly(_database.dictionaryEntries)
          ..addColumns([_database.dictionaryEntries.languagePair])
          ..groupBy([_database.dictionaryEntries.languagePair]))
          .get();
      
      return {
        'totalEntries': totalEntries.read(_database.dictionaryEntries.id.count()) ?? 0,
        'languagePairs': languagePairs.length,
      };
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to get dictionary statistics',
        details: e.toString(),
      );
      return {'totalEntries': 0, 'languagePairs': 0};
    }
  }
}