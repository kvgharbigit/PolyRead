// Reader Settings Model
// Stores and manages reading experience preferences with PolyRead themes

import 'package:flutter/material.dart';
import 'package:polyread/core/themes/polyread_theme.dart';
import 'package:polyread/core/themes/polyread_typography.dart';

// Use PolyRead theme types for enhanced reading experience
typedef ReaderTheme = ReadingThemeType;

class ReaderSettings {
  // Text settings
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final TextAlign textAlign;
  
  // Theme settings
  final ReaderTheme theme;
  final double brightness; // Only used for custom theme
  
  // Layout settings
  final double pageMargins;
  
  // Reading behavior
  final bool autoScroll;
  final double autoScrollSpeed;
  final bool keepScreenOn;
  final bool fullScreenMode;
  
  const ReaderSettings({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.textAlign,
    required this.theme,
    required this.brightness,
    required this.pageMargins,
    required this.autoScroll,
    required this.autoScrollSpeed,
    required this.keepScreenOn,
    required this.fullScreenMode,
  });
  
  /// Default settings with PolyRead optimizations
  factory ReaderSettings.defaultSettings() {
    return const ReaderSettings(
      fontSize: 18, // Optimized for reading
      lineHeight: 1.6, // Better reading line spacing
      fontFamily: 'Literata', // Premium reading font
      textAlign: TextAlign.left,
      theme: ReadingThemeType.warmLight, // Use PolyRead theme
      brightness: 1.0,
      pageMargins: 24, // Better reading margins
      autoScroll: false,
      autoScrollSpeed: 1.0,
      keepScreenOn: false,
      fullScreenMode: true, // Default to immersive reading
    );
  }
  
  /// Create a copy with modified values
  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    TextAlign? textAlign,
    ReaderTheme? theme,
    double? brightness,
    double? pageMargins,
    bool? autoScroll,
    double? autoScrollSpeed,
    bool? keepScreenOn,
    bool? fullScreenMode,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
      theme: theme ?? this.theme,
      brightness: brightness ?? this.brightness,
      pageMargins: pageMargins ?? this.pageMargins,
      autoScroll: autoScroll ?? this.autoScroll,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      fullScreenMode: fullScreenMode ?? this.fullScreenMode,
    );
  }
  
  /// Copy settings for immutability
  ReaderSettings copy() {
    return copyWith();
  }
  
  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontFamily': fontFamily,
      'textAlign': textAlign.index,
      'theme': theme.index,
      'brightness': brightness,
      'pageMargins': pageMargins,
      'autoScroll': autoScroll,
      'autoScrollSpeed': autoScrollSpeed,
      'keepScreenOn': keepScreenOn,
      'fullScreenMode': fullScreenMode,
    };
  }
  
  /// Create from JSON with PolyRead defaults
  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      fontFamily: json['fontFamily'] as String? ?? 'Literata',
      textAlign: TextAlign.values[json['textAlign'] as int? ?? 0],
      theme: ReadingThemeType.values[json['theme'] as int? ?? 0],
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      pageMargins: (json['pageMargins'] as num?)?.toDouble() ?? 24,
      autoScroll: json['autoScroll'] as bool? ?? false,
      autoScrollSpeed: (json['autoScrollSpeed'] as num?)?.toDouble() ?? 1.0,
      keepScreenOn: json['keepScreenOn'] as bool? ?? false,
      fullScreenMode: json['fullScreenMode'] as bool? ?? true,
    );
  }
  
  /// Get PolyRead theme based on reader settings
  ThemeData getThemeData(BuildContext context) {
    // For custom theme, adjust brightness manually
    if (theme == ReadingThemeType.custom) {
      // Create a custom brightness-adjusted theme
      final brightness = this.brightness;
      final isDark = brightness < 0.5;
      
      return PolyReadTheme.createTheme(
        themeType: isDark ? ReadingThemeType.trueDark : ReadingThemeType.warmLight,
        brightness: isDark ? Brightness.dark : Brightness.light,
      );
    }
    
    // Use PolyRead theme system for optimal reading experience
    final brightness = _getThemeBrightness();
    return PolyReadTheme.createTheme(
      themeType: theme,
      brightness: brightness,
    );
  }
  
  /// Get appropriate brightness for the theme
  Brightness _getThemeBrightness() {
    switch (theme) {
      case ReadingThemeType.trueDark:
        return Brightness.dark;
      case ReadingThemeType.warmLight:
      case ReadingThemeType.enhancedSepia:
      case ReadingThemeType.blueFilter:
        return Brightness.light;
      case ReadingThemeType.custom:
        return brightness < 0.5 ? Brightness.dark : Brightness.light;
    }
  }
  
  /// Get reading text style with PolyRead typography
  TextStyle getTextStyle(BuildContext context) {
    // Use PolyRead typography system for optimal reading
    TextStyle baseStyle;
    
    switch (fontFamily) {
      case 'Literata':
        baseStyle = PolyReadTypography.readingBody;
        break;
      case 'Source Serif Pro':
      case 'Crimson Text':
      case 'Lora':
      case 'Merriweather':
        baseStyle = PolyReadTypography.getReadingFont(fontFamily);
        break;
      default:
        baseStyle = PolyReadTypography.readingBody;
    }
    
    // Apply user customizations
    return baseStyle.copyWith(
      fontSize: fontSize,
      height: lineHeight,
    );
  }
  
  /// Get available font options
  static List<String> get availableFonts => [
    'Literata',
    'Source Serif Pro',
    'Crimson Text',
    'Lora',
    'Merriweather',
  ];
  
  /// Get theme display names
  static Map<ReadingThemeType, String> get themeNames => {
    ReadingThemeType.warmLight: 'Warm Light',
    ReadingThemeType.trueDark: 'True Dark',
    ReadingThemeType.enhancedSepia: 'Enhanced Sepia',
    ReadingThemeType.blueFilter: 'Blue Light Filter',
    ReadingThemeType.custom: 'Custom',
  };
  
  /// Get theme descriptions
  static Map<ReadingThemeType, String> get themeDescriptions => {
    ReadingThemeType.warmLight: 'Warm, cream-colored background perfect for daytime reading',
    ReadingThemeType.trueDark: 'Deep black background for comfortable night reading',
    ReadingThemeType.enhancedSepia: 'Rich sepia tones that reduce eye strain',
    ReadingThemeType.blueFilter: 'Amber-tinted theme that filters blue light for evening reading',
    ReadingThemeType.custom: 'Customizable brightness level',
  };
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ReaderSettings &&
        other.fontSize == fontSize &&
        other.lineHeight == lineHeight &&
        other.fontFamily == fontFamily &&
        other.textAlign == textAlign &&
        other.theme == theme &&
        other.brightness == brightness &&
        other.pageMargins == pageMargins &&
        other.autoScroll == autoScroll &&
        other.autoScrollSpeed == autoScrollSpeed &&
        other.keepScreenOn == keepScreenOn &&
        other.fullScreenMode == fullScreenMode;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      fontSize,
      lineHeight,
      fontFamily,
      textAlign,
      theme,
      brightness,
      pageMargins,
      autoScroll,
      autoScrollSpeed,
      keepScreenOn,
      fullScreenMode,
    );
  }
  
  @override
  String toString() {
    return 'ReaderSettings(fontSize: $fontSize, theme: ${themeNames[theme]}, fontFamily: $fontFamily, fullScreen: $fullScreenMode)';
  }
}