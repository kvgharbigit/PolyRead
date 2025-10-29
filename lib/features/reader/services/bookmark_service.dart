// Bookmark Service
// Manages bookmarks with database persistence using Drift
import 'package:drift/drift.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/models/bookmark_model.dart';

class BookmarkService {
  final AppDatabase _database;
  
  BookmarkService(this._database);
  
  /// Add a bookmark at the current position
  Future<int> addBookmark({
    required int bookId,
    required ReaderPosition position,
    String? title,
    String? note,
    String? excerpt,
    BookmarkColor color = BookmarkColor.blue,
    BookmarkIcon icon = BookmarkIcon.bookmark,
    bool isQuickBookmark = false,
  }) async {
    final bookmarksCompanion = BookmarksCompanion.insert(
      bookId: bookId,
      position: position.toJsonString(),
      title: Value(title),
      note: Value(note),
      excerpt: Value(excerpt),
      color: Value(color.name),
      icon: Value(icon.name),
      isQuickBookmark: Value(isQuickBookmark),
      sortOrder: Value(await _getNextSortOrder(bookId)),
    );
    
    return await _database.into(_database.bookmarks).insert(bookmarksCompanion);
  }
  
  /// Get all bookmarks for a book
  Future<List<BookmarkModel>> getBookmarks(int bookId) async {
    final query = _database.select(_database.bookmarks)
      ..where((b) => b.bookId.equals(bookId))
      ..orderBy([
        (b) => OrderingTerm(expression: b.sortOrder),
        (b) => OrderingTerm(expression: b.createdAt),
      ]);
    
    final results = await query.get();
    return results.map((row) => BookmarkModel.fromRow(row)).toList();
  }
  
  /// Get recent bookmarks across all books
  Future<List<BookmarkModel>> getRecentBookmarks({int limit = 10}) async {
    final query = _database.select(_database.bookmarks)
      ..orderBy([
        (b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    
    final results = await query.get();
    return results.map((row) => BookmarkModel.fromRow(row)).toList();
  }
  
  /// Update bookmark
  Future<bool> updateBookmark(BookmarkModel bookmark) async {
    final companion = BookmarksCompanion(
      id: Value(bookmark.id),
      title: Value(bookmark.title),
      note: Value(bookmark.note),
      excerpt: Value(bookmark.excerpt),
      color: Value(bookmark.color.name),
      icon: Value(bookmark.icon.name),
      sortOrder: Value(bookmark.sortOrder),
      lastAccessedAt: Value(DateTime.now()),
    );
    
    final rowsAffected = await (_database.update(_database.bookmarks)
      ..where((b) => b.id.equals(bookmark.id))).write(companion);
    
    return rowsAffected > 0;
  }
  
  /// Delete bookmark
  Future<bool> deleteBookmark(int bookmarkId) async {
    final rowsAffected = await (_database.delete(_database.bookmarks)
      ..where((b) => b.id.equals(bookmarkId))).go();
    
    return rowsAffected > 0;
  }
  
  /// Check if a position is bookmarked
  Future<BookmarkModel?> getBookmarkAt({
    required int bookId,
    required ReaderPosition position,
  }) async {
    final query = _database.select(_database.bookmarks)
      ..where((b) => 
        b.bookId.equals(bookId) & 
        b.position.equals(position.toJsonString())
      );
    
    final result = await query.getSingleOrNull();
    return result != null ? BookmarkModel.fromRow(result) : null;
  }
  
  /// Toggle bookmark at position (add if doesn't exist, remove if exists)
  Future<BookmarkToggleResult> toggleBookmark({
    required int bookId,
    required ReaderPosition position,
    String? title,
    String? excerpt,
  }) async {
    final existingBookmark = await getBookmarkAt(
      bookId: bookId,
      position: position,
    );
    
    if (existingBookmark != null) {
      // Remove existing bookmark
      await deleteBookmark(existingBookmark.id);
      return BookmarkToggleResult(
        wasAdded: false,
        bookmark: existingBookmark,
      );
    } else {
      // Add new bookmark
      final bookmarkId = await addBookmark(
        bookId: bookId,
        position: position,
        title: title ?? _generateDefaultTitle(position),
        excerpt: excerpt,
        isQuickBookmark: true,
      );
      
      final newBookmark = await _getBookmarkById(bookmarkId);
      return BookmarkToggleResult(
        wasAdded: true,
        bookmark: newBookmark!,
      );
    }
  }
  
  /// Reorder bookmarks
  Future<void> reorderBookmarks(List<BookmarkModel> bookmarks) async {
    await _database.transaction(() async {
      for (int i = 0; i < bookmarks.length; i++) {
        final bookmark = bookmarks[i];
        await (_database.update(_database.bookmarks)
          ..where((b) => b.id.equals(bookmark.id)))
          .write(BookmarksCompanion(
            sortOrder: Value(i),
          ));
      }
    });
  }
  
  /// Get bookmark statistics for a book
  Future<BookmarkStats> getBookmarkStats(int bookId) async {
    final bookmarks = await getBookmarks(bookId);
    
    final totalCount = bookmarks.length;
    final quickBookmarkCount = bookmarks.where((b) => b.isQuickBookmark).length;
    final userBookmarkCount = totalCount - quickBookmarkCount;
    
    final colorCounts = <BookmarkColor, int>{};
    for (final bookmark in bookmarks) {
      colorCounts[bookmark.color] = (colorCounts[bookmark.color] ?? 0) + 1;
    }
    
    return BookmarkStats(
      totalCount: totalCount,
      userBookmarkCount: userBookmarkCount,
      quickBookmarkCount: quickBookmarkCount,
      colorCounts: colorCounts,
      lastBookmarkDate: bookmarks.isNotEmpty ? bookmarks.first.createdAt : null,
    );
  }
  
  /// Search bookmarks by title or note
  Future<List<BookmarkModel>> searchBookmarks({
    required int bookId,
    required String query,
  }) async {
    final dbQuery = _database.select(_database.bookmarks)
      ..where((b) => 
        b.bookId.equals(bookId) & 
        (b.title.like('%$query%') | 
         b.note.like('%$query%') |
         b.excerpt.like('%$query%')));
    
    final results = await dbQuery.get();
    
    return results.map((row) => BookmarkModel.fromRow(row)).toList();
  }
  
  /// Import bookmarks from another format
  Future<void> importBookmarks(List<BookmarkModel> bookmarks) async {
    await _database.transaction(() async {
      for (final bookmark in bookmarks) {
        await addBookmark(
          bookId: bookmark.bookId,
          position: bookmark.position,
          title: bookmark.title,
          note: bookmark.note,
          excerpt: bookmark.excerpt,
          color: bookmark.color,
          icon: bookmark.icon,
          isQuickBookmark: bookmark.isQuickBookmark,
        );
      }
    });
  }
  
  /// Export bookmarks for a book
  Future<List<BookmarkModel>> exportBookmarks(int bookId) async {
    return await getBookmarks(bookId);
  }
  
  // Private helper methods
  
  Future<int> _getNextSortOrder(int bookId) async {
    final maxSortOrder = await _database
      .selectOnly(_database.bookmarks)
      ..addColumns([_database.bookmarks.sortOrder.max()])
      ..where(_database.bookmarks.bookId.equals(bookId));
    
    final result = await maxSortOrder.getSingleOrNull();
    final currentMax = result?.read(_database.bookmarks.sortOrder.max()) ?? 0;
    return currentMax + 1;
  }
  
  Future<BookmarkModel?> _getBookmarkById(int bookmarkId) async {
    final result = await (_database.select(_database.bookmarks)
      ..where((b) => b.id.equals(bookmarkId))).getSingleOrNull();
    
    return result != null ? BookmarkModel.fromRow(result) : null;
  }
  
  String _generateDefaultTitle(ReaderPosition position) {
    if (position.pageNumber != null) {
      return 'Page ${position.pageNumber}';
    } else if (position.chapterId != null) {
      return position.chapterId!;
    } else {
      return 'Bookmark';
    }
  }
}

class BookmarkToggleResult {
  final bool wasAdded;
  final BookmarkModel bookmark;
  
  const BookmarkToggleResult({
    required this.wasAdded,
    required this.bookmark,
  });
}

class BookmarkStats {
  final int totalCount;
  final int userBookmarkCount;
  final int quickBookmarkCount;
  final Map<BookmarkColor, int> colorCounts;
  final DateTime? lastBookmarkDate;
  
  const BookmarkStats({
    required this.totalCount,
    required this.userBookmarkCount,
    required this.quickBookmarkCount,
    required this.colorCounts,
    this.lastBookmarkDate,
  });
}