// Book Card Widget
// Displays a book in the library grid with elegant PolyRead design

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polyread/core/database/app_database.dart';
import 'package:polyread/core/themes/polyread_spacing.dart';
import 'package:polyread/core/themes/polyread_typography.dart';
import 'package:polyread/core/themes/polyread_theme.dart';
import 'package:polyread/core/utils/constants.dart';

class BookCard extends StatefulWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  
  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> 
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _tapScaleAnimation;
  
  bool _isHovered = false;
  
  @override
  void initState() {
    super.initState();
    
    _hoverController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );
    
    _tapController = AnimationController(
      duration: AppConstants.microAnimation,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: AppConstants.elegantCurve,
    ));
    
    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: AppConstants.smoothCurve,
    ));
    
    _tapScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _tapController,
      curve: AppConstants.smoothCurve,
    ));
  }
  
  @override
  void dispose() {
    _hoverController.dispose();
    _tapController.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    _tapController.forward();
  }
  
  void _handleTapUp(TapUpDetails details) {
    _tapController.reverse();
    widget.onTap();
  }
  
  void _handleTapCancel() {
    _tapController.reverse();
  }
  
  void _handleHoverEnter(PointerEnterEvent event) {
    setState(() => _isHovered = true);
    _hoverController.forward();
  }
  
  void _handleHoverExit(PointerExitEvent event) {
    setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _tapScaleAnimation, _elevationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _tapScaleAnimation.value,
          child: MouseRegion(
            onEnter: _handleHoverEnter,
            onExit: _handleHoverExit,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PolyReadSpacing.bookCoverRadius),
                color: Theme.of(context).cardColor,
                boxShadow: [
                  // Enhanced shadow that responds to hover
                  ...PolyReadSpacing.bookShadow.map((shadow) => BoxShadow(
                    color: shadow.color,
                    blurRadius: shadow.blurRadius * (1.0 + _elevationAnimation.value * 0.5),
                    offset: shadow.offset * (1.0 + _elevationAnimation.value * 0.3),
                    spreadRadius: shadow.spreadRadius + (_elevationAnimation.value * 2),
                  )).toList(),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PolyReadSpacing.bookCoverRadius),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Book cover (75% of card height for book-like proportions)
                        Expanded(
                          flex: 3,
                          child: _buildElegantCover(),
                        ),
                        
                        // Book info (25% of card height)
                        Container(
                          height: 74,
                          padding: const EdgeInsets.all(PolyReadSpacing.elementSpacing),
                          child: _buildBookInfo(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildElegantCover() {
    // Try to show book cover if available
    if (widget.book.coverImagePath != null) {
      final coverFile = File(widget.book.coverImagePath!);
      if (coverFile.existsSync()) {
        return Hero(
          tag: 'book_cover_${widget.book.id}',
          child: AnimatedContainer(
            duration: AppConstants.mediumAnimation,
            curve: AppConstants.elegantCurve,
            child: Image.file(
              coverFile,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
            ),
          ),
        );
      }
    }
    
    return _buildDefaultCover();
  }
  
  Widget _buildDefaultCover() {
    return Hero(
      tag: 'book_cover_${widget.book.id}',
      child: AnimatedContainer(
        duration: AppConstants.mediumAnimation,
        curve: AppConstants.elegantCurve,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getFileTypeColor().withValues(alpha: 0.15),
              _getFileTypeColor().withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: AppConstants.mediumAnimation,
              tween: Tween(begin: 0.8, end: 1.0),
              curve: AppConstants.bouncyCurve,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(PolyReadSpacing.elementSpacing),
                    decoration: BoxDecoration(
                      color: _getFileTypeColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                    ),
                    child: Icon(
                      _getFileTypeIcon(),
                      size: 40,
                      color: _getFileTypeColor(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: PolyReadSpacing.smallSpacing),
            Text(
              widget.book.fileType.toUpperCase(),
              style: PolyReadTypography.interfaceCaption.copyWith(
                color: _getFileTypeColor(),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build book information section with PolyRead typography
  Widget _buildBookInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title - using Flexible instead of Expanded to avoid overflow
        Flexible(
          child: Text(
            widget.book.title,
            style: PolyReadTypography.interfaceBody.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: widget.book.author != null ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        if (widget.book.author != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.book.author!,
            style: PolyReadTypography.interfaceCaption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: PolyReadSpacing.microSpacing),
        ] else
          const SizedBox(height: PolyReadSpacing.microSpacing),
        
        // File type and actions row
        Row(
          children: [
            // Elegant file type badge
            _buildFileTypeBadge(context),
            const Spacer(),
            // Elegant delete button
            _buildDeleteButton(context),
          ],
        ),
      ],
    );
  }
  
  /// Build elegant file type badge
  Widget _buildFileTypeBadge(BuildContext context) {
    return AnimatedContainer(
      duration: AppConstants.shortAnimation,
      curve: AppConstants.elegantCurve,
      padding: const EdgeInsets.symmetric(
        horizontal: PolyReadSpacing.smallSpacing,
        vertical: PolyReadSpacing.microSpacing,
      ),
      decoration: BoxDecoration(
        color: _getFileTypeColor().withValues(alpha: _isHovered ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(PolyReadSpacing.microSpacing),
        border: Border.all(
          color: _getFileTypeColor().withValues(alpha: _isHovered ? 0.5 : 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        widget.book.fileType.toUpperCase(),
        style: PolyReadTypography.interfaceCaption.copyWith(
          color: _getFileTypeColor(),
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  /// Build elegant delete button
  Widget _buildDeleteButton(BuildContext context) {
    return AnimatedContainer(
      duration: AppConstants.shortAnimation,
      curve: AppConstants.elegantCurve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PolyReadSpacing.microSpacing),
        color: _isHovered 
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onDelete,
          borderRadius: BorderRadius.circular(PolyReadSpacing.microSpacing),
          child: Padding(
            padding: const EdgeInsets.all(PolyReadSpacing.microSpacing),
            child: AnimatedOpacity(
              duration: AppConstants.shortAnimation,
              opacity: _isHovered ? 1.0 : 0.7,
              child: Icon(
                Icons.more_vert,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getFileTypeColor() {
    switch (widget.book.fileType.toLowerCase()) {
      case 'pdf':
        return PolyReadTheme.colors.errorRed;
      case 'epub':
        return PolyReadTheme.colors.linkBlue;
      case 'html':
      case 'htm':
        return PolyReadTheme.colors.successGreen;
      case 'txt':
        return PolyReadTheme.colors.warmAccent;
      default:
        return PolyReadTheme.colors.warmAccent;
    }
  }
  
  IconData _getFileTypeIcon() {
    switch (widget.book.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'epub':
        return Icons.menu_book;
      default:
        return Icons.insert_drive_file;
    }
  }
}