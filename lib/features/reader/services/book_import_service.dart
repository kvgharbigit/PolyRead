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
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'html', 'htm', 'txt'],
        allowMultiple: true,
        allowCompression: false,
        withReadStream: false,
        withData: false,
      );
      
      if (result == null || result.files.isEmpty) {
        return [];
      }
      
      final importResults = <BookImportResult>[];
      
      for (final file in result.files) {
        if (file.path == null) continue;
        
        final importResult = await _importSingleBook(file.path!);
        importResults.add(importResult);
      }
      
      return importResults;
    } catch (e) {
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
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return BookImportResult.error('File not found: $sourcePath');
      }
      
      // Get file info
      final fileName = path.basename(sourcePath);
      final fileExtension = path.extension(sourcePath).toLowerCase();
      final fileSize = await sourceFile.length();
      
      // Validate file type
      if (fileExtension != '.pdf' && fileExtension != '.epub') {
        return BookImportResult.error('Unsupported file type: $fileExtension');
      }
      
      // Copy file to app storage
      final targetPath = await _fileService.importBook(sourceFile);
      
      // Extract metadata
      BookMetadata? metadata;
      if (fileExtension == '.pdf') {
        metadata = await _extractPdfMetadata(targetPath);
      } else if (fileExtension == '.epub') {
        metadata = await _extractEpubMetadata(targetPath);
      }
      
      if (metadata == null) {
        return BookImportResult.error('Failed to extract book metadata');
      }
      
      // Generate cover image
      String? coverPath;
      try {
        final coverImage = await _generateCoverImage(targetPath, fileExtension);
        if (coverImage != null) {
          coverPath = await _fileService.saveCoverImage(
            coverImage, 
            metadata.title.replaceAll(RegExp(r'[^\w\s-]'), ''),
          );
        }
      } catch (e) {
        // Cover generation failed, continue without cover
        ErrorService.logFileSystemError(
          'Failed to generate cover image',
          details: e.toString(),
        );
      }
      
      // Save to database
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
      
      final bookId = await _database.into(_database.books).insert(companion);
      
      return BookImportResult.success(
        bookId: bookId,
        title: metadata.title,
        author: metadata.author,
        filePath: targetPath,
        coverPath: coverPath,
      );
      
    } catch (e) {
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
      final document = await PdfDocument.openFile(filePath);
      final pageCount = document.pagesCount;
      
      // Get document info if available
      // Note: pdfx doesn't expose metadata directly, so we use filename
      final fileName = path.basenameWithoutExtension(filePath);
      
      await document.close();
      
      return BookMetadata(
        title: fileName,
        author: null,
        language: 'unknown', // TODO: Implement language detection
        totalPages: pageCount,
        totalChapters: null,
      );
    } catch (e) {
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
      final bytes = await File(filePath).readAsBytes();
      final book = await epubx.EpubReader.readBook(bytes);
      
      return BookMetadata(
        title: book.Title ?? path.basenameWithoutExtension(filePath),
        author: book.Author,
        language: book.Schema?.Package?.Metadata?.Languages?.firstOrNull ?? 'unknown',
        totalPages: null,
        totalChapters: book.Chapters?.length,
      );
    } catch (e) {
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
      if (fileType == '.epub') {
        final bytes = await File(filePath).readAsBytes();
        final book = await epubx.EpubReader.readBook(bytes);
        
        // Try to get existing cover
        if (book.CoverImage != null) {
          final encoded = img.encodeJpg(book.CoverImage!);
          return Uint8List.fromList(encoded);
        }
      } else if (fileType == '.pdf') {
        final document = await PdfDocument.openFile(filePath);
        if (document.pagesCount > 0) {
          final page = await document.getPage(1);
          final pageImage = await page.render(
            width: 200,
            height: 300,
            format: PdfPageImageFormat.jpeg,
          );
          await page.close();
          await document.close();
          
          return pageImage?.bytes;
        }
        await document.close();
      }
    } catch (e) {
      // Cover generation failed
      ErrorService.logFileSystemError(
        'Cover generation failed',
        details: e.toString(),
      );
    }
    
    return null;
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