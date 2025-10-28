// Reader Settings Model
// Stores and manages reading experience preferences

import 'package:flutter/material.dart';

enum ReaderTheme {
  light,
  sepia,
  dark,
  custom,
}

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
  
  /// Default settings
  factory ReaderSettings.defaultSettings() {
    return const ReaderSettings(
      fontSize: 16,
      lineHeight: 1.5,
      fontFamily: 'System Default',
      textAlign: TextAlign.left,
      theme: ReaderTheme.light,
      brightness: 1.0,
      pageMargins: 16,
      autoScroll: false,
      autoScrollSpeed: 1.0,
      keepScreenOn: false,
      fullScreenMode: false,
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
  
  /// Create from JSON
  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      fontFamily: json['fontFamily'] as String? ?? 'System Default',
      textAlign: TextAlign.values[json['textAlign'] as int? ?? 0],
      theme: ReaderTheme.values[json['theme'] as int? ?? 0],
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      pageMargins: (json['pageMargins'] as num?)?.toDouble() ?? 16,
      autoScroll: json['autoScroll'] as bool? ?? false,
      autoScrollSpeed: (json['autoScrollSpeed'] as num?)?.toDouble() ?? 1.0,
      keepScreenOn: json['keepScreenOn'] as bool? ?? false,
      fullScreenMode: json['fullScreenMode'] as bool? ?? false,
    );
  }
  
  /// Get theme colors
  ThemeData getThemeData(BuildContext context) {
    final baseTheme = Theme.of(context);
    
    switch (theme) {
      case ReaderTheme.light:
        return baseTheme.copyWith(
          scaffoldBackgroundColor: Colors.white,
          cardColor: Colors.white,
          textTheme: baseTheme.textTheme.apply(
            bodyColor: Colors.black87,
            displayColor: Colors.black87,
          ),
        );
        
      case ReaderTheme.sepia:
        const sepiaBackground = Color(0xFFFDF6E3);
        const sepiaText = Color(0xFF5D4E37);
        return baseTheme.copyWith(
          scaffoldBackgroundColor: sepiaBackground,
          cardColor: sepiaBackground,
          textTheme: baseTheme.textTheme.apply(
            bodyColor: sepiaText,
            displayColor: sepiaText,
          ),
        );
        
      case ReaderTheme.dark:
        const darkBackground = Color(0xFF1A1A1A);
        const darkCard = Color(0xFF2A2A2A);
        return baseTheme.copyWith(
          scaffoldBackgroundColor: darkBackground,
          cardColor: darkCard,
          textTheme: baseTheme.textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        );
        
      case ReaderTheme.custom:
        final customBackground = Colors.grey.shade300.withOpacity(brightness);
        final customText = brightness > 0.5 ? Colors.black87 : Colors.white;
        return baseTheme.copyWith(
          scaffoldBackgroundColor: customBackground,
          cardColor: customBackground,
          textTheme: baseTheme.textTheme.apply(
            bodyColor: customText,
            displayColor: customText,
          ),
        );
    }
  }
  
  /// Get text style based on settings
  TextStyle getTextStyle(BuildContext context) {
    String? fontFamily;
    
    // Map font family names to actual font families
    switch (this.fontFamily) {
      case 'System Default':
        fontFamily = null; // Use system default
        break;
      case 'Georgia':
      case 'Times New Roman':
      case 'Arial':
      case 'Helvetica':
      case 'Open Sans':
      case 'Roboto':
        fontFamily = this.fontFamily;
        break;
      default:
        fontFamily = null;
    }
    
    return TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      fontFamily: fontFamily,
    );
  }
  
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
    return 'ReaderSettings(fontSize: $fontSize, theme: $theme, fontFamily: $fontFamily)';
  }
}