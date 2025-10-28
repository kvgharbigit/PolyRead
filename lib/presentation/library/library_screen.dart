// Library Screen
// Main screen showing imported books with import functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/providers/database_provider.dart';
import 'package:polyread/core/providers/file_service_provider.dart';
import 'package:polyread/core/services/file_service.dart';
import 'package:polyread/features/reader/services/book_import_service.dart';
import 'package:polyread/presentation/library/widgets/book_card.dart';
import 'package:polyread/core/utils/constants.dart';
import 'package:drift/drift.dart' hide Column;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);
    final fileService = ref.watch(fileServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _isImporting ? null : () => _importBooks(),
            tooltip: 'Import Books',
          ),
        ],
      ),
      body: FutureBuilder<List<Book>>(
        future: _getBooks(database, fileService),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load library',
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
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final books = snapshot.data ?? [];
          
          if (books.isEmpty) {
            return _buildEmptyState();
          }
          
          return _buildBookGrid(books);
        },
      ),
      floatingActionButton: _isImporting ? null : FloatingActionButton(
        onPressed: _importBooks,
        tooltip: 'Import Books',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.library_books_outlined,
            size: 100,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            'No books in your library',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Import PDF or EPUB files to start reading',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _importBooks,
            icon: _isImporting 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(_isImporting ? 'Importing...' : 'Import Books'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBookGrid(List<Book> books) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: AppConstants.defaultPadding,
          mainAxisSpacing: AppConstants.defaultPadding,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return BookCard(
            book: book,
            onTap: () => _openBook(book),
            onDelete: () => _deleteBook(book),
          );
        },
      ),
    );
  }
  
  Future<List<Book>> _getBooks(AppDatabase database, FileService fileService) async {
    final importService = BookImportService(database, fileService);
    return await importService.getAllBooks();
  }
  
  Future<void> _importBooks() async {
    // Skip the problematic file picker and go directly to instructions
    _showImportInstructions();
  }
  
  Future<void> _tryFilePicker() async {
    setState(() => _isImporting = true);
    
    try {
      final database = ref.read(databaseProvider);
      final fileService = ref.read(fileServiceProvider);
      final importService = BookImportService(database, fileService);
      
      final results = await importService.importBooksFromDevice();
      
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No files selected or file picker cancelled')),
          );
        }
        return;
      }
      
      final successCount = results.where((r) => r.success).length;
      final errorCount = results.length - successCount;
      
      if (mounted) {
        String message;
        if (errorCount == 0) {
          message = 'Imported $successCount book${successCount == 1 ? '' : 's'} successfully';
        } else {
          message = 'Imported $successCount book${successCount == 1 ? '' : 's'}, $errorCount failed';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        
        // Refresh the library
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }
  
  void _openBook(Book book) {
    context.push('/reader/${book.id}');
  }
  
  Future<void> _deleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Are you sure you want to delete "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final database = ref.read(databaseProvider);
        final fileService = ref.read(fileServiceProvider);
        final importService = BookImportService(database, fileService);
        
        final success = await importService.deleteBook(book.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success 
                  ? 'Book deleted successfully' 
                  : 'Failed to delete book'),
            ),
          );
          
          if (success) {
            setState(() {}); // Refresh the library
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: ${e.toString()}')),
          );
        }
      }
    }
  }
  
  void _showImportInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Import Books'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The file picker has known issues on iOS Simulator.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('🎯 For immediate testing:'),
              Text('• Use "Add Sample Books" to get test content'),
              Text('• Try the reading and navigation features'),
              SizedBox(height: 12),
              Text('📱 On real device:'),
              Text('• File picker works properly'),
              Text('• Can import from Files app, iCloud, etc.'),
              SizedBox(height: 12),
              Text('🔧 Alternative for simulator:'),
              Text('• Download PDFs in Safari'),
              Text('• Save to Files app first'),
              Text('• Then try file picker'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _addSampleBooks();
            },
            icon: const Icon(Icons.library_add),
            label: const Text('Add Sample Books'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _tryFilePicker();
            },
            child: const Text('Try File Picker'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _addSampleBooks() async {
    try {
      final database = ref.read(databaseProvider);
      
      // Add sample books directly to database for testing
      final sampleBooks = [
        BooksCompanion.insert(
          title: 'Sample PDF Book',
          author: Value('Test Author'),
          filePath: '/sample/path/book1.pdf',
          fileType: 'pdf',
          language: 'en',
          fileSizeBytes: 1024 * 1024, // 1MB
          importedAt: Value(DateTime.now()),
        ),
        BooksCompanion.insert(
          title: 'Sample EPUB Novel',
          author: Value('Demo Writer'),
          filePath: '/sample/path/book2.epub',
          fileType: 'epub',
          language: 'en',
          totalChapters: Value(15),
          fileSizeBytes: 2 * 1024 * 1024, // 2MB
          importedAt: Value(DateTime.now()),
        ),
        BooksCompanion.insert(
          title: 'Learning Spanish',
          author: Value('Language Expert'),
          filePath: '/sample/path/spanish.pdf',
          fileType: 'pdf',
          language: 'es',
          fileSizeBytes: 3 * 1024 * 1024, // 3MB
          importedAt: Value(DateTime.now()),
        ),
      ];
      
      for (final book in sampleBooks) {
        await database.into(database.books).insert(book);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added 3 sample books for testing')),
        );
        setState(() {}); // Refresh the library
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add sample books: ${e.toString()}')),
        );
      }
    }
  }
}

class _PhaseStatusCard extends StatelessWidget {
  const _PhaseStatusCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Implementation Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildPhaseStatus('Phase 0: Architecture Validation', true),
            _buildPhaseStatus('Phase 1: Foundation Architecture', false),
            _buildPhaseStatus('Phase 2: Reading Core', false),
            _buildPhaseStatus('Phase 3: Translation Services', false),
            _buildPhaseStatus('Phase 4: Language Pack Management', false),
            _buildPhaseStatus('Phase 5: Advanced Features', false),
            _buildPhaseStatus('Phase 6: Polish & Deployment', false),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseStatus(String phaseName, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: isActive ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phaseName,
              style: TextStyle(
                color: isActive ? Colors.green : Colors.grey,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}