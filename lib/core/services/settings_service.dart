// Settings Service
// Manages user preferences and app configuration

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyDefaultSourceLanguage = 'default_source_language';
  static const String _keyDefaultTargetLanguage = 'default_target_language';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyFontSize = 'font_size';
  static const String _keyTranslationProvider = 'translation_provider';
  static const String _keyAutoDownloadModels = 'auto_download_models';
  static const String _keyMaxStorageMB = 'max_storage_mb';
  static const String _keyShowOnboarding = 'show_onboarding';
  
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
  
  // Translation Settings
  String get translationProvider => _prefs.getString(_keyTranslationProvider) ?? 'ml_kit';
  bool get autoDownloadModels => _prefs.getBool(_keyAutoDownloadModels) ?? true;
  
  Future<void> setTranslationProvider(String provider) async {
    await _prefs.setString(_keyTranslationProvider, provider);
  }
  
  Future<void> setAutoDownloadModels(bool enabled) async {
    await _prefs.setBool(_keyAutoDownloadModels, enabled);
  }
  
  // Storage Settings
  int get maxStorageMB => _prefs.getInt(_keyMaxStorageMB) ?? 500;
  
  Future<void> setMaxStorageMB(int mb) async {
    await _prefs.setInt(_keyMaxStorageMB, mb);
  }
  
  // Onboarding
  bool get showOnboarding => _prefs.getBool(_keyShowOnboarding) ?? true;
  
  Future<void> setShowOnboarding(bool show) async {
    await _prefs.setBool(_keyShowOnboarding, show);
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
      'translationProvider': translationProvider,
      'autoDownloadModels': autoDownloadModels,
      'maxStorageMB': maxStorageMB,
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
    if (settings['translationProvider'] != null) {
      await setTranslationProvider(settings['translationProvider']);
    }
    if (settings['autoDownloadModels'] != null) {
      await setAutoDownloadModels(settings['autoDownloadModels']);
    }
    if (settings['maxStorageMB'] != null) {
      await setMaxStorageMB(settings['maxStorageMB']);
    }
  }
}