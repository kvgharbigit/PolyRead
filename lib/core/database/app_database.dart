// Core Database Setup with Drift
// Handles books, reading progress, vocabulary, and dictionary data

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Book table for imported PDFs/EPUBs
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get author => text().nullable().withLength(max: 255)();
  TextColumn get filePath => text()();
  TextColumn get fileType => text()(); // 'pdf' or 'epub'
  TextColumn get language => text().withLength(min: 2, max: 10)(); // ISO language code
  IntColumn get totalPages => integer().nullable()(); // For PDFs
  IntColumn get totalChapters => integer().nullable()(); // For EPUBs
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  TextColumn get coverImagePath => text().nullable()();
  IntColumn get fileSizeBytes => integer()();
}

// Reading progress tracking
class ReadingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  
  // Position tracking (supports both PDF and EPUB)
  IntColumn get currentPage => integer().nullable()(); // For PDFs
  TextColumn get currentChapter => text().nullable()(); // For EPUBs
  TextColumn get currentPosition => text().nullable()(); // JSON position data
  
  // Progress metrics
  RealColumn get progressPercentage => real().withDefault(const Constant(0.0))();
  IntColumn get totalReadingTimeMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReadAt => dateTime().withDefault(currentDateAndTime)();
  
  // Session data
  IntColumn get wordsRead => integer().withDefault(const Constant(0))();
  IntColumn get translationsUsed => integer().withDefault(const Constant(0))();
}

// Vocabulary items created from translations
class VocabularyItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  
  // Word data
  TextColumn get sourceText => text()();
  TextColumn get translation => text()();
  TextColumn get sourceLanguage => text().withLength(min: 2, max: 10)();
  TextColumn get targetLanguage => text().withLength(min: 2, max: 10)();
  
  // Context
  TextColumn get context => text().nullable()(); // Surrounding sentence
  TextColumn get bookPosition => text().nullable()(); // Where in book this was found
  
  // SRS (Spaced Repetition System) data
  IntColumn get reviewCount => integer().withDefault(const Constant(0))();
  RealColumn get difficulty => real().withDefault(const Constant(2.5))(); // SRS difficulty
  DateTimeColumn get nextReview => dateTime().nullable()();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
  
  // Metadata
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

// Cycling Dictionary Structure for proper cycling support
// Eliminates conjugation pollution and enables discrete meaning/synonym cycling

class WordGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get baseWord => text()(); // Canonical form (e.g., "agua")
  TextColumn get wordForms => text()(); // All forms: "agua|agüita|aguas|agüitas"
  TextColumn get partOfSpeech => text().nullable()(); // "noun", "verb", "adj"
  TextColumn get sourceLanguage => text()(); // "es", "en", etc.
  TextColumn get targetLanguage => text()(); // "en", "es", etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Meanings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wordGroupId => integer().references(WordGroups, #id, onDelete: KeyAction.cascade)();
  IntColumn get meaningOrder => integer()(); // 1, 2, 3, 4... for cycling
  TextColumn get targetMeaning => text()(); // "water", "body of water", "rain", "faire", "machen"
  TextColumn get context => text().nullable()(); // "(archaic)", "(slang)", "(Guatemala)"
  TextColumn get partOfSpeech => text().nullable()(); // "noun", "verb", "adj" - preserved from original data
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))(); // Mark primary meaning
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class TargetReverseLookup extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetWord => text()(); // "water", "house", "time", "do" (target language)
  IntColumn get sourceWordGroupId => integer().references(WordGroups, #id, onDelete: KeyAction.cascade)();
  IntColumn get sourceMeaningId => integer().references(Meanings, #id, onDelete: KeyAction.cascade)();
  IntColumn get lookupOrder => integer()(); // 1, 2, 3... for cycling through source words
  IntColumn get qualityScore => integer().withDefault(const Constant(100))(); // For ranking (higher = better)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Note: FTS search will be implemented at the SQL level within the meaning-based structure

// Language pack metadata
class LanguagePacks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get packId => text().unique()(); // e.g., 'en-es-dict-v1'
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get sourceLanguage => text()();
  TextColumn get targetLanguage => text()();
  TextColumn get packType => text()(); // 'dictionary', 'translation_model', 'combined'
  TextColumn get version => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get downloadUrl => text()();
  TextColumn get checksum => text()();
  BoolColumn get isInstalled => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get installedAt => dateTime().nullable()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
}

// Bookmarks for specific positions in books
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  
  // Position data (JSON serialized ReaderPosition)
  TextColumn get position => text()(); // JSON position data for any format
  
  // Bookmark metadata
  TextColumn get title => text().nullable()(); // User-defined bookmark name
  TextColumn get note => text().nullable()(); // Optional user note
  TextColumn get excerpt => text().nullable()(); // Text excerpt from the bookmark location
  
  // Visual markers
  TextColumn get color => text().withDefault(const Constant('blue'))(); // Bookmark color
  TextColumn get icon => text().withDefault(const Constant('bookmark'))(); // Icon name
  
  // Timestamps
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAccessedAt => dateTime().nullable()();
  
  // Metadata for sorting and organization
  BoolColumn get isQuickBookmark => boolean().withDefault(const Constant(false))(); // Auto-created vs user-created
  IntColumn get sortOrder => integer().withDefault(const Constant(0))(); // For manual ordering
}

// User settings and preferences
class UserSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  TextColumn get type => text()(); // 'string', 'int', 'bool', 'double'
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Books,
  ReadingProgress,
  VocabularyItems,
  WordGroups,
  Meanings,
  TargetReverseLookup,
  LanguagePacks,
  Bookmarks,
  UserSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  // Test constructor for integration tests
  AppDatabase.forTesting(DatabaseConnection connection) : super(connection);

  @override
  int get schemaVersion => 6; // Generalized meaning-based dictionary structure

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      
      // Create FTS table for cycling dictionary search
      await m.database.customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS cycling_dictionary_fts USING fts5(
          base_word,
          word_forms,
          target_meaning,
          content='word_groups',
          content_rowid='id'
        )
      ''');
      
      // Create indexes for better performance
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_books_language ON books(language)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_books_file_type ON books(file_type)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_reading_progress_book_id ON reading_progress(book_id)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_vocabulary_book_id ON vocabulary_items(book_id)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_vocabulary_next_review ON vocabulary_items(next_review)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_word_groups_base ON word_groups(base_word)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_word_groups_forms ON word_groups(word_forms)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_word_groups_lang_pair ON word_groups(source_language, target_language)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_meanings_word_group ON meanings(word_group_id)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_meanings_order ON meanings(meaning_order)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_meanings_primary ON meanings(is_primary)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_reverse_lookup_target ON target_reverse_lookup(target_word)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_reverse_lookup_order ON target_reverse_lookup(lookup_order)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_reverse_lookup_lang_pair ON target_reverse_lookup(target_word, source_word_group_id)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_language_packs_active ON language_packs(is_active)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_bookmarks_book_id ON bookmarks(book_id)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_bookmarks_created_at ON bookmarks(created_at)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_user_settings_key ON user_settings(key)');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 6) {
        // Migration to cycling dictionary schema v6
        print('Migrating database from v$from to v$to (Cycling Dictionary System)');
        
        try {
          // Create new cycling dictionary tables
          await m.createTable($WordGroupsTable(this));
          await m.createTable($MeaningsTable(this));
          await m.createTable($TargetReverseLookupTable(this));
          
          // Add indexes for new tables
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_word_groups_base ON word_groups(base_word)');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_word_groups_forms ON word_groups(word_forms)');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_meanings_word_group ON meanings(word_group_id)');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_meanings_order ON meanings(meaning_order)');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_meanings_primary ON meanings(is_primary)');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_meanings_pos ON meanings(part_of_speech)');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_reverse_lookup_target ON target_reverse_lookup(target_word)');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_reverse_lookup_order ON target_reverse_lookup(lookup_order)');
          await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_reverse_lookup_quality ON target_reverse_lookup(quality_score DESC)');
          
          print('✅ Created cycling dictionary tables and indexes');
          
          // Drop legacy dictionary table completely (cycling dictionaries use new schema)
          try {
            await m.database.customStatement('DROP TABLE IF EXISTS dictionary_entries');
            await m.database.customStatement('DROP TABLE IF EXISTS dictionary_fts');
            await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_ai');
            await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_ad');
            await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_au');
            print('✅ Removed legacy dictionary tables for clean cycling dictionary migration');
          } catch (e) {
            print('Note: No legacy dictionary tables to remove: $e');
          }
          
        } catch (e) {
          print('Error during cycling dictionary migration: $e');
          // Continue with other migrations
        }
      }
      
      if (from < 4) {
        // Legacy migration cleanup - remove old dictionary system completely
        try {
          await m.database.customStatement('DROP TABLE IF EXISTS dictionary_entries');
          await m.database.customStatement('DROP TABLE IF EXISTS dictionary_fts');
          await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_ai');
          await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_ad');
          await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_au');
          print('✅ Cleaned up legacy dictionary system');
        } catch (e) {
          print('Note: Legacy dictionary cleanup: $e');
        }
        
        // Add bookmarks table in schema version 2
        await m.createTable($BookmarksTable(this));
        await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_bookmarks_book_id ON bookmarks(book_id)');
        await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_bookmarks_created_at ON bookmarks(created_at)');
      }
    },
  );

  // Database queries will be added here as needed
  // For now, basic table access is provided by Drift
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'polyread.db'));
    return NativeDatabase(file);
  });
}