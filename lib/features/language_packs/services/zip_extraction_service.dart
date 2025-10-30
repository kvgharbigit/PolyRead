// ZIP Extraction Service - Handles extraction of downloaded .sqlite.zip files
// Provides secure ZIP extraction with validation and error handling

import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class ZipExtractionService {
  static const int _maxFileSize = 1024 * 1024 * 1024; // 1GB limit per file (for large dictionaries)
  static const int _maxTotalSize = 1024 * 1024 * 1024; // 1GB total limit
  static const List<String> _allowedExtensions = ['.sqlite', '.db'];
  
  /// Extract a ZIP file to a destination directory
  /// Returns list of extracted file paths
  Future<List<String>> extractZip({
    required String zipFilePath,
    required String destinationDir,
    Function(String fileName, int progress)? onProgress,
  }) async {
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      throw ZipExtractionException('ZIP file not found: $zipFilePath');
    }
    
    // Ensure destination directory exists
    final destDir = Directory(destinationDir);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    
    final extractedFiles = <String>[];
    
    try {
      // Read and decode ZIP file
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Validate ZIP contents before extraction
      await _validateZipContents(archive);
      
      // Extract files
      int totalFiles = archive.length;
      int processedFiles = 0;
      
      for (final file in archive) {
        if (file.isFile) {
          final extractedPath = await _extractFile(file, destinationDir);
          if (extractedPath != null) {
            extractedFiles.add(extractedPath);
          }
        }
        
        processedFiles++;
        onProgress?.call(file.name, (processedFiles * 100) ~/ totalFiles);
      }
      
      return extractedFiles;
    } catch (e) {
      // Clean up any partially extracted files on error
      await _cleanupPartialExtraction(extractedFiles);
      throw ZipExtractionException('Failed to extract ZIP: $e');
    }
  }
  
  /// Extract dictionary SQLite files specifically
  /// Returns the path to the extracted SQLite file
  Future<String?> extractDictionarySqlite({
    required String zipFilePath,
    required String destinationDir,
    Function(String message)? onProgress,
  }) async {
    onProgress?.call('Extracting dictionary database...');
    
    final extractedFiles = await extractZip(
      zipFilePath: zipFilePath,
      destinationDir: destinationDir,
      onProgress: (fileName, progress) {
        onProgress?.call('Extracting $fileName ($progress%)');
      },
    );
    
    // Find the SQLite file
    final sqliteFiles = extractedFiles.where((filePath) {
      final extension = path.extension(filePath).toLowerCase();
      return _allowedExtensions.contains(extension);
    }).toList();
    
    if (sqliteFiles.isEmpty) {
      throw ZipExtractionException('No SQLite database file found in ZIP archive');
    }
    
    if (sqliteFiles.length > 1) {
      // Use the largest file as the main dictionary
      String? largestFile;
      int largestSize = 0;
      
      for (final filePath in sqliteFiles) {
        final file = File(filePath);
        final size = await file.length();
        if (size > largestSize) {
          largestSize = size;
          largestFile = filePath;
        }
      }
      
      onProgress?.call('Found multiple SQLite files, using largest: ${path.basename(largestFile!)}');
      return largestFile;
    }
    
    onProgress?.call('Dictionary extracted successfully');
    return sqliteFiles.first;
  }
  
  /// Validate ZIP file integrity and safety
  Future<void> validateZipFile(String zipFilePath) async {
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      throw ZipExtractionException('ZIP file not found: $zipFilePath');
    }
    
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      await _validateZipContents(archive);
    } catch (e) {
      throw ZipExtractionException('ZIP validation failed: $e');
    }
  }
  
  /// Get information about ZIP contents without extracting
  Future<ZipInfo> getZipInfo(String zipFilePath) async {
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      throw ZipExtractionException('ZIP file not found: $zipFilePath');
    }
    
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    final files = <ZipFileInfo>[];
    int totalUncompressedSize = 0;
    int sqliteFileCount = 0;
    
    for (final file in archive) {
      if (file.isFile) {
        final extension = path.extension(file.name).toLowerCase();
        final isSqlite = _allowedExtensions.contains(extension);
        
        if (isSqlite) {
          sqliteFileCount++;
        }
        
        files.add(ZipFileInfo(
          name: file.name,
          compressedSize: file.rawContent?.length ?? 0,
          uncompressedSize: file.size,
          isSqlite: isSqlite,
        ));
        
        totalUncompressedSize += file.size;
      }
    }
    
    return ZipInfo(
      totalFiles: files.length,
      totalUncompressedSize: totalUncompressedSize,
      sqliteFileCount: sqliteFileCount,
      files: files,
    );
  }
  
  // Private helper methods
  
  Future<void> _validateZipContents(Archive archive) async {
    int totalUncompressedSize = 0;
    bool hasSqliteFile = false;
    
    for (final file in archive) {
      if (file.isFile) {
        // Check individual file size
        if (file.size > _maxFileSize) {
          throw ZipExtractionException(
            'File ${file.name} exceeds maximum size limit (${file.size} bytes)'
          );
        }
        
        // Check for path traversal attacks
        if (file.name.contains('..') || file.name.startsWith('/')) {
          throw ZipExtractionException(
            'Unsafe file path detected: ${file.name}'
          );
        }
        
        // Check file extension
        final extension = path.extension(file.name).toLowerCase();
        if (_allowedExtensions.contains(extension)) {
          hasSqliteFile = true;
        }
        
        totalUncompressedSize += file.size;
      }
    }
    
    // Check total size
    if (totalUncompressedSize > _maxTotalSize) {
      throw ZipExtractionException(
        'Total uncompressed size exceeds limit ($totalUncompressedSize bytes)'
      );
    }
    
    // Ensure we have at least one SQLite file
    if (!hasSqliteFile) {
      throw ZipExtractionException(
        'ZIP archive must contain at least one SQLite database file'
      );
    }
  }
  
  Future<String?> _extractFile(ArchiveFile file, String destinationDir) async {
    // Create safe file path
    final fileName = path.basename(file.name);
    final filePath = path.join(destinationDir, fileName);
    
    // Create directory if needed
    final parentDir = Directory(path.dirname(filePath));
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
    
    // Extract file
    final outputFile = File(filePath);
    await outputFile.writeAsBytes(file.content as List<int>);
    
    return filePath;
  }
  
  Future<void> _cleanupPartialExtraction(List<String> extractedFiles) async {
    for (final filePath in extractedFiles) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }
}

// Data classes

class ZipInfo {
  final int totalFiles;
  final int totalUncompressedSize;
  final int sqliteFileCount;
  final List<ZipFileInfo> files;
  
  const ZipInfo({
    required this.totalFiles,
    required this.totalUncompressedSize,
    required this.sqliteFileCount,
    required this.files,
  });
  
  bool get isValid => sqliteFileCount > 0;
  
  String get primarySqliteFile {
    final sqliteFiles = files.where((f) => f.isSqlite).toList();
    if (sqliteFiles.isEmpty) return '';
    
    // Return largest SQLite file
    sqliteFiles.sort((a, b) => b.uncompressedSize.compareTo(a.uncompressedSize));
    return sqliteFiles.first.name;
  }
}

class ZipFileInfo {
  final String name;
  final int compressedSize;
  final int uncompressedSize;
  final bool isSqlite;
  
  const ZipFileInfo({
    required this.name,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.isSqlite,
  });
}

class ZipExtractionException implements Exception {
  final String message;
  const ZipExtractionException(this.message);
  
  @override
  String toString() => 'ZipExtractionException: $message';
}