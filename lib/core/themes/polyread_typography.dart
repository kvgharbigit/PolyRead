// PolyRead Typography System
// Reading-optimized font hierarchy using Google Fonts

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system optimized for reading and premium UI experience
class PolyReadTypography {
  // Prevent instantiation
  PolyReadTypography._();

  /// Reading Content Typography
  /// Optimized for long-form reading comfort
  
  static TextStyle get readingBody => GoogleFonts.literata(
    fontSize: 18,
    height: 1.6,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get readingBodyLarge => GoogleFonts.literata(
    fontSize: 22,
    height: 1.6,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get readingBodySmall => GoogleFonts.literata(
    fontSize: 16,
    height: 1.5,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get readingHeadline => GoogleFonts.literata(
    fontSize: 28,
    height: 1.4,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get readingSubheadline => GoogleFonts.literata(
    fontSize: 24,
    height: 1.4,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w500,
  );

  /// Interface Typography
  /// Clean sans-serif for UI elements, navigation, and controls

  static TextStyle get interfaceTitle => GoogleFonts.inter(
    fontSize: 24,
    height: 1.3,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get interfaceHeadline => GoogleFonts.inter(
    fontSize: 20,
    height: 1.3,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get interfaceSubheadline => GoogleFonts.inter(
    fontSize: 18,
    height: 1.3,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get interfaceBody => GoogleFonts.inter(
    fontSize: 16,
    height: 1.4,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get interfaceBodyMedium => GoogleFonts.inter(
    fontSize: 14,
    height: 1.4,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get interfaceCaption => GoogleFonts.inter(
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get interfaceLabel => GoogleFonts.inter(
    fontSize: 14,
    height: 1.3,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get interfaceButton => GoogleFonts.inter(
    fontSize: 16,
    height: 1.2,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w500,
  );

  /// Translation Typography
  /// Specialized styles for translation popups and language learning

  static TextStyle get translationWord => GoogleFonts.inter(
    fontSize: 18,
    height: 1.3,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get translationMeaning => GoogleFonts.inter(
    fontSize: 16,
    height: 1.4,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get translationContext => GoogleFonts.inter(
    fontSize: 14,
    height: 1.4,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
  );

  static TextStyle get translationLanguagePair => GoogleFonts.inter(
    fontSize: 12,
    height: 1.2,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w700,
  );

  /// Create complete TextTheme for Flutter Theme system
  static TextTheme getTextTheme(Brightness brightness) {
    return TextTheme(
      // Display styles (largest)
      displayLarge: readingHeadline,
      displayMedium: readingSubheadline,
      displaySmall: interfaceTitle,

      // Headline styles
      headlineLarge: interfaceTitle,
      headlineMedium: interfaceHeadline,
      headlineSmall: interfaceSubheadline,

      // Title styles
      titleLarge: interfaceSubheadline,
      titleMedium: interfaceBody,
      titleSmall: interfaceLabel,

      // Body styles (main content)
      bodyLarge: readingBody,
      bodyMedium: interfaceBody,
      bodySmall: interfaceBodyMedium,

      // Label styles (buttons, form labels)
      labelLarge: interfaceButton,
      labelMedium: interfaceLabel,
      labelSmall: interfaceCaption,
    );
  }

  /// Font scales for user customization
  static const Map<String, double> fontScales = {
    'small': 0.85,
    'normal': 1.0,
    'large': 1.15,
    'extraLarge': 1.3,
  };

  /// Apply font scale to reading styles
  static TextStyle scaleReadingStyle(TextStyle style, double scale) {
    return style.copyWith(
      fontSize: (style.fontSize ?? 16) * scale,
    );
  }

  /// Get reading style with user's preferred scale
  static TextStyle getScaledReadingBody(double scale) {
    return scaleReadingStyle(readingBody, scale);
  }

  static TextStyle getScaledReadingBodyLarge(double scale) {
    return scaleReadingStyle(readingBodyLarge, scale);
  }

  /// Font family fallbacks for different platforms
  static const List<String> readingFontFallbacks = [
    'Literata',
    'Source Serif Pro',
    'Georgia',
    'Times New Roman',
    'serif',
  ];

  static const List<String> interfaceFontFallbacks = [
    'Inter',
    'SF Pro Display',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  /// Alternative reading fonts for user preference
  static Map<String, TextStyle Function()> readingFontOptions = {
    'Literata': () => readingBody, // Default
    'Source Serif Pro': () => GoogleFonts.sourceSerifPro(
      fontSize: 18,
      height: 1.6,
      letterSpacing: 0.2,
      fontWeight: FontWeight.w400,
    ),
    'Crimson Text': () => GoogleFonts.crimsonText(
      fontSize: 18,
      height: 1.6,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w400,
    ),
    'Lora': () => GoogleFonts.lora(
      fontSize: 18,
      height: 1.6,
      letterSpacing: 0.0,
      fontWeight: FontWeight.w400,
    ),
    'Merriweather': () => GoogleFonts.merriweather(
      fontSize: 17,
      height: 1.7,
      letterSpacing: 0.0,
      fontWeight: FontWeight.w400,
    ),
  };

  /// Get reading font by name
  static TextStyle getReadingFont(String fontName, {double? fontSize, double? height}) {
    final fontFactory = readingFontOptions[fontName] ?? readingFontOptions['Literata']!;
    final baseStyle = fontFactory();
    
    return baseStyle.copyWith(
      fontSize: fontSize ?? baseStyle.fontSize,
      height: height ?? baseStyle.height,
    );
  }
}

/// Extension for easy access to PolyRead typography from BuildContext
extension PolyReadTypographyExtension on BuildContext {
  /// Get PolyRead typography styles
  PolyReadTypographyHelper get polyReadTypography => PolyReadTypographyHelper(this);
}

/// Helper class for accessing typography with theme colors
class PolyReadTypographyHelper {
  final BuildContext context;
  
  const PolyReadTypographyHelper(this.context);

  // Reading styles with theme colors
  TextStyle get readingBody => PolyReadTypography.readingBody.copyWith(
    color: Theme.of(context).colorScheme.onBackground,
  );

  TextStyle get readingBodyLarge => PolyReadTypography.readingBodyLarge.copyWith(
    color: Theme.of(context).colorScheme.onBackground,
  );

  TextStyle get readingHeadline => PolyReadTypography.readingHeadline.copyWith(
    color: Theme.of(context).colorScheme.onBackground,
  );

  // Interface styles with theme colors
  TextStyle get interfaceTitle => PolyReadTypography.interfaceTitle.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  );

  TextStyle get interfaceHeadline => PolyReadTypography.interfaceHeadline.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  );

  TextStyle get interfaceBody => PolyReadTypography.interfaceBody.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  );

  TextStyle get interfaceCaption => PolyReadTypography.interfaceCaption.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  // Translation styles with theme colors
  TextStyle get translationWord => PolyReadTypography.translationWord.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  );

  TextStyle get translationMeaning => PolyReadTypography.translationMeaning.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  );

  TextStyle get translationContext => PolyReadTypography.translationContext.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}