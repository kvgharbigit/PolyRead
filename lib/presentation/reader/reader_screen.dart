// Reader Screen
// Main reading interface for PDF and EPUB files

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/providers/database_provider.dart';
import 'package:polyread/features/reader/widgets/book_reader_widget.dart';
import 'package:polyread/features/reader/services/reading_progress_service.dart' show ReadingProgressService;
import 'package:polyread/features/reader/services/reading_progress_service.dart' as progress;
import 'package:polyread/features/reader/services/book_import_service.dart';
import 'package:polyread/core/providers/file_service_provider.dart';

class ReaderScreen extends ConsumerWidget {
  final int bookId;
  
  const ReaderScreen({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);
    
    return FutureBuilder<Book?>(
      future: _getBook(database, bookId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load book',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final book = snapshot.data;
        if (book == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Book Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Book not found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The requested book could not be found.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Get reading progress and open book
        return FutureBuilder<progress.ReadingProgressData?>(
          future: _getReadingProgress(database, bookId),
          builder: (context, progressSnapshot) {
            // Update last opened time
            _updateLastOpened(ref, bookId);
            
            return BookReaderWidget(
              book: book,
              initialPosition: progressSnapshot.data?.position,
            );
          },
        );
      },
    );
  }
  
  Future<Book?> _getBook(AppDatabase database, int bookId) async {
    try {
      return await (database.select(database.books)
        ..where((b) => b.id.equals(bookId))).getSingleOrNull();
    } catch (e) {
      throw Exception('Failed to load book: $e');
    }
  }
  
  Future<progress.ReadingProgressData?> _getReadingProgress(AppDatabase database, int bookId) async {
    try {
      final progressService = ReadingProgressService(database);
      return await progressService.getProgress(bookId);
    } catch (e) {
      // Progress loading failed, continue without initial position
      return null;
    }
  }
  
  void _updateLastOpened(WidgetRef ref, int bookId) {
    // Update last opened time asynchronously
    Future.microtask(() async {
      try {
        final database = ref.read(databaseProvider);
        final fileService = ref.read(fileServiceProvider);
        final importService = BookImportService(database, fileService);
        await importService.updateLastOpened(bookId);
      } catch (e) {
        // Failed to update last opened, not critical
      }
    });
  }
}