// Adaptive Table of Contents Dialog
// Provides format-specific navigation while maintaining consistent UI

import 'package:flutter/material.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';
import 'package:polyread/features/reader/engines/epub_reader_engine.dart';
import 'package:polyread/features/reader/engines/pdf_reader_engine.dart';
import 'package:polyread/features/reader/engines/html_reader_engine.dart';
import 'package:polyread/features/reader/engines/txt_reader_engine.dart';

class TableOfContentsDialog extends StatelessWidget {
  final ReaderEngine readerEngine;
  final Function(ReaderPosition) onNavigate;
  
  const TableOfContentsDialog({
    super.key,
    required this.readerEngine,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    String title;
    IconData icon;
    
    // Adapt header based on format
    if (readerEngine is EpubReaderEngine) {
      title = 'Chapters';
      icon = Icons.menu_book;
    } else if (readerEngine is PdfReaderEngine) {
      title = 'Pages';
      icon = Icons.picture_as_pdf;
    } else if (readerEngine is HtmlReaderEngine) {
      title = 'Sections';
      icon = Icons.web;
    } else {
      title = 'Navigation';
      icon = Icons.list;
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
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
  
  Widget _buildContent(BuildContext context) {
    if (readerEngine is EpubReaderEngine) {
      return _buildEpubChapters(context);
    } else if (readerEngine is PdfReaderEngine) {
      return _buildPdfPages(context);
    } else if (readerEngine is HtmlReaderEngine) {
      return _buildHtmlSections(context);
    } else if (readerEngine is TxtReaderEngine) {
      return _buildTxtSections(context);
    } else {
      return _buildFallbackNavigation(context);
    }
  }
  
  Widget _buildEpubChapters(BuildContext context) {
    final epubEngine = readerEngine as EpubReaderEngine;
    final chapters = epubEngine.chapters;
    
    if (chapters == null || chapters.isEmpty) {
      return const Center(child: Text('No chapters available'));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final isActive = epubEngine.currentPosition.chapterId == chapter.Title;
        
        return _buildNavigationTile(
          context: context,
          title: chapter.Title ?? 'Chapter ${index + 1}',
          subtitle: chapter.SubChapters?.isNotEmpty == true 
              ? '${chapter.SubChapters!.length} sections'
              : null,
          index: index + 1,
          isActive: isActive,
          icon: Icons.article_outlined,
          onTap: () => _navigateAndClose(context, ReaderPosition.epub(chapter.Title ?? '')),
        );
      },
    );
  }
  
  Widget _buildPdfPages(BuildContext context) {
    final pdfEngine = readerEngine as PdfReaderEngine;
    final totalPages = pdfEngine.totalPages;
    final currentPage = pdfEngine.currentPosition.pageNumber ?? 1;
    
    // Create page groups for better navigation
    final pageGroups = _createPageGroups(totalPages, currentPage);
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: pageGroups.length,
      itemBuilder: (context, index) {
        final group = pageGroups[index];
        
        return _buildPageGroupTile(
          context: context,
          group: group,
          currentPage: currentPage,
        );
      },
    );
  }
  
  Widget _buildHtmlSections(BuildContext context) {
    final htmlEngine = readerEngine as HtmlReaderEngine;
    
    // Generate sections based on HTML headings
    final sections = _generateHtmlSections(htmlEngine);
    
    if (sections.isEmpty) {
      return _buildSimplePageNavigation(context, htmlEngine.totalPages);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final isActive = false; // TODO: Implement current section detection
        
        return _buildNavigationTile(
          context: context,
          title: section.title,
          subtitle: 'Section ${index + 1}',
          index: index + 1,
          isActive: isActive,
          icon: Icons.web_outlined,
          onTap: () => _navigateAndClose(context, section.position),
        );
      },
    );
  }
  
  Widget _buildTxtSections(BuildContext context) {
    final txtEngine = readerEngine as TxtReaderEngine;
    
    // Generate sections based on text content (paragraphs, line breaks, etc.)
    final sections = _generateTxtSections(txtEngine);
    
    if (sections.isEmpty) {
      return _buildSimplePageNavigation(context, txtEngine.totalPages);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final isActive = false; // TODO: Implement current section detection
        
        return _buildNavigationTile(
          context: context,
          title: section.title,
          subtitle: 'Section ${index + 1}',
          index: index + 1,
          isActive: isActive,
          icon: Icons.text_snippet_outlined,
          onTap: () => _navigateAndClose(context, section.position),
        );
      },
    );
  }
  
  Widget _buildNavigationTile({
    required BuildContext context,
    required String title,
    String? subtitle,
    required int index,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: isActive ? 3 : 1,
      color: isActive ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: isActive 
              ? Theme.of(context).primaryColor
              : Theme.of(context).primaryColor.withOpacity(0.2),
          child: isActive
              ? Icon(Icons.play_arrow, size: 16, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Theme.of(context).primaryColor : null,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Icon(
          Icons.chevron_right, 
          color: isActive ? Theme.of(context).primaryColor : Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
  
  Widget _buildPageGroupTile({
    required BuildContext context,
    required PageGroup group,
    required int currentPage,
  }) {
    final isActiveGroup = currentPage >= group.startPage && currentPage <= group.endPage;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: isActiveGroup ? 3 : 1,
      color: isActiveGroup ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      child: ExpansionTile(
        leading: Icon(
          Icons.folder_outlined,
          color: isActiveGroup ? Theme.of(context).primaryColor : Colors.grey,
        ),
        title: Text(
          group.title,
          style: TextStyle(
            fontWeight: isActiveGroup ? FontWeight.bold : FontWeight.normal,
            color: isActiveGroup ? Theme.of(context).primaryColor : null,
          ),
        ),
        subtitle: Text('${group.endPage - group.startPage + 1} pages'),
        children: List.generate(
          group.endPage - group.startPage + 1,
          (pageIndex) {
            final pageNumber = group.startPage + pageIndex;
            final isCurrentPage = pageNumber == currentPage;
            
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              leading: CircleAvatar(
                radius: 12,
                backgroundColor: isCurrentPage 
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).primaryColor.withOpacity(0.2),
                child: isCurrentPage
                    ? const Icon(Icons.play_arrow, size: 12, color: Colors.white)
                    : Text(
                        '$pageNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
              ),
              title: Text(
                'Page $pageNumber',
                style: TextStyle(
                  fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                  color: isCurrentPage ? Theme.of(context).primaryColor : null,
                ),
              ),
              onTap: () => _navigateAndClose(context, ReaderPosition.pdf(pageNumber)),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildSimplePageNavigation(BuildContext context, int totalPages) {
    final currentPageNumber = readerEngine.currentPosition.pageNumber ?? 1;
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: totalPages,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final isActive = pageNumber == currentPageNumber;
        
        return _buildNavigationTile(
          context: context,
          title: 'Page $pageNumber',
          subtitle: null,
          index: pageNumber,
          isActive: isActive,
          icon: Icons.description_outlined,
          onTap: () => _navigateAndClose(context, ReaderPosition.pdf(pageNumber)),
        );
      },
    );
  }
  
  Widget _buildFallbackNavigation(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Navigation not available',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Use the bottom controls to navigate',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
  
  void _navigateAndClose(BuildContext context, ReaderPosition position) {
    onNavigate(position);
    Navigator.of(context).pop();
  }
  
  List<PageGroup> _createPageGroups(int totalPages, int currentPage) {
    const pagesPerGroup = 10;
    final groups = <PageGroup>[];
    
    for (int i = 1; i <= totalPages; i += pagesPerGroup) {
      final endPage = (i + pagesPerGroup - 1).clamp(1, totalPages);
      final isActive = currentPage >= i && currentPage <= endPage;
      
      groups.add(PageGroup(
        title: i == endPage ? 'Page $i' : 'Pages $i - $endPage',
        startPage: i,
        endPage: endPage,
        isActive: isActive,
      ));
    }
    
    return groups;
  }
  
  List<NavigationSection> _generateHtmlSections(HtmlReaderEngine engine) {
    // TODO: Implement HTML heading extraction
    // For now, return empty list to fall back to simple page navigation
    return [];
  }
  
  List<NavigationSection> _generateTxtSections(TxtReaderEngine engine) {
    // TODO: Implement text section detection (double line breaks, etc.)
    // For now, return empty list to fall back to simple page navigation
    return [];
  }
}

class PageGroup {
  final String title;
  final int startPage;
  final int endPage;
  final bool isActive;
  
  const PageGroup({
    required this.title,
    required this.startPage,
    required this.endPage,
    this.isActive = false,
  });
}

class NavigationSection {
  final String title;
  final ReaderPosition position;
  
  const NavigationSection({
    required this.title,
    required this.position,
  });
}