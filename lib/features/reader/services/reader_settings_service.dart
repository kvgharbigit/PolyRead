// Reader Settings Service
// Manages persistence and application of reading preferences

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:polyread/features/reader/models/reader_settings.dart';
import 'package:polyread/core/themes/polyread_theme.dart';

class ReaderSettingsService {
  static const String _settingsKey = 'reader_settings';
  static const String _defaultSettingsKey = 'default_reader_settings';
  
  SharedPreferences? _prefs;
  ReaderSettings _currentSettings = ReaderSettings.defaultSettings();
  
  // Singleton pattern
  static final ReaderSettingsService _instance = ReaderSettingsService._internal();
  factory ReaderSettingsService() => _instance;
  ReaderSettingsService._internal();
  
  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }
  
  /// Get current settings
  ReaderSettings get currentSettings => _currentSettings;
  
  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      final settingsJson = _prefs?.getString(_settingsKey);
      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        _currentSettings = ReaderSettings.fromJson(settingsMap);
      } else {
        // Use default settings if none saved
        _currentSettings = ReaderSettings.defaultSettings();
        await _saveSettings(); // Save defaults for next time
      }
      
      // Apply system-level settings
      await _applySystemSettings(_currentSettings);
    } catch (e) {
      // If loading fails, use defaults
      _currentSettings = ReaderSettings.defaultSettings();
      await _saveSettings();
    }
  }
  
  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      final settingsJson = json.encode(_currentSettings.toJson());
      await _prefs?.setString(_settingsKey, settingsJson);
    } catch (e) {
      // Handle save error - could log or show user notification
      print('Failed to save reader settings: $e');
    }
  }
  
  /// Update settings and persist changes
  Future<void> updateSettings(ReaderSettings newSettings) async {
    final oldSettings = _currentSettings;
    _currentSettings = newSettings;
    
    // Save to persistent storage
    await _saveSettings();
    
    // Apply system-level changes
    await _applySystemSettings(newSettings);
    
    // Handle setting-specific changes
    await _handleSettingChanges(oldSettings, newSettings);
  }
  
  /// Apply system-level settings (wake lock, full screen, etc.)
  Future<void> _applySystemSettings(ReaderSettings settings) async {
    try {
      // Handle wake lock
      if (settings.keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
      
      // Handle full screen mode
      if (settings.fullScreenMode) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
      } else {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
      }
      
      // Handle brightness (for custom theme)
      if (settings.theme == ReadingThemeType.custom) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarBrightness: settings.brightness > 0.5 
                ? Brightness.light 
                : Brightness.dark,
            statusBarIconBrightness: settings.brightness > 0.5 
                ? Brightness.dark 
                : Brightness.light,
          ),
        );
      }
    } catch (e) {
      print('Failed to apply system settings: $e');
    }
  }
  
  /// Handle specific setting changes that need immediate action
  Future<void> _handleSettingChanges(
    ReaderSettings oldSettings, 
    ReaderSettings newSettings,
  ) async {
    // Handle wake lock changes
    if (oldSettings.keepScreenOn != newSettings.keepScreenOn) {
      if (newSettings.keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    }
    
    // Handle full screen changes
    if (oldSettings.fullScreenMode != newSettings.fullScreenMode) {
      if (newSettings.fullScreenMode) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
      } else {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
      }
    }
    
    // Handle theme changes
    if (oldSettings.theme != newSettings.theme || 
        oldSettings.brightness != newSettings.brightness) {
      await _applyThemeSettings(newSettings);
    }
  }
  
  /// Apply theme-specific system settings
  Future<void> _applyThemeSettings(ReaderSettings settings) async {
    try {
      SystemUiOverlayStyle overlayStyle;
      
      switch (settings.theme) {
        case ReadingThemeType.warmLight:
          overlayStyle = const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Color(0xFFFDF6E3),
            systemNavigationBarIconBrightness: Brightness.dark,
          );
          break;
          
        case ReadingThemeType.trueDark:
          overlayStyle = const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF000000),
            systemNavigationBarIconBrightness: Brightness.light,
          );
          break;
          
        case ReadingThemeType.enhancedSepia:
          overlayStyle = const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Color(0xFFF4ECD8),
            systemNavigationBarIconBrightness: Brightness.dark,
          );
          break;
          
        case ReadingThemeType.blueFilter:
          overlayStyle = const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Color(0xFFFFF8E1),
            systemNavigationBarIconBrightness: Brightness.dark,
          );
          break;
          
        case ReadingThemeType.custom:
          final isDarkBrightness = settings.brightness < 0.5;
          overlayStyle = SystemUiOverlayStyle(
            statusBarBrightness: isDarkBrightness ? Brightness.dark : Brightness.light,
            statusBarIconBrightness: isDarkBrightness ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: isDarkBrightness ? Brightness.light : Brightness.dark,
          );
          break;
      }
      
      SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    } catch (e) {
      print('Failed to apply theme settings: $e');
    }
  }
  
  /// Reset to default settings
  Future<void> resetToDefaults() async {
    await updateSettings(ReaderSettings.defaultSettings());
  }
  
  /// Export settings as JSON string
  String exportSettings() {
    return json.encode(_currentSettings.toJson());
  }
  
  /// Import settings from JSON string
  Future<bool> importSettings(String settingsJson) async {
    try {
      final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
      final newSettings = ReaderSettings.fromJson(settingsMap);
      await updateSettings(newSettings);
      return true;
    } catch (e) {
      print('Failed to import settings: $e');
      return false;
    }
  }
  
  /// Get settings for specific reader engine type
  ReaderEngineSettings getEngineSettings(String engineType) {
    return ReaderEngineSettings(
      fontSize: _currentSettings.fontSize,
      lineHeight: _currentSettings.lineHeight,
      fontFamily: _currentSettings.fontFamily,
      textAlign: _currentSettings.textAlign,
      theme: _currentSettings.theme,
      brightness: _currentSettings.brightness,
      pageMargins: _currentSettings.pageMargins,
      autoScroll: _currentSettings.autoScroll,
      autoScrollSpeed: _currentSettings.autoScrollSpeed,
      engineType: engineType,
    );
  }
  
  /// Clean up when app is closing
  Future<void> dispose() async {
    try {
      // Restore system UI when app closes
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      
      // Disable wake lock
      await WakelockPlus.disable();
    } catch (e) {
      print('Error during settings service disposal: $e');
    }
  }
}

/// Settings specific to reader engines
class ReaderEngineSettings {
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final TextAlign textAlign;
  final ReaderTheme theme;
  final double brightness;
  final double pageMargins;
  final bool autoScroll;
  final double autoScrollSpeed;
  final String engineType;
  
  const ReaderEngineSettings({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.textAlign,
    required this.theme,
    required this.brightness,
    required this.pageMargins,
    required this.autoScroll,
    required this.autoScrollSpeed,
    required this.engineType,
  });
  
  /// Get CSS styles for web-based engines (HTML, EPUB)
  String getCssStyles() {
    final fontFamilyValue = fontFamily == 'System Default' 
        ? '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif'
        : fontFamily;
    
    final alignValue = textAlign == TextAlign.justify ? 'justify' 
        : textAlign == TextAlign.center ? 'center' 
        : 'left';
    
    final colors = _getThemeColors();
    
    return '''
      body {
        font-family: "$fontFamilyValue";
        font-size: ${fontSize}px;
        line-height: $lineHeight;
        text-align: $alignValue;
        margin: ${pageMargins}px;
        padding: ${pageMargins}px;
        background-color: ${colors.backgroundColor};
        color: ${colors.textColor};
        transition: all 0.3s ease;
      }
      
      p, div {
        font-family: inherit;
        font-size: inherit;
        line-height: inherit;
        text-align: inherit;
        margin-bottom: ${lineHeight * 0.5}em;
      }
      
      h1, h2, h3, h4, h5, h6 {
        font-family: inherit;
        line-height: ${lineHeight * 0.9};
        margin-bottom: ${lineHeight * 0.8}em;
        margin-top: ${lineHeight * 1.2}em;
      }
      
      ::selection {
        background-color: ${colors.selectionColor};
        color: ${colors.selectionTextColor};
      }
      
      .polyread-highlight {
        background-color: ${colors.highlightColor};
        padding: 2px 4px;
        border-radius: 3px;
      }
    ''';
  }
  
  /// Get theme colors for styling
  ThemeColors _getThemeColors() {
    switch (theme) {
      case ReadingThemeType.warmLight:
        return const ThemeColors(
          backgroundColor: '#FFFFFF', // White page background to match getPageBackgroundColor
          textColor: '#2E2A24',
          selectionColor: '#E6D7C3',
          selectionTextColor: '#2E2A24',
          highlightColor: '#F4E8C1',
        );
        
      case ReadingThemeType.enhancedSepia:
        return const ThemeColors(
          backgroundColor: '#F4ECD8',
          textColor: '#5D4E37',
          selectionColor: '#E6D7C3',
          selectionTextColor: '#5D4E37',
          highlightColor: '#F4E8C1',
        );
        
      case ReadingThemeType.trueDark:
        return const ThemeColors(
          backgroundColor: '#000000',
          textColor: '#E8E6E3',
          selectionColor: '#404040',
          selectionTextColor: '#E8E6E3',
          highlightColor: '#FFB74D',
        );
        
      case ReadingThemeType.blueFilter:
        return const ThemeColors(
          backgroundColor: '#FFF8E1',
          textColor: '#3E2723',
          selectionColor: '#F5E5B7',
          selectionTextColor: '#3E2723',
          highlightColor: '#FFD54F',
        );
        
      case ReadingThemeType.custom:
        final bgBrightness = (brightness * 255).round();
        final textBrightness = brightness > 0.5 ? 0 : 255;
        return ThemeColors(
          backgroundColor: '#${bgBrightness.toRadixString(16).padLeft(2, '0') * 3}',
          textColor: '#${textBrightness.toRadixString(16).padLeft(2, '0') * 3}',
          selectionColor: brightness > 0.5 ? '#CCCCCC' : '#444444',
          selectionTextColor: '#${textBrightness.toRadixString(16).padLeft(2, '0') * 3}',
          highlightColor: brightness > 0.5 ? '#FFEB3B' : '#FFB74D',
        );
    }
  }
}

/// Theme color constants
class ThemeColors {
  final String backgroundColor;
  final String textColor;
  final String selectionColor;
  final String selectionTextColor;
  final String highlightColor;
  
  const ThemeColors({
    required this.backgroundColor,
    required this.textColor,
    required this.selectionColor,
    required this.selectionTextColor,
    required this.highlightColor,
  });
}

/// Extension to add text styling to TextStyle
extension ReaderSettingsTextStyle on ReaderSettings {
  /// Get the actual page background color used in WebView/EPUB content
  Color getPageBackgroundColor(BuildContext context) {
    switch (theme) {
      case ReadingThemeType.warmLight:
        return Colors.white; // EPUB pages are white, not cream
      case ReadingThemeType.enhancedSepia:
        return const Color(0xFFF4ECD8); // Sepia page color
      case ReadingThemeType.trueDark:
        return const Color(0xFF000000); // True dark page color
      case ReadingThemeType.blueFilter:
        return const Color(0xFFFFF8E1); // Blue filter page color
      case ReadingThemeType.custom:
        final brightnessValue = (this.brightness * 255).round();
        return Color.fromRGBO(brightnessValue, brightnessValue, brightnessValue, 1.0);
    }
  }
  /// Get Flutter TextStyle based on settings
  TextStyle getFlutterTextStyle([TextStyle? baseStyle]) {
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
    
    return (baseStyle ?? const TextStyle()).copyWith(
      fontSize: fontSize,
      height: lineHeight,
      fontFamily: fontFamily,
    );
  }
  
  /// Get colors based on theme
  Color getBackgroundColor() {
    switch (theme) {
      case ReadingThemeType.warmLight:
        return const Color(0xFFFDF6E3);
      case ReadingThemeType.enhancedSepia:
        return const Color(0xFFF4ECD8);
      case ReadingThemeType.trueDark:
        return const Color(0xFF000000);
      case ReadingThemeType.blueFilter:
        return const Color(0xFFFFF8E1);
      case ReadingThemeType.custom:
        final brightness = (this.brightness * 255).round();
        return Color.fromRGBO(brightness, brightness, brightness, 1.0);
    }
  }
  
  /// Get text color based on theme
  Color getTextColor() {
    switch (theme) {
      case ReadingThemeType.warmLight:
        return const Color(0xFF2E2A24);
      case ReadingThemeType.enhancedSepia:
        return const Color(0xFF5D4E37);
      case ReadingThemeType.trueDark:
        return const Color(0xFFE8E6E3);
      case ReadingThemeType.blueFilter:
        return const Color(0xFF3E2723);
      case ReadingThemeType.custom:
        return brightness > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    }
  }
}