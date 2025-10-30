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

// Dictionary entries (compatible with Wiktionary/StarDict format)
class DictionaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // Core Wiktionary fields
  TextColumn get writtenRep => text()(); // The headword/lemma (Wiktionary: written_rep)
  TextColumn get lexentry => text().nullable()(); // Lexical entry ID (e.g., "cold_ADJ_01")
  TextColumn get sense => text().nullable()(); // Definition/meaning description
  TextColumn get transList => text()(); // Pipe-separated translations (e.g., "frío | helado | gélido")
  TextColumn get pos => text().nullable()(); // Part of speech
  TextColumn get domain => text().nullable()(); // Semantic domain
  
  // Language pair information
  TextColumn get sourceLanguage => text()(); // Source language code
  TextColumn get targetLanguage => text()(); // Target language code
  
  // Additional metadata
  TextColumn get pronunciation => text().nullable()(); // IPA or other
  TextColumn get examples => text().nullable()(); // JSON array of example sentences
  IntColumn get frequency => integer().withDefault(const Constant(0))(); // Usage frequency
  TextColumn get source => text().nullable()(); // Dictionary pack source
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  // Deprecated fields (maintained for data migration only - DO NOT USE in new code)
  // All new code should use modern Wiktionary fields: writtenRep, sense, transList, pos
  TextColumn get lemma => text().withDefault(const Constant(''))(); // DEPRECATED: Use writtenRep
  TextColumn get definition => text().withDefault(const Constant(''))(); // DEPRECATED: Use sense/transList  
  TextColumn get partOfSpeech => text().nullable()(); // DEPRECATED: Use pos
  TextColumn get languagePair => text().withDefault(const Constant(''))(); // DEPRECATED: Use sourceLanguage/targetLanguage
}

// FTS table for dictionary search (compatible with Wiktionary format)
@UseRowClass(DictionaryFtsData)
class DictionaryFts extends Table {
  TextColumn get writtenRep => text()(); // Headword for search
  TextColumn get sense => text()(); // Definition for search
  TextColumn get transList => text()(); // Translations for search
  
  @override
  String get tableName => 'dictionary_fts';
}

class DictionaryFtsData {
  final String writtenRep;
  final String sense;
  final String transList;
  
  DictionaryFtsData({required this.writtenRep, required this.sense, required this.transList});
}

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
  DictionaryEntries,
  DictionaryFts,
  LanguagePacks,
  Bookmarks,
  UserSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      
      // Create FTS table for dictionary search (Wiktionary format)
      await m.database.customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS dictionary_fts USING fts5(
          written_rep,
          sense,
          trans_list,
          content='dictionary_entries',
          content_rowid='id'
        )
      ''');
      
      // Create triggers to keep FTS in sync with dictionary_entries
      await m.database.customStatement('''
        CREATE TRIGGER IF NOT EXISTS dictionary_entries_ai AFTER INSERT ON dictionary_entries
        BEGIN
          INSERT INTO dictionary_fts(written_rep, sense, trans_list)
          VALUES (new.written_rep, COALESCE(new.sense, ''), new.trans_list);
        END
      ''');
      
      await m.database.customStatement('''
        CREATE TRIGGER IF NOT EXISTS dictionary_entries_ad AFTER DELETE ON dictionary_entries
        BEGIN
          DELETE FROM dictionary_fts WHERE written_rep = old.written_rep AND sense = COALESCE(old.sense, '') AND trans_list = old.trans_list;
        END
      ''');
      
      await m.database.customStatement('''
        CREATE TRIGGER IF NOT EXISTS dictionary_entries_au AFTER UPDATE ON dictionary_entries
        BEGIN
          DELETE FROM dictionary_fts WHERE written_rep = old.written_rep AND sense = COALESCE(old.sense, '') AND trans_list = old.trans_list;
          INSERT INTO dictionary_fts(written_rep, sense, trans_list)
          VALUES (new.written_rep, COALESCE(new.sense, ''), new.trans_list);
        END
      ''');
      
      // Create indexes for better performance
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_books_language ON books(language)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_books_file_type ON books(file_type)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_reading_progress_book_id ON reading_progress(book_id)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_vocabulary_book_id ON vocabulary_items(book_id)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_vocabulary_next_review ON vocabulary_items(next_review)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_dictionary_written_rep ON dictionary_entries(written_rep)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_dictionary_pos ON dictionary_entries(pos)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_dictionary_source_lang ON dictionary_entries(source_language)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_dictionary_target_lang ON dictionary_entries(target_language)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_dictionary_lang_pair ON dictionary_entries(source_language, target_language)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_language_packs_active ON language_packs(is_active)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_bookmarks_book_id ON bookmarks(book_id)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_bookmarks_created_at ON bookmarks(created_at)');
      await m.database.customStatement('CREATE INDEX IF NOT EXISTS idx_user_settings_key ON user_settings(key)');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 4) {
        // Fix FTS table issues from previous schema versions
        try {
          // Drop existing FTS table and triggers if they exist
          await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_ai');
          await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_ad');
          await m.database.customStatement('DROP TRIGGER IF EXISTS dictionary_entries_au');
          await m.database.customStatement('DROP TABLE IF EXISTS dictionary_fts');
          
          // Clear existing dictionary data to avoid migration conflicts
          await m.database.customStatement('DELETE FROM dictionary_entries');
          
          // Add new Wiktionary columns if they don't exist
          try {
            await m.database.customStatement('ALTER TABLE dictionary_entries ADD COLUMN written_rep TEXT DEFAULT ""');
          } catch (e) {
            // Column might already exist
          }
          try {
            await m.database.customStatement('ALTER TABLE dictionary_entries ADD COLUMN sense TEXT');
          } catch (e) {
            // Column might already exist
          }
          try {
            await m.database.customStatement('ALTER TABLE dictionary_entries ADD COLUMN trans_list TEXT DEFAULT ""');
          } catch (e) {
            // Column might already exist
          }
          try {
            await m.database.customStatement('ALTER TABLE dictionary_entries ADD COLUMN pos TEXT');
          } catch (e) {
            // Column might already exist
          }
          try {
            await m.database.customStatement('ALTER TABLE dictionary_entries ADD COLUMN source_language TEXT DEFAULT "unknown"');
          } catch (e) {
            // Column might already exist
          }
          try {
            await m.database.customStatement('ALTER TABLE dictionary_entries ADD COLUMN target_language TEXT DEFAULT "unknown"');
          } catch (e) {
            // Column might already exist
          }
          
          // Recreate FTS table with Wiktionary-compatible schema
          await m.database.customStatement('''
            CREATE VIRTUAL TABLE dictionary_fts USING fts5(
              written_rep,
              sense,
              trans_list,
              content='dictionary_entries',
              content_rowid='id'
            )
          ''');
          
          // Recreate triggers with Wiktionary-compatible field names
          await m.database.customStatement('''
            CREATE TRIGGER dictionary_entries_ai AFTER INSERT ON dictionary_entries
            BEGIN
              INSERT INTO dictionary_fts(written_rep, sense, trans_list)
              VALUES (new.written_rep, COALESCE(new.sense, ''), new.trans_list);
              
              -- Update legacy compatibility fields
              UPDATE dictionary_entries SET 
                lemma = new.written_rep,
                definition = COALESCE(new.sense, ''),
                part_of_speech = new.pos,
                language_pair = new.source_language || '-' || new.target_language
              WHERE id = new.id;
            END
          ''');
          
          await m.database.customStatement('''
            CREATE TRIGGER dictionary_entries_ad AFTER DELETE ON dictionary_entries
            BEGIN
              DELETE FROM dictionary_fts WHERE written_rep = old.written_rep AND sense = COALESCE(old.sense, '') AND trans_list = old.trans_list;
            END
          ''');
          
          await m.database.customStatement('''
            CREATE TRIGGER dictionary_entries_au AFTER UPDATE ON dictionary_entries
            BEGIN
              DELETE FROM dictionary_fts WHERE written_rep = old.written_rep AND sense = COALESCE(old.sense, '') AND trans_list = old.trans_list;
              INSERT INTO dictionary_fts(written_rep, sense, trans_list)
              VALUES (new.written_rep, COALESCE(new.sense, ''), new.trans_list);
            END
          ''');
          
          print('Fixed FTS table schema during migration');
        } catch (e) {
          print('Error fixing FTS table during migration: $e');
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