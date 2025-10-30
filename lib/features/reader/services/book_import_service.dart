// Book Import Service
// Handles importing PDF and EPUB files into the library

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:path/path.dart' as path;
import 'package:epubx/epubx.dart' as epubx;
import 'package:pdfx/pdfx.dart';
import 'package:image/image.dart' as img;
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/services/file_service.dart';
import 'package:polyread/core/services/error_service.dart';
import 'package:drift/drift.dart';

class BookImportService {
  final AppDatabase _database;
  final FileService _fileService;
  
  BookImportService(this._database, this._fileService);
  
  /// Import books from device storage
  Future<List<BookImportResult>> importBooksFromDevice() async {
    try {
      print('📚 BookImportService: Starting book import from device...');
      
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'html', 'htm', 'txt'],
        allowMultiple: true,
        allowCompression: false,
        withReadStream: false,
        withData: false,
      );
      
      print('📚 BookImportService: File picker result: ${result != null ? "${result.files.length} files selected" : "cancelled"}');
      
      if (result == null || result.files.isEmpty) {
        print('📚 BookImportService: No files selected, returning empty list');
        return [];
      }
      
      final importResults = <BookImportResult>[];
      
      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        print('📚 BookImportService: Processing file ${i + 1}/${result.files.length}: ${file.name}');
        print('📚 BookImportService: File path: ${file.path}');
        print('📚 BookImportService: File size: ${file.size} bytes');
        
        if (file.path == null) {
          print('📚 BookImportService: ❌ File path is null, skipping file: ${file.name}');
          continue;
        }
        
        final importResult = await _importSingleBook(file.path!);
        importResults.add(importResult);
        
        print('📚 BookImportService: Import result for ${file.name}: ${importResult.success ? "SUCCESS" : "FAILED - ${importResult.error}"}');
      }
      
      print('📚 BookImportService: ✅ Completed importing ${result.files.length} files');
      print('📚 BookImportService: Results: ${importResults.where((r) => r.success).length} successful, ${importResults.where((r) => !r.success).length} failed');
      
      return importResults;
    } catch (e) {
      print('📚 BookImportService: ❌ Critical error during import: $e');
      print('📚 BookImportService: Stack trace: ${StackTrace.current}');
      ErrorService.logFileSystemError(
        'Failed to import books from device',
        details: e.toString(),
      );
      return [BookImportResult.error('Failed to import books: ${e.toString()}')];
    }
  }
  
  /// Import a single book file
  Future<BookImportResult> importBook(String filePath) async {
    return await _importSingleBook(filePath);
  }
  
  Future<BookImportResult> _importSingleBook(String sourcePath) async {
    try {
      print('📚 _importSingleBook: Starting import for: $sourcePath');
      
      final sourceFile = File(sourcePath);
      print('📚 _importSingleBook: Checking if source file exists...');
      if (!await sourceFile.exists()) {
        print('📚 _importSingleBook: ❌ Source file not found: $sourcePath');
        return BookImportResult.error('File not found: $sourcePath');
      }
      print('📚 _importSingleBook: ✅ Source file exists');
      
      // Get file info
      final fileName = path.basename(sourcePath);
      final fileExtension = path.extension(sourcePath).toLowerCase();
      final fileSize = await sourceFile.length();
      
      print('📚 _importSingleBook: File info:');
      print('  - Name: $fileName');
      print('  - Extension: $fileExtension');
      print('  - Size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      // Validate file type
      if (fileExtension != '.pdf' && fileExtension != '.epub') {
        print('📚 _importSingleBook: ❌ Unsupported file type: $fileExtension');
        return BookImportResult.error('Unsupported file type: $fileExtension');
      }
      print('📚 _importSingleBook: ✅ File type supported: $fileExtension');
      
      // Copy file to app storage
      print('📚 _importSingleBook: Copying file to app storage...');
      final targetPath = await _fileService.importBook(sourceFile);
      print('📚 _importSingleBook: ✅ File copied to: $targetPath');
      
      // Verify copied file exists
      final targetFile = File(targetPath);
      if (!await targetFile.exists()) {
        print('📚 _importSingleBook: ❌ Target file not found after copy: $targetPath');
        return BookImportResult.error('Failed to copy file to app storage');
      }
      print('📚 _importSingleBook: ✅ Target file verified at: $targetPath');
      
      // Extract metadata
      print('📚 _importSingleBook: Extracting metadata...');
      BookMetadata? metadata;
      if (fileExtension == '.pdf') {
        print('📚 _importSingleBook: Extracting PDF metadata...');
        metadata = await _extractPdfMetadata(targetPath);
      } else if (fileExtension == '.epub') {
        print('📚 _importSingleBook: Extracting EPUB metadata...');
        metadata = await _extractEpubMetadata(targetPath);
      }
      
      if (metadata == null) {
        print('📚 _importSingleBook: ❌ Failed to extract metadata');
        return BookImportResult.error('Failed to extract book metadata');
      }
      
      print('📚 _importSingleBook: ✅ Metadata extracted:');
      print('  - Title: ${metadata.title}');
      print('  - Author: ${metadata.author ?? "Unknown"}');
      print('  - Language: ${metadata.language}');
      print('  - Pages: ${metadata.totalPages ?? "Unknown"}');
      print('  - Chapters: ${metadata.totalChapters ?? "Unknown"}');
      
      // Generate cover image
      print('📚 _importSingleBook: Generating cover image...');
      String? coverPath;
      try {
        final coverImage = await _generateCoverImage(targetPath, fileExtension);
        if (coverImage != null) {
          print('📚 _importSingleBook: Cover image generated (${coverImage.length} bytes)');
          coverPath = await _fileService.saveCoverImage(
            coverImage, 
            metadata.title.replaceAll(RegExp(r'[^\w\s-]'), ''),
          );
          print('📚 _importSingleBook: ✅ Cover saved to: $coverPath');
        } else {
          print('📚 _importSingleBook: No cover image generated');
        }
      } catch (e) {
        print('📚 _importSingleBook: ⚠️ Cover generation failed: $e');
        // Cover generation failed, continue without cover
        ErrorService.logFileSystemError(
          'Failed to generate cover image',
          details: e.toString(),
        );
      }
      
      // Save to database
      print('📚 _importSingleBook: Saving to database...');
      final companion = BooksCompanion.insert(
        title: metadata.title,
        author: Value(metadata.author),
        filePath: targetPath,
        fileType: fileExtension.substring(1), // Remove the dot
        language: metadata.language,
        totalPages: Value(metadata.totalPages),
        totalChapters: Value(metadata.totalChapters),
        coverImagePath: Value(coverPath),
        fileSizeBytes: fileSize,
        importedAt: Value(DateTime.now()),
      );
      
      print('📚 _importSingleBook: Database companion created, inserting...');
      final bookId = await _database.into(_database.books).insert(companion);
      print('📚 _importSingleBook: ✅ Book saved to database with ID: $bookId');
      
      print('📚 _importSingleBook: ✅✅✅ IMPORT COMPLETED SUCCESSFULLY ✅✅✅');
      return BookImportResult.success(
        bookId: bookId,
        title: metadata.title,
        author: metadata.author,
        filePath: targetPath,
        coverPath: coverPath,
      );
      
    } catch (e) {
      print('📚 _importSingleBook: ❌❌❌ IMPORT FAILED ❌❌❌');
      print('📚 _importSingleBook: Error: $e');
      print('📚 _importSingleBook: Error type: ${e.runtimeType}');
      print('📚 _importSingleBook: Stack trace: ${StackTrace.current}');
      ErrorService.logFileSystemError(
        'Failed to import book',
        details: e.toString(),
        context: {'filePath': sourcePath},
      );
      return BookImportResult.error('Import failed: ${e.toString()}');
    }
  }
  
  /// Extract metadata from PDF file
  Future<BookMetadata?> _extractPdfMetadata(String filePath) async {
    try {
      print('📚 _extractPdfMetadata: Opening PDF file: $filePath');
      final document = await PdfDocument.openFile(filePath);
      print('📚 _extractPdfMetadata: PDF opened successfully');
      
      final pageCount = document.pagesCount;
      print('📚 _extractPdfMetadata: Page count: $pageCount');
      
      // Get document info if available
      // Note: pdfx doesn't expose metadata directly, so we use filename
      final fileName = path.basenameWithoutExtension(filePath);
      print('📚 _extractPdfMetadata: Using filename as title: $fileName');
      
      await document.close();
      print('📚 _extractPdfMetadata: PDF document closed');
      
      final metadata = BookMetadata(
        title: fileName,
        author: null,
        language: _detectLanguageFromFilename(fileName),
        totalPages: pageCount,
        totalChapters: null,
      );
      
      print('📚 _extractPdfMetadata: ✅ PDF metadata extracted successfully');
      return metadata;
    } catch (e) {
      print('📚 _extractPdfMetadata: ❌ Failed to extract PDF metadata: $e');
      ErrorService.logParsingError(
        'Failed to extract PDF metadata',
        details: e.toString(),
        fileName: filePath,
      );
      return null;
    }
  }
  
  /// Extract metadata from EPUB file
  Future<BookMetadata?> _extractEpubMetadata(String filePath) async {
    try {
      print('📚 _extractEpubMetadata: Reading EPUB file: $filePath');
      final bytes = await File(filePath).readAsBytes();
      print('📚 _extractEpubMetadata: File read, ${bytes.length} bytes');
      
      print('📚 _extractEpubMetadata: Parsing EPUB...');
      final book = await epubx.EpubReader.readBook(bytes);
      print('📚 _extractEpubMetadata: EPUB parsed successfully');
      
      final title = book.Title ?? path.basenameWithoutExtension(filePath);
      final author = book.Author;
      final language = book.Schema?.Package?.Metadata?.Languages?.firstOrNull ?? 'unknown';
      final chapters = book.Chapters?.length;
      
      print('📚 _extractEpubMetadata: Extracted metadata:');
      print('  - Title: $title');
      print('  - Author: $author');
      print('  - Language: $language');
      print('  - Chapters: $chapters');
      
      final metadata = BookMetadata(
        title: title,
        author: author,
        language: language,
        totalPages: null,
        totalChapters: chapters,
      );
      
      print('📚 _extractEpubMetadata: ✅ EPUB metadata extracted successfully');
      return metadata;
    } catch (e) {
      print('📚 _extractEpubMetadata: ❌ Failed to extract EPUB metadata: $e');
      ErrorService.logParsingError(
        'Failed to extract EPUB metadata',
        details: e.toString(),
        fileName: filePath,
      );
      return null;
    }
  }
  
  /// Generate cover image from book
  Future<Uint8List?> _generateCoverImage(String filePath, String fileType) async {
    try {
      print('📚 _generateCoverImage: Generating cover for $fileType file: $filePath');
      
      if (fileType == '.epub') {
        print('📚 _generateCoverImage: Processing EPUB cover...');
        final bytes = await File(filePath).readAsBytes();
        final book = await epubx.EpubReader.readBook(bytes);
        
        // Try to get existing cover
        if (book.CoverImage != null) {
          print('📚 _generateCoverImage: Found existing cover image in EPUB');
          final encoded = img.encodeJpg(book.CoverImage!);
          print('📚 _generateCoverImage: ✅ EPUB cover encoded successfully (${encoded.length} bytes)');
          return Uint8List.fromList(encoded);
        } else {
          print('📚 _generateCoverImage: No cover image found in EPUB');
        }
      } else if (fileType == '.pdf') {
        print('📚 _generateCoverImage: Processing PDF cover (first page)...');
        final document = await PdfDocument.openFile(filePath);
        print('📚 _generateCoverImage: PDF opened, pages: ${document.pagesCount}');
        
        if (document.pagesCount > 0) {
          print('📚 _generateCoverImage: Rendering first page...');
          final page = await document.getPage(1);
          final pageImage = await page.render(
            width: 200,
            height: 300,
            format: PdfPageImageFormat.jpeg,
          );
          await page.close();
          await document.close();
          
          if (pageImage?.bytes != null) {
            print('📚 _generateCoverImage: ✅ PDF cover generated successfully (${pageImage!.bytes.length} bytes)');
            return pageImage.bytes;
          } else {
            print('📚 _generateCoverImage: PDF page rendering returned null');
          }
        } else {
          print('📚 _generateCoverImage: PDF has no pages');
          await document.close();
        }
      }
      
      print('📚 _generateCoverImage: No cover image generated');
      return null;
    } catch (e) {
      print('📚 _generateCoverImage: ❌ Cover generation failed: $e');
      // Cover generation failed
      ErrorService.logFileSystemError(
        'Cover generation failed',
        details: e.toString(),
      );
      return null;
    }
  }
  
  /// Delete a book and its files
  Future<bool> deleteBook(int bookId) async {
    try {
      // Get book info
      final book = await (_database.select(_database.books)
        ..where((b) => b.id.equals(bookId))).getSingleOrNull();
      
      if (book == null) return false;
      
      // Delete files
      await _fileService.deleteBook(book.filePath);
      if (book.coverImagePath != null) {
        await _fileService.deleteCoverImage(book.coverImagePath);
      }
      
      // Delete from database (cascade will handle progress)
      await (_database.delete(_database.books)
        ..where((b) => b.id.equals(bookId))).go();
      
      return true;
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to delete book',
        details: e.toString(),
      );
      return false;
    }
  }
  
  /// Get all imported books
  Future<List<Book>> getAllBooks() async {
    try {
      return await (_database.select(_database.books)
        ..orderBy([(b) => OrderingTerm.desc(b.lastOpenedAt ?? b.importedAt)])).get();
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to get books',
        details: e.toString(),
      );
      return [];
    }
  }
  
  /// Update last opened time
  Future<void> updateLastOpened(int bookId) async {
    try {
      await (_database.update(_database.books)
        ..where((b) => b.id.equals(bookId))).write(
        BooksCompanion(lastOpenedAt: Value(DateTime.now())),
      );
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to update last opened',
        details: e.toString(),
      );
    }
  }
  
  /// Simple language detection based on filename patterns and keywords
  String _detectLanguageFromFilename(String filename) {
    final lowerFilename = filename.toLowerCase();
    
    // Common language patterns in filenames
    final languagePatterns = {
      'spanish': 'es',
      'español': 'es',
      'france': 'fr',
      'french': 'fr',
      'français': 'fr',
      'german': 'de',
      'deutsch': 'de',
      'italian': 'it',
      'italiano': 'it',
      'portuguese': 'pt',
      'português': 'pt',
      'chinese': 'zh',
      'japanese': 'ja',
      'korean': 'ko',
      'russian': 'ru',
      'русский': 'ru',
    };
    
    // Check for language keywords in filename
    for (final entry in languagePatterns.entries) {
      if (lowerFilename.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Default to English if no pattern detected
    return 'en';
  }
}

/// Book metadata extracted during import
class BookMetadata {
  final String title;
  final String? author;
  final String language;
  final int? totalPages;
  final int? totalChapters;
  
  const BookMetadata({
    required this.title,
    this.author,
    required this.language,
    this.totalPages,
    this.totalChapters,
  });
}

/// Result of book import operation
class BookImportResult {
  final bool success;
  final String? error;
  final int? bookId;
  final String? title;
  final String? author;
  final String? filePath;
  final String? coverPath;
  
  const BookImportResult._({
    required this.success,
    this.error,
    this.bookId,
    this.title,
    this.author,
    this.filePath,
    this.coverPath,
  });
  
  factory BookImportResult.success({
    required int bookId,
    required String title,
    String? author,
    required String filePath,
    String? coverPath,
  }) {
    return BookImportResult._(
      success: true,
      bookId: bookId,
      title: title,
      author: author,
      filePath: filePath,
      coverPath: coverPath,
    );
  }
  
  factory BookImportResult.error(String error) {
    return BookImportResult._(
      success: false,
      error: error,
    );
  }
}