// PolyRead Theme System
// Premium reading-focused color palettes and theme definitions

import 'package:flutter/material.dart';
import 'polyread_typography.dart';
import 'polyread_spacing.dart';

/// Reading-optimized theme system replacing Material Design
class PolyReadTheme {
  // Prevent instantiation
  PolyReadTheme._();

  /// Color Palettes for Reading Themes
  static const _PolyReadColors colors = _PolyReadColors();

  /// Create a reading theme for the specified type and brightness
  static ThemeData createTheme({
    required ReadingThemeType themeType,
    required Brightness brightness,
  }) {
    final colorScheme = _getColorScheme(themeType, brightness);
    
    return ThemeData(
      useMaterial3: false, // Disable Material 3 design system
      brightness: brightness,
      colorScheme: colorScheme,
      
      // Typography
      textTheme: PolyReadTypography.getTextTheme(brightness),
      primaryTextTheme: PolyReadTypography.getTextTheme(brightness),
      
      // App Bar Theme (for non-reading screens)
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: PolyReadTypography.interfaceTitle.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      
      // Card Theme (for library and settings)
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        shadowColor: colorScheme.shadow,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
        ),
      ),
      
      // Navigation Theme (for library navigation)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PolyReadTypography.interfaceCaption.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            );
          }
          return PolyReadTypography.interfaceCaption.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
          ),
          textStyle: PolyReadTypography.interfaceBody.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: PolyReadTypography.interfaceBody.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Input Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PolyReadSpacing.inputRadius),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PolyReadSpacing.elementSpacing,
          vertical: PolyReadSpacing.microSpacing,
        ),
      ),
      
      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PolyReadSpacing.dialogRadius),
        ),
      ),
      
      // Scaffold Theme
      scaffoldBackgroundColor: colorScheme.background,
      
      // Disable Material splash effects for reading focus
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  /// Get color scheme for reading theme type
  static ColorScheme _getColorScheme(ReadingThemeType themeType, Brightness brightness) {
    switch (themeType) {
      case ReadingThemeType.warmLight:
        return _createWarmLightScheme();
      case ReadingThemeType.trueDark:
        return _createTrueDarkScheme();
      case ReadingThemeType.enhancedSepia:
        return _createEnhancedSepiaScheme();
      case ReadingThemeType.blueFilter:
        return _createBlueFilterScheme();
      case ReadingThemeType.custom:
        // For now, fallback to warm light
        return _createWarmLightScheme();
    }
  }

  static ColorScheme _createWarmLightScheme() {
    return ColorScheme.light(
      brightness: Brightness.light,
      primary: colors.warmAccent,
      onPrimary: colors.warmPaper,
      primaryContainer: colors.warmAccent.withOpacity(0.2),
      onPrimaryContainer: colors.warmText,
      secondary: colors.warmAccent,
      onSecondary: colors.warmPaper,
      surface: colors.warmPaper,
      onSurface: colors.warmText,
      background: colors.warmCream,
      onBackground: colors.warmText,
      error: colors.errorRed,
      onError: Colors.white,
      outline: colors.warmText.withOpacity(0.2),
      shadow: Colors.black.withOpacity(0.1),
    );
  }

  static ColorScheme _createTrueDarkScheme() {
    return ColorScheme.dark(
      brightness: Brightness.dark,
      primary: colors.darkAccent,
      onPrimary: colors.trueDark,
      primaryContainer: colors.darkAccent.withOpacity(0.3),
      onPrimaryContainer: colors.darkText,
      secondary: colors.darkAccent,
      onSecondary: colors.trueDark,
      surface: colors.darkSurface,
      onSurface: colors.darkText,
      background: colors.trueDark,
      onBackground: colors.darkText,
      error: colors.errorRed,
      onError: Colors.white,
      outline: colors.darkText.withOpacity(0.2),
      shadow: Colors.black.withOpacity(0.3),
    );
  }

  static ColorScheme _createEnhancedSepiaScheme() {
    return ColorScheme.light(
      brightness: Brightness.light,
      primary: colors.sepiaAccent,
      onPrimary: colors.sepiaLight,
      primaryContainer: colors.sepiaAccent.withOpacity(0.2),
      onPrimaryContainer: colors.sepiaText,
      secondary: colors.sepiaAccent,
      onSecondary: colors.sepiaLight,
      surface: colors.sepiaLight,
      onSurface: colors.sepiaText,
      background: colors.richSepia,
      onBackground: colors.sepiaText,
      error: colors.errorRed,
      onError: Colors.white,
      outline: colors.sepiaText.withOpacity(0.2),
      shadow: Colors.black.withOpacity(0.1),
    );
  }

  static ColorScheme _createBlueFilterScheme() {
    return ColorScheme.light(
      brightness: Brightness.light,
      primary: colors.amberAccent,
      onPrimary: colors.amberLight,
      primaryContainer: colors.amberAccent.withOpacity(0.2),
      onPrimaryContainer: colors.amberText,
      secondary: colors.amberAccent,
      onSecondary: colors.amberLight,
      surface: colors.amberLight,
      onSurface: colors.amberText,
      background: colors.amberWarm,
      onBackground: colors.amberText,
      error: colors.errorRed,
      onError: Colors.white,
      outline: colors.amberText.withOpacity(0.2),
      shadow: Colors.black.withOpacity(0.1),
    );
  }
}

/// Reading theme types
enum ReadingThemeType {
  warmLight,
  trueDark,
  enhancedSepia,
  blueFilter,
  custom,
}

/// Color constants for PolyRead reading themes
class _PolyReadColors {
  const _PolyReadColors();

  // Warm Reading Light Theme
  static const Color warmCream = Color(0xFFFDF6E3);
  static const Color warmPaper = Color(0xFFFAF7F0);
  static const Color warmText = Color(0xFF2E2A24);
  static const Color warmAccent = Color(0xFF8D6E63); // Warm brown

  // True Dark Reading Theme
  static const Color trueDark = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF2A2A2A);
  static const Color darkText = Color(0xFFE8E6E3);
  static const Color darkAccent = Color(0xFFBCAAA4); // Muted warm brown

  // Enhanced Sepia Theme
  static const Color richSepia = Color(0xFFF4ECD8);
  static const Color sepiaLight = Color(0xFFFAF5E4);
  static const Color sepiaText = Color(0xFF5D4E37);
  static const Color sepiaAccent = Color(0xFF8B4513);

  // Blue Light Filter (Evening)
  static const Color amberWarm = Color(0xFFFFF8E1);
  static const Color amberLight = Color(0xFFFFFCF2);
  static const Color amberText = Color(0xFF3E2723);
  static const Color amberAccent = Color(0xFFFF8F00);

  // Interface Colors (not for reading content)
  static const Color linkBlue = Color(0xFF1976D2);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color warningOrange = Color(0xFFF57C00);
  static const Color errorRed = Color(0xFFD32F2F);

  // Expose colors through getters
  Color get warmCream => _PolyReadColors.warmCream;
  Color get warmPaper => _PolyReadColors.warmPaper;
  Color get warmText => _PolyReadColors.warmText;
  Color get warmAccent => _PolyReadColors.warmAccent;

  Color get trueDark => _PolyReadColors.trueDark;
  Color get darkSurface => _PolyReadColors.darkSurface;
  Color get darkCard => _PolyReadColors.darkCard;
  Color get darkText => _PolyReadColors.darkText;
  Color get darkAccent => _PolyReadColors.darkAccent;

  Color get richSepia => _PolyReadColors.richSepia;
  Color get sepiaLight => _PolyReadColors.sepiaLight;
  Color get sepiaText => _PolyReadColors.sepiaText;
  Color get sepiaAccent => _PolyReadColors.sepiaAccent;

  Color get amberWarm => _PolyReadColors.amberWarm;
  Color get amberLight => _PolyReadColors.amberLight;
  Color get amberText => _PolyReadColors.amberText;
  Color get amberAccent => _PolyReadColors.amberAccent;

  Color get linkBlue => _PolyReadColors.linkBlue;
  Color get successGreen => _PolyReadColors.successGreen;
  Color get warningOrange => _PolyReadColors.warningOrange;
  Color get errorRed => _PolyReadColors.errorRed;
}

/// Helper extension for reading theme detection
extension ReadingThemeExtension on ThemeData {
  /// Get the current reading theme type from the color scheme
  ReadingThemeType get readingThemeType {
    if (colorScheme.background == PolyReadTheme.colors.warmCream) {
      return ReadingThemeType.warmLight;
    } else if (colorScheme.background == PolyReadTheme.colors.trueDark) {
      return ReadingThemeType.trueDark;
    } else if (colorScheme.background == PolyReadTheme.colors.richSepia) {
      return ReadingThemeType.enhancedSepia;
    } else if (colorScheme.background == PolyReadTheme.colors.amberWarm) {
      return ReadingThemeType.blueFilter;
    } else {
      return ReadingThemeType.custom;
    }
  }

  /// Check if this is a reading-optimized theme
  bool get isReadingTheme => readingThemeType != ReadingThemeType.custom;
}