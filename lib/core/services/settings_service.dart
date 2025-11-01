// Settings Service
// Manages user preferences and app configuration

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class SettingsService {
  static const String _keyDefaultSourceLanguage = 'default_source_language';
  static const String _keyDefaultTargetLanguage = 'default_target_language';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyFontSize = 'font_size';
  // Translation provider is now handled automatically with fallbacks
  // Auto download models removed - users should always be prompted
  // Storage limit removed from UI - handled internally with high limit
  static const String _keyShowOnboarding = 'show_onboarding';
  
  // Cycling Dictionary Settings
  static const String _keyCyclingEnabled = 'cycling_enabled';
  static const String _keyCyclingSpeed = 'cycling_speed';
  static const String _keyAutoExpansion = 'auto_expansion';
  static const String _keyShowPartOfSpeech = 'show_part_of_speech';
  static const String _keyShowQualityIndicators = 'show_quality_indicators';
  
  late final SharedPreferences _prefs;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // Language Settings
  String get defaultSourceLanguage => _prefs.getString(_keyDefaultSourceLanguage) ?? 'auto';
  String get defaultTargetLanguage => _prefs.getString(_keyDefaultTargetLanguage) ?? 'en';
  
  Future<void> setDefaultSourceLanguage(String language) async {
    await _prefs.setString(_keyDefaultSourceLanguage, language);
  }
  
  Future<void> setDefaultTargetLanguage(String language) async {
    await _prefs.setString(_keyDefaultTargetLanguage, language);
  }
  
  // UI Settings
  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'system';
  double get fontSize => _prefs.getDouble(_keyFontSize) ?? 16.0;
  
  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }
  
  Future<void> setFontSize(double size) async {
    await _prefs.setDouble(_keyFontSize, size);
  }
  
  // Translation settings removed - handled automatically by fallback system
  
  // Storage settings removed from UI - uses high internal limit
  int get maxStorageMB => AppConstants.defaultMaxStorageMB;
  
  // Onboarding
  bool get showOnboarding => _prefs.getBool(_keyShowOnboarding) ?? true;
  
  Future<void> setShowOnboarding(bool show) async {
    await _prefs.setBool(_keyShowOnboarding, show);
  }

  // Cycling Dictionary Settings
  bool get cyclingEnabled => _prefs.getBool(_keyCyclingEnabled) ?? true;
  int get cyclingSpeed => _prefs.getInt(_keyCyclingSpeed) ?? 2000;
  bool get autoExpansion => _prefs.getBool(_keyAutoExpansion) ?? false;
  bool get showPartOfSpeech => _prefs.getBool(_keyShowPartOfSpeech) ?? true;
  bool get showQualityIndicators => _prefs.getBool(_keyShowQualityIndicators) ?? true;

  Future<void> setCyclingEnabled(bool enabled) async {
    await _prefs.setBool(_keyCyclingEnabled, enabled);
  }

  Future<void> setCyclingSpeed(int milliseconds) async {
    await _prefs.setInt(_keyCyclingSpeed, milliseconds);
  }

  Future<void> setAutoExpansion(bool enabled) async {
    await _prefs.setBool(_keyAutoExpansion, enabled);
  }

  Future<void> setShowPartOfSpeech(bool enabled) async {
    await _prefs.setBool(_keyShowPartOfSpeech, enabled);
  }

  Future<void> setShowQualityIndicators(bool enabled) async {
    await _prefs.setBool(_keyShowQualityIndicators, enabled);
  }
  
  // Utility methods
  Future<void> resetToDefaults() async {
    await _prefs.clear();
  }
  
  Future<Map<String, dynamic>> exportSettings() async {
    return {
      'defaultSourceLanguage': defaultSourceLanguage,
      'defaultTargetLanguage': defaultTargetLanguage,
      'themeMode': themeMode,
      'fontSize': fontSize,
      // maxStorageMB removed from export - uses high internal limit
      'cyclingEnabled': cyclingEnabled,
      'cyclingSpeed': cyclingSpeed,
      'autoExpansion': autoExpansion,
      'showPartOfSpeech': showPartOfSpeech,
      'showQualityIndicators': showQualityIndicators,
    };
  }
  
  Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings['defaultSourceLanguage'] != null) {
      await setDefaultSourceLanguage(settings['defaultSourceLanguage']);
    }
    if (settings['defaultTargetLanguage'] != null) {
      await setDefaultTargetLanguage(settings['defaultTargetLanguage']);
    }
    if (settings['themeMode'] != null) {
      await setThemeMode(settings['themeMode']);
    }
    if (settings['fontSize'] != null) {
      await setFontSize(settings['fontSize']);
    }
    // maxStorageMB import removed - uses high internal limit
    if (settings['cyclingEnabled'] != null) {
      await setCyclingEnabled(settings['cyclingEnabled']);
    }
    if (settings['cyclingSpeed'] != null) {
      await setCyclingSpeed(settings['cyclingSpeed']);
    }
    if (settings['autoExpansion'] != null) {
      await setAutoExpansion(settings['autoExpansion']);
    }
    if (settings['showPartOfSpeech'] != null) {
      await setShowPartOfSpeech(settings['showPartOfSpeech']);
    }
    if (settings['showQualityIndicators'] != null) {
      await setShowQualityIndicators(settings['showQualityIndicators']);
    }
  }
}