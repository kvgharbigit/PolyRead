// Bookmarks Dialog
// Displays and manages bookmarks for the current book

import 'package:flutter/material.dart';
import 'package:polyread/features/reader/models/bookmark_model.dart';
import 'package:polyread/features/reader/services/bookmark_service.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';

class BookmarksDialog extends StatefulWidget {
  final int bookId;
  final String bookTitle;
  final BookmarkService bookmarkService;
  final Function(ReaderPosition) onNavigate;
  final ReaderPosition currentPosition;
  
  const BookmarksDialog({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.bookmarkService,
    required this.onNavigate,
    required this.currentPosition,
  });

  @override
  State<BookmarksDialog> createState() => _BookmarksDialogState();
}

class _BookmarksDialogState extends State<BookmarksDialog> {
  List<BookmarkModel> _bookmarks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    
    try {
      final bookmarks = _searchQuery.isEmpty
          ? await widget.bookmarkService.getBookmarks(widget.bookId)
          : await widget.bookmarkService.searchBookmarks(
              bookId: widget.bookId,
              query: _searchQuery,
            );
      
      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bookmarks: $e')),
        );
      }
    }
  }
  
  void _onSearch(String query) {
    setState(() => _searchQuery = query);
    _loadBookmarks();
  }
  
  Future<void> _deleteBookmark(BookmarkModel bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bookmark'),
        content: Text('Are you sure you want to delete "${bookmark.displayTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await widget.bookmarkService.deleteBookmark(bookmark.id);
      _loadBookmarks();
    }
  }
  
  Future<void> _editBookmark(BookmarkModel bookmark) async {
    final result = await showDialog<BookmarkModel>(
      context: context,
      builder: (context) => _EditBookmarkDialog(bookmark: bookmark),
    );
    
    if (result != null) {
      await widget.bookmarkService.updateBookmark(result);
      _loadBookmarks();
    }
  }
  
  Future<void> _addQuickBookmark() async {
    await widget.bookmarkService.addBookmark(
      bookId: widget.bookId,
      position: widget.currentPosition,
      title: null, // Will auto-generate
      isQuickBookmark: true,
    );
    _loadBookmarks();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildBookmarksList()),
            _buildActions(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.bookmark, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bookmarks',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  widget.bookTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search bookmarks...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: _onSearch,
      ),
    );
  }
  
  Widget _buildBookmarksList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No bookmarks yet'
                  : 'No bookmarks found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Tap the bookmark button while reading to save your place'
                  : 'Try a different search term',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        return _buildBookmarkCard(bookmark);
      },
    );
  }
  
  Widget _buildBookmarkCard(BookmarkModel bookmark) {
    final isCurrentPosition = bookmark.position == widget.currentPosition;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentPosition ? 3 : 1,
      color: isCurrentPosition 
          ? Theme.of(context).primaryColor.withOpacity(0.1)
          : null,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bookmark.color.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: bookmark.color.color,
              width: isCurrentPosition ? 2 : 1,
            ),
          ),
          child: Icon(
            bookmark.icon.iconData,
            color: bookmark.color.color,
            size: 20,
          ),
        ),
        title: Text(
          bookmark.displayTitle,
          style: TextStyle(
            fontWeight: isCurrentPosition ? FontWeight.bold : FontWeight.normal,
            color: isCurrentPosition ? Theme.of(context).primaryColor : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bookmark.positionDescription),
            if (bookmark.hasNote) ...[
              const SizedBox(height: 4),
              Text(
                bookmark.note!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (bookmark.hasExcerpt) ...[
              const SizedBox(height: 4),
              Text(
                bookmark.excerpt!,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  bookmark.formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (bookmark.isQuickBookmark) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Quick',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
                if (isCurrentPosition) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editBookmark(bookmark);
                break;
              case 'delete':
                _deleteBookmark(bookmark);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () {
          widget.onNavigate(bookmark.position);
          Navigator.of(context).pop();
        },
      ),
    );
  }
  
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_bookmarks.length} bookmark${_bookmarks.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _addQuickBookmark,
                icon: const Icon(Icons.add),
                label: const Text('Add Here'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditBookmarkDialog extends StatefulWidget {
  final BookmarkModel bookmark;
  
  const _EditBookmarkDialog({required this.bookmark});

  @override
  State<_EditBookmarkDialog> createState() => _EditBookmarkDialogState();
}

class _EditBookmarkDialogState extends State<_EditBookmarkDialog> {
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  late BookmarkColor _selectedColor;
  late BookmarkIcon _selectedIcon;
  
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bookmark.title);
    _noteController = TextEditingController(text: widget.bookmark.note);
    _selectedColor = widget.bookmark.color;
    _selectedIcon = widget.bookmark.icon;
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Bookmark'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Color selection
            Text(
              'Color',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: BookmarkColor.values.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.color.withOpacity(0.3),
                      border: Border.all(
                        color: color.color,
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: color.color, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Icon selection
            Text(
              'Icon',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: BookmarkIcon.values.map((icon) {
                final isSelected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).primaryColor.withOpacity(0.2)
                          : Colors.grey.shade100,
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon.iconData,
                      color: isSelected 
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final updatedBookmark = widget.bookmark.copyWith(
              title: _titleController.text.trim().isEmpty
                  ? null
                  : _titleController.text.trim(),
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              color: _selectedColor,
              icon: _selectedIcon,
            );
            Navigator.of(context).pop(updatedBookmark);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}