// Reading Progress Service
// Tracks and persists reading progress for books

import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/core/services/error_service.dart';
import 'package:drift/drift.dart';

class ReadingProgressService {
  final AppDatabase _database;
  
  ReadingProgressService(this._database);
  
  /// Save reading progress for a book
  Future<void> saveProgress({
    required int bookId,
    required ReaderPosition position,
    required double progressPercentage,
    int? readingTimeMs,
    int? wordsRead,
    int? translationsUsed,
  }) async {
    try {
      final companion = ReadingProgressCompanion.insert(
        bookId: bookId,
        currentPage: Value(position.pageNumber),
        currentChapter: Value(position.chapterId),
        currentPosition: Value(position.toJson().toString()),
        progressPercentage: Value(progressPercentage),
        totalReadingTimeMs: Value(readingTimeMs ?? 0),
        wordsRead: Value(wordsRead ?? 0),
        translationsUsed: Value(translationsUsed ?? 0),
        lastReadAt: Value(DateTime.now()),
      );
      
      // Check if progress already exists for this book
      final existing = await (_database.select(_database.readingProgress)
        ..where((p) => p.bookId.equals(bookId))).getSingleOrNull();
      
      if (existing != null) {
        // Update existing progress
        await (_database.update(_database.readingProgress)
          ..where((p) => p.bookId.equals(bookId))).write(
          ReadingProgressCompanion(
            currentPage: Value(position.pageNumber),
            currentChapter: Value(position.chapterId),
            currentPosition: Value(position.toJson().toString()),
            progressPercentage: Value(progressPercentage),
            totalReadingTimeMs: Value((existing.totalReadingTimeMs) + (readingTimeMs ?? 0)),
            wordsRead: Value((existing.wordsRead) + (wordsRead ?? 0)),
            translationsUsed: Value((existing.translationsUsed) + (translationsUsed ?? 0)),
            lastReadAt: Value(DateTime.now()),
          ),
        );
      } else {
        // Insert new progress
        await _database.into(_database.readingProgress).insert(companion);
      }
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to save reading progress',
        details: e.toString(),
      );
    }
  }
  
  /// Get reading progress for a book
  Future<ReadingProgressData?> getProgress(int bookId) async {
    try {
      final progress = await (_database.select(_database.readingProgress)
        ..where((p) => p.bookId.equals(bookId))).getSingleOrNull();
      
      if (progress == null) return null;
      
      ReaderPosition? position;
      if (progress.currentPosition != null) {
        try {
          // Parse JSON position
          final positionData = progress.currentPosition!;
          // This is a simplified parsing - in production you'd use proper JSON
          if (progress.currentPage != null) {
            position = ReaderPosition.pdf(progress.currentPage!);
          } else if (progress.currentChapter != null) {
            position = ReaderPosition.epub(progress.currentChapter!);
          }
        } catch (e) {
          // Fallback to basic position
          if (progress.currentPage != null) {
            position = ReaderPosition.pdf(progress.currentPage!);
          } else if (progress.currentChapter != null) {
            position = ReaderPosition.epub(progress.currentChapter!);
          }
        }
      }
      
      return ReadingProgressData(
        bookId: progress.bookId,
        position: position,
        progressPercentage: progress.progressPercentage,
        totalReadingTimeMs: progress.totalReadingTimeMs,
        wordsRead: progress.wordsRead,
        translationsUsed: progress.translationsUsed,
        lastReadAt: progress.lastReadAt,
      );
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to get reading progress',
        details: e.toString(),
      );
      return null;
    }
  }
  
  /// Get all reading progress sorted by last read
  Future<List<ReadingProgressData>> getAllProgress() async {
    try {
      final progressList = await (_database.select(_database.readingProgress)
        ..orderBy([(p) => OrderingTerm.desc(p.lastReadAt)])).get();
      
      return progressList.map((progress) {
        ReaderPosition? position;
        if (progress.currentPage != null) {
          position = ReaderPosition.pdf(progress.currentPage!);
        } else if (progress.currentChapter != null) {
          position = ReaderPosition.epub(progress.currentChapter!);
        }
        
        return ReadingProgressData(
          bookId: progress.bookId,
          position: position,
          progressPercentage: progress.progressPercentage,
          totalReadingTimeMs: progress.totalReadingTimeMs,
          wordsRead: progress.wordsRead,
          translationsUsed: progress.translationsUsed,
          lastReadAt: progress.lastReadAt,
        );
      }).toList();
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to get all reading progress',
        details: e.toString(),
      );
      return [];
    }
  }
  
  /// Delete reading progress for a book
  Future<void> deleteProgress(int bookId) async {
    try {
      await (_database.delete(_database.readingProgress)
        ..where((p) => p.bookId.equals(bookId))).go();
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to delete reading progress',
        details: e.toString(),
      );
    }
  }
  
  /// Get reading statistics
  Future<ReadingStatistics> getStatistics() async {
    try {
      final progressList = await _database.select(_database.readingProgress).get();
      
      if (progressList.isEmpty) {
        return const ReadingStatistics(
          totalBooks: 0,
          totalReadingTimeMs: 0,
          totalWordsRead: 0,
          totalTranslationsUsed: 0,
          averageProgress: 0.0,
        );
      }
      
      final totalBooks = progressList.length;
      final totalReadingTimeMs = progressList.fold<int>(
        0, (sum, p) => sum + p.totalReadingTimeMs);
      final totalWordsRead = progressList.fold<int>(
        0, (sum, p) => sum + p.wordsRead);
      final totalTranslationsUsed = progressList.fold<int>(
        0, (sum, p) => sum + p.translationsUsed);
      final averageProgress = progressList.fold<double>(
        0.0, (sum, p) => sum + p.progressPercentage) / totalBooks;
      
      return ReadingStatistics(
        totalBooks: totalBooks,
        totalReadingTimeMs: totalReadingTimeMs,
        totalWordsRead: totalWordsRead,
        totalTranslationsUsed: totalTranslationsUsed,
        averageProgress: averageProgress,
      );
    } catch (e) {
      ErrorService.logDatabaseError(
        'Failed to get reading statistics',
        details: e.toString(),
      );
      return const ReadingStatistics(
        totalBooks: 0,
        totalReadingTimeMs: 0,
        totalWordsRead: 0,
        totalTranslationsUsed: 0,
        averageProgress: 0.0,
      );
    }
  }
}

/// Reading progress data model
class ReadingProgressData {
  final int bookId;
  final ReaderPosition? position;
  final double progressPercentage;
  final int totalReadingTimeMs;
  final int wordsRead;
  final int translationsUsed;
  final DateTime lastReadAt;
  
  const ReadingProgressData({
    required this.bookId,
    this.position,
    required this.progressPercentage,
    required this.totalReadingTimeMs,
    required this.wordsRead,
    required this.translationsUsed,
    required this.lastReadAt,
  });
  
  /// Get reading time in minutes
  double get readingTimeMinutes => totalReadingTimeMs / 60000.0;
  
  /// Get reading time in hours
  double get readingTimeHours => totalReadingTimeMs / 3600000.0;
  
  /// Format reading time as string
  String get formattedReadingTime {
    final hours = readingTimeHours.floor();
    final minutes = (readingTimeMinutes % 60).floor();
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

/// Reading statistics
class ReadingStatistics {
  final int totalBooks;
  final int totalReadingTimeMs;
  final int totalWordsRead;
  final int totalTranslationsUsed;
  final double averageProgress;
  
  const ReadingStatistics({
    required this.totalBooks,
    required this.totalReadingTimeMs,
    required this.totalWordsRead,
    required this.totalTranslationsUsed,
    required this.averageProgress,
  });
  
  /// Get total reading time in hours
  double get totalReadingHours => totalReadingTimeMs / 3600000.0;
  
  /// Get average words per minute
  double get averageWordsPerMinute {
    final totalMinutes = totalReadingTimeMs / 60000.0;
    if (totalMinutes == 0) return 0.0;
    return totalWordsRead / totalMinutes;
  }
  
  /// Get translations per hour
  double get translationsPerHour {
    final totalHours = totalReadingHours;
    if (totalHours == 0) return 0.0;
    return totalTranslationsUsed / totalHours;
  }
}