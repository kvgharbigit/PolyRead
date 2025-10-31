// Library Screen
// Elegant book library with PolyRead design system

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/providers/database_provider.dart';
import 'package:polyread/core/providers/file_service_provider.dart';
import 'package:polyread/core/services/file_service.dart';
import 'package:polyread/features/reader/services/book_import_service.dart';
import 'package:polyread/presentation/library/widgets/book_card.dart';
import 'package:polyread/core/themes/polyread_spacing.dart';
import 'package:polyread/core/themes/polyread_typography.dart';
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
      appBar: _buildElegantAppBar(),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FutureBuilder<List<Book>>(
        future: _getBooks(database, fileService),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          
          final books = snapshot.data ?? [];
          
          if (books.isEmpty) {
            return _buildEmptyState();
          }
          
          return _buildBookGrid(books);
        },
      ),
      floatingActionButton: _isImporting ? null : _buildElegantFAB(),
    );
  }
  
  /// Build elegant error state
  Widget _buildErrorState(String error) {
    return Container(
      padding: PolyReadSpacing.pagePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.sectionSpacing),
          
          Text(
            'Unable to Load Library',
            style: PolyReadTypography.interfaceTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          
          Text(
            'Something went wrong while loading your books',
            style: PolyReadTypography.interfaceBody.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PolyReadSpacing.smallSpacing),
          
          Text(
            error,
            style: PolyReadTypography.interfaceCaption.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: PolyReadSpacing.sectionSpacing,
                vertical: PolyReadSpacing.elementSpacing,
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Try Again',
              style: PolyReadTypography.interfaceButton,
            ),
          ),
        ],
      ),
    );
  }

  /// Build elegant app bar with PolyRead styling
  PreferredSizeWidget _buildElegantAppBar() {
    return AppBar(
      title: Text(
        'Library',
        style: PolyReadTypography.interfaceTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: PolyReadSpacing.elementSpacing),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isImporting ? null : _importBooks,
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
              child: Container(
                padding: const EdgeInsets.all(PolyReadSpacing.smallSpacing),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Build elegant floating action button
  Widget _buildElegantFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
        boxShadow: PolyReadSpacing.elevatedShadow,
      ),
      child: FloatingActionButton(
        onPressed: _importBooks,
        tooltip: 'Import Books',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: PolyReadSpacing.pagePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Elegant empty state illustration
          Container(
            padding: const EdgeInsets.all(PolyReadSpacing.majorSpacing),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(PolyReadSpacing.majorSpacing),
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.sectionSpacing),
          
          Text(
            'Your Library Awaits',
            style: PolyReadTypography.interfaceTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          
          Text(
            'Import PDF, EPUB, HTML, or TXT files\nto begin your reading journey',
            style: PolyReadTypography.interfaceBody.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          
          // Elegant import button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
              boxShadow: PolyReadSpacing.subtleShadow,
            ),
            child: ElevatedButton.icon(
              onPressed: _isImporting ? null : _importBooks,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: PolyReadSpacing.sectionSpacing,
                  vertical: PolyReadSpacing.elementSpacing,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                ),
              ),
              icon: _isImporting 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(
                _isImporting ? 'Importing...' : 'Import Books',
                style: PolyReadTypography.interfaceButton,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBookGrid(List<Book> books) {
    return Container(
      padding: PolyReadSpacing.getResponsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Library header with book count
          Padding(
            padding: const EdgeInsets.only(bottom: PolyReadSpacing.sectionSpacing),
            child: Row(
              children: [
                Text(
                  'My Books',
                  style: PolyReadTypography.interfaceHeadline.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: PolyReadSpacing.elementSpacing),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PolyReadSpacing.elementSpacing,
                    vertical: PolyReadSpacing.microSpacing,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  ),
                  child: Text(
                    '${books.length}',
                    style: PolyReadTypography.interfaceCaption.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Responsive book grid
          Expanded(
            child: _buildResponsiveGrid(books),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResponsiveGrid(List<Book> books) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive grid
        int crossAxisCount;
        double childAspectRatio;
        
        if (constraints.maxWidth > PolyReadSpacing.desktopBreakpoint) {
          crossAxisCount = 5;
          childAspectRatio = 0.7;
        } else if (constraints.maxWidth > PolyReadSpacing.tabletBreakpoint) {
          crossAxisCount = 4;
          childAspectRatio = 0.72;
        } else if (constraints.maxWidth > PolyReadSpacing.mobileBreakpoint) {
          crossAxisCount = 3;
          childAspectRatio = 0.75;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 0.7;
        }
        
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: PolyReadSpacing.bookShelfSpacing,
            mainAxisSpacing: PolyReadSpacing.bookShelfSpacing,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return _buildAnimatedBookCard(book, index);
          },
        );
      },
    );
  }
  
  Widget _buildAnimatedBookCard(Book book, int index) {
    return AnimatedContainer(
      duration: PolyReadSpacing.mediumAnimation,
      curve: PolyReadSpacing.defaultCurve,
      child: BookCard(
        book: book,
        onTap: () => _openBook(book),
        onDelete: () => _deleteBook(book),
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