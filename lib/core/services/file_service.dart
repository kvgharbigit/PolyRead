// File Service
// Handles book import, storage management, and file operations

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class FileService {
  static const String _booksFolder = 'books';
  static const String _coversFolder = 'covers';
  static const String _languagePacksFolder = 'language_packs';
  
  late final Directory _appDocDir;
  late final Directory _booksDir;
  late final Directory _coversDir;
  late final Directory _languagePacksDir;
  
  Future<void> initialize() async {
    _appDocDir = await getApplicationDocumentsDirectory();
    _booksDir = Directory(p.join(_appDocDir.path, _booksFolder));
    _coversDir = Directory(p.join(_appDocDir.path, _coversFolder));
    _languagePacksDir = Directory(p.join(_appDocDir.path, _languagePacksFolder));
    
    // Create directories if they don't exist
    await _booksDir.create(recursive: true);
    await _coversDir.create(recursive: true);
    await _languagePacksDir.create(recursive: true);
  }
  
  // Book file operations
  Future<String> importBook(File sourceFile) async {
    final fileName = p.basename(sourceFile.path);
    final targetPath = p.join(_booksDir.path, fileName);
    
    // Copy file to app directory
    await sourceFile.copy(targetPath);
    
    return targetPath;
  }
  
  Future<void> deleteBook(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  Future<bool> bookExists(String filePath) async {
    return await File(filePath).exists();
  }
  
  Future<int> getBookFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }
  
  // Cover image operations
  Future<String?> saveCoverImage(Uint8List imageData, String bookId) async {
    try {
      final fileName = 'cover_$bookId.jpg';
      final filePath = p.join(_coversDir.path, fileName);
      final file = File(filePath);
      
      await file.writeAsBytes(imageData);
      return filePath;
    } catch (e) {
      return null;
    }
  }
  
  Future<void> deleteCoverImage(String? coverPath) async {
    if (coverPath == null) return;
    
    final file = File(coverPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  // Language pack operations
  Future<String> getLanguagePackPath(String packId) async {
    return p.join(_languagePacksDir.path, '$packId.zip');
  }
  
  Future<void> deleteLanguagePack(String packId) async {
    final packPath = await getLanguagePackPath(packId);
    final file = File(packPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  // Storage management
  Future<StorageInfo> getStorageInfo() async {
    final totalSize = await _calculateDirectorySize(_appDocDir);
    final booksSize = await _calculateDirectorySize(_booksDir);
    final coversSize = await _calculateDirectorySize(_coversDir);
    final languagePacksSize = await _calculateDirectorySize(_languagePacksDir);
    
    return StorageInfo(
      totalBytes: totalSize,
      booksBytes: booksSize,
      coversBytes: coversSize,
      languagePacksBytes: languagePacksSize,
    );
  }
  
  Future<int> _calculateDirectorySize(Directory directory) async {
    int totalSize = 0;
    
    if (!await directory.exists()) return 0;
    
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    
    return totalSize;
  }
  
  Future<void> cleanupCache() async {
    // Remove temporary files, old covers for deleted books, etc.
    // This would be called periodically or when storage is low
  }
  
  // File validation
  Future<bool> validateBookFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    
    final extension = p.extension(filePath).toLowerCase();
    return extension == '.pdf' || extension == '.epub';
  }
  
  Future<String> calculateFileChecksum(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw FileSystemException('File not found');
    
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Backup and restore
  Future<String> exportAppData() async {
    // Create a backup of all app data
    // This would create a zip file with books, settings, and database
    throw UnimplementedError('Export functionality not yet implemented');
  }
  
  Future<void> importAppData(String backupPath) async {
    // Restore app data from backup
    throw UnimplementedError('Import functionality not yet implemented');
  }
}

class StorageInfo {
  final int totalBytes;
  final int booksBytes;
  final int coversBytes;
  final int languagePacksBytes;
  
  const StorageInfo({
    required this.totalBytes,
    required this.booksBytes,
    required this.coversBytes,
    required this.languagePacksBytes,
  });
  
  double get totalMB => totalBytes / (1024 * 1024);
  double get booksMB => booksBytes / (1024 * 1024);
  double get coversMB => coversBytes / (1024 * 1024);
  double get languagePacksMB => languagePacksBytes / (1024 * 1024);
}