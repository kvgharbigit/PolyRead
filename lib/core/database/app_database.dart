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

// Dictionary entries (from StarDict imports)
class DictionaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get lemma => text()(); // The word to look up
  TextColumn get definition => text()();
  TextColumn get partOfSpeech => text().nullable()();
  TextColumn get languagePair => text()(); // e.g., 'en-es'
  IntColumn get frequency => integer().withDefault(const Constant(0))(); // Usage frequency
  TextColumn get pronunciation => text().nullable()(); // IPA or other
  TextColumn get examples => text().nullable()(); // JSON array of example sentences
  TextColumn get synonyms => text().nullable()(); // JSON array
  TextColumn get source => text().nullable()(); // Dictionary pack source
}

// FTS table for dictionary search
class DictionaryFts extends Table {
  IntColumn get rowid => integer()();
  TextColumn get lemma => text()();
  TextColumn get definition => text()();
  
  @override
  String get tableName => 'dictionary_fts';
  
  @override
  Set<Column> get primaryKey => {rowid};
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
  UserSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      
      // Create FTS table for dictionary search
      await customStatement('''
        CREATE VIRTUAL TABLE dictionary_fts USING fts5(
          lemma,
          definition,
          content='dictionary_entries',
          content_rowid='id'
        )
      ''');
      
      // Create triggers to keep FTS in sync with dictionary_entries
      await customStatement('''
        CREATE TRIGGER dictionary_entries_ai AFTER INSERT ON dictionary_entries
        BEGIN
          INSERT INTO dictionary_fts(rowid, lemma, definition)
          VALUES (new.id, new.lemma, new.definition);
        END
      ''');
      
      await customStatement('''
        CREATE TRIGGER dictionary_entries_ad AFTER DELETE ON dictionary_entries
        BEGIN
          INSERT INTO dictionary_fts(dictionary_fts, rowid, lemma, definition)
          VALUES('delete', old.id, old.lemma, old.definition);
        END
      ''');
      
      await customStatement('''
        CREATE TRIGGER dictionary_entries_au AFTER UPDATE ON dictionary_entries
        BEGIN
          INSERT INTO dictionary_fts(dictionary_fts, rowid, lemma, definition)
          VALUES('delete', old.id, old.lemma, old.definition);
          INSERT INTO dictionary_fts(rowid, lemma, definition)
          VALUES (new.id, new.lemma, new.definition);
        END
      ''');
      
      // Create indexes for better performance
      await customStatement('CREATE INDEX idx_books_language ON books(language)');
      await customStatement('CREATE INDEX idx_books_file_type ON books(file_type)');
      await customStatement('CREATE INDEX idx_reading_progress_book_id ON reading_progress(book_id)');
      await customStatement('CREATE INDEX idx_vocabulary_book_id ON vocabulary_items(book_id)');
      await customStatement('CREATE INDEX idx_vocabulary_next_review ON vocabulary_items(next_review)');
      await customStatement('CREATE INDEX idx_dictionary_lemma ON dictionary_entries(lemma)');
      await customStatement('CREATE INDEX idx_dictionary_language_pair ON dictionary_entries(language_pair)');
      await customStatement('CREATE INDEX idx_language_packs_active ON language_packs(is_active)');
      await customStatement('CREATE INDEX idx_user_settings_key ON user_settings(key)');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Handle future schema migrations here
    },
  );

  // Database queries will be added here as needed
  // For now, basic table access is provided by Drift
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'polyread.db'));
    return NativeDatabase(file);
  });
}