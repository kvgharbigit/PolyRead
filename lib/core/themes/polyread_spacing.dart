// PolyRead Spacing & Layout System
// Reading-optimized spacing, shadows, and layout constants

import 'package:flutter/material.dart';

/// Spacing and layout system optimized for reading experience
class PolyReadSpacing {
  // Prevent instantiation
  PolyReadSpacing._();

  /// Reading Content Spacing
  /// Optimized for comfortable reading on different screen sizes
  
  static const double readingMarginPhone = 24.0;
  static const double readingMarginTablet = 64.0;
  static const double readingMarginDesktop = 120.0;
  
  static const double readingLineSpacing = 1.6;
  static const double readingParagraphSpacing = 24.0;
  static const double readingChapterSpacing = 48.0;
  
  /// Calculate responsive reading margins
  static double getReadingMargin(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      return readingMarginDesktop;
    } else if (screenWidth > 600) {
      return readingMarginTablet;
    } else {
      return readingMarginPhone;
    }
  }

  /// UI Element Spacing
  /// For interface components like cards, buttons, sections
  
  static const double microSpacing = 4.0;
  static const double smallSpacing = 8.0;
  static const double elementSpacing = 16.0;
  static const double sectionSpacing = 24.0;
  static const double pageSpacing = 32.0;
  static const double majorSpacing = 48.0;
  
  /// Card and Component Dimensions
  static const double cardPadding = 20.0;
  static const double cardRadius = 12.0;
  static const double dialogRadius = 16.0;
  static const double buttonRadius = 8.0;
  static const double inputRadius = 8.0;
  
  /// Book-specific dimensions
  static const double bookCardAspectRatio = 2.4 / 3.6; // Typical book proportions
  static const double bookCoverRadius = 8.0;
  static const double bookShelfSpacing = 24.0;
  
  /// Progress and UI element dimensions
  static const double progressBarHeight = 4.0;
  static const double iconButtonSize = 48.0;
  static const double minTouchTarget = 44.0; // Accessibility requirement
  
  /// Shadow System
  /// Subtle, book-like shadows instead of Material elevation
  
  static List<BoxShadow> get noShadow => [];
  
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 30,
      offset: const Offset(0, 15),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 6,
      offset: const Offset(0, 3),
    ),
  ];

  /// Book-like shadows for cards and covers
  static List<BoxShadow> get bookShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  /// Paper-like shadow for reading surfaces
  static List<BoxShadow> get paperShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  /// Layout Constants
  static const EdgeInsets contentPadding = EdgeInsets.all(elementSpacing);
  static const EdgeInsets sectionPadding = EdgeInsets.all(sectionSpacing);
  static const EdgeInsets pagePadding = EdgeInsets.all(pageSpacing);
  
  static const EdgeInsets cardContentPadding = EdgeInsets.all(cardPadding);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: elementSpacing,
    vertical: smallSpacing,
  );
  
  /// Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  
  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > desktopBreakpoint) {
      return const EdgeInsets.all(majorSpacing);
    } else if (screenWidth > tabletBreakpoint) {
      return const EdgeInsets.all(pageSpacing);
    } else {
      return const EdgeInsets.all(sectionSpacing);
    }
  }
  
  /// Get responsive book card size
  static Size getBookCardSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    late double cardWidth;
    
    if (screenWidth > desktopBreakpoint) {
      cardWidth = 180;
    } else if (screenWidth > tabletBreakpoint) {
      cardWidth = 160;
    } else if (screenWidth > mobileBreakpoint) {
      cardWidth = 140;
    } else {
      cardWidth = 120;
    }
    
    final cardHeight = cardWidth / bookCardAspectRatio;
    return Size(cardWidth, cardHeight);
  }
  
  /// Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 250);
  static const Duration longAnimation = Duration(milliseconds: 400);
  static const Duration pageTransition = Duration(milliseconds: 300);
  
  /// Animation Curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve sharpCurve = Curves.easeOutQuart;
  static const Curve gentleCurve = Curves.easeOut;
  static const Curve springCurve = Curves.elasticOut;
}

/// Extension for easy spacing access
extension PolyReadSpacingExtension on BuildContext {
  /// Get PolyRead spacing helper
  PolyReadSpacingHelper get spacing => PolyReadSpacingHelper(this);
}

/// Helper class for context-aware spacing
class PolyReadSpacingHelper {
  final BuildContext context;
  
  const PolyReadSpacingHelper(this.context);
  
  /// Responsive reading margin
  double get readingMargin => PolyReadSpacing.getReadingMargin(context);
  
  /// Responsive padding
  EdgeInsets get responsivePadding => PolyReadSpacing.getResponsivePadding(context);
  
  /// Responsive book card size
  Size get bookCardSize => PolyReadSpacing.getBookCardSize(context);
  
  /// Screen type detection
  bool get isMobile => MediaQuery.of(context).size.width < PolyReadSpacing.mobileBreakpoint;
  bool get isTablet => MediaQuery.of(context).size.width >= PolyReadSpacing.mobileBreakpoint && 
                     MediaQuery.of(context).size.width < PolyReadSpacing.desktopBreakpoint;
  bool get isDesktop => MediaQuery.of(context).size.width >= PolyReadSpacing.desktopBreakpoint;
}

/// Common layout patterns for PolyRead
class PolyReadLayouts {
  // Prevent instantiation
  PolyReadLayouts._();
  
  /// Standard page layout with responsive padding
  static Widget page({
    required BuildContext context,
    required Widget child,
    EdgeInsets? padding,
  }) {
    return Padding(
      padding: padding ?? PolyReadSpacing.getResponsivePadding(context),
      child: child,
    );
  }
  
  /// Card layout with book-like shadow
  static Widget card({
    required Widget child,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    Color? color,
    List<BoxShadow>? shadow,
  }) {
    return Container(
      padding: padding ?? PolyReadSpacing.cardContentPadding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(PolyReadSpacing.cardRadius),
        boxShadow: shadow ?? PolyReadSpacing.cardShadow,
      ),
      child: child,
    );
  }
  
  /// Section with proper spacing
  static Widget section({
    required String title,
    required Widget child,
    EdgeInsets? padding,
    TextStyle? titleStyle,
  }) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: PolyReadSpacing.sectionSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: titleStyle),
            const SizedBox(height: PolyReadSpacing.elementSpacing),
          ],
          child,
        ],
      ),
    );
  }
}