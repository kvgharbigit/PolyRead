// Migration Service
// Handles app data migration between versions and file location changes

import 'package:drift/drift.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/services/file_service.dart';

class MigrationService {
  final AppDatabase _database;
  final FileService _fileService;
  
  MigrationService({
    required AppDatabase database,
    required FileService fileService,
  }) : _database = database,
       _fileService = fileService;

  /// Run all necessary migrations
  Future<void> runMigrations() async {
    print('🔄 Starting app migrations...');
    
    // Migrate files to new persistent location
    await _migrateFilesToApplicationSupport();
    
    // Fix database file paths
    await _fixDatabaseFilePaths();
    
    print('✅ Migrations complete');
  }

  /// Migrate book files from Documents to Application Support directory
  Future<void> _migrateFilesToApplicationSupport() async {
    try {
      print('📁 Migrating book files...');
      final migratedFiles = await _fileService.migrateExistingBooks();
      
      if (migratedFiles.isNotEmpty) {
        print('✅ Migrated ${migratedFiles.length} book files to persistent storage');
      }
    } catch (e) {
      print('❌ File migration failed: $e');
    }
  }

  /// Fix database file paths to point to new locations
  Future<void> _fixDatabaseFilePaths() async {
    try {
      print('🔗 Fixing database file paths...');
      
      // Get all books from database
      final books = await _database.select(_database.books).get();
      int fixedCount = 0;
      
      for (final book in books) {
        // Check if current path exists
        final currentExists = await _fileService.bookExists(book.filePath);
        
        if (!currentExists) {
          // Try to find the book in the new location
          final newPath = await _fileService.findBookInNewLocation(book.filePath);
          
          if (newPath != null) {
            // Update database with new path
            await (_database.update(_database.books)
                  ..where((t) => t.id.equals(book.id)))
                .write(BooksCompanion(
                  filePath: Value(newPath),
                ));
            
            print('✅ Fixed path for "${book.title}": ${book.filePath} → $newPath');
            fixedCount++;
          } else {
            print('⚠️  Book file not found for "${book.title}": ${book.filePath}');
          }
        }
      }
      
      if (fixedCount > 0) {
        print('✅ Fixed $fixedCount database file paths');
      }
    } catch (e) {
      print('❌ Database path fixing failed: $e');
    }
  }

  /// Clean up broken book entries (files that no longer exist)
  Future<int> cleanupBrokenEntries() async {
    try {
      print('🧹 Cleaning up broken book entries...');
      
      final books = await _database.select(_database.books).get();
      int removedCount = 0;
      
      for (final book in books) {
        final exists = await _fileService.bookExists(book.filePath);
        
        if (!exists) {
          // Remove book entry from database
          await (_database.delete(_database.books)
                ..where((t) => t.id.equals(book.id)))
              .go();
          
          print('🗑️  Removed broken entry: "${book.title}"');
          removedCount++;
        }
      }
      
      print('✅ Cleaned up $removedCount broken entries');
      return removedCount;
    } catch (e) {
      print('❌ Cleanup failed: $e');
      return 0;
    }
  }

  /// Get statistics about file status
  Future<FileStatusStats> getFileStatusStats() async {
    final books = await _database.select(_database.books).get();
    int validFiles = 0;
    int missingFiles = 0;
    
    for (final book in books) {
      final exists = await _fileService.bookExists(book.filePath);
      if (exists) {
        validFiles++;
      } else {
        missingFiles++;
      }
    }
    
    return FileStatusStats(
      totalBooks: books.length,
      validFiles: validFiles,
      missingFiles: missingFiles,
    );
  }
}

class FileStatusStats {
  final int totalBooks;
  final int validFiles;
  final int missingFiles;
  
  const FileStatusStats({
    required this.totalBooks,
    required this.validFiles,
    required this.missingFiles,
  });
  
  double get validPercentage => totalBooks > 0 ? (validFiles / totalBooks) * 100 : 0;
  
  @override
  String toString() {
    return 'FileStats(total: $totalBooks, valid: $validFiles, missing: $missingFiles, ${validPercentage.toStringAsFixed(1)}% valid)';
  }
}