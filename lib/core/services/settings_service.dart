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
      'translationProvider': translationProvider,
      'autoDownloadModels': autoDownloadModels,
      'maxStorageMB': maxStorageMB,
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
    if (settings['translationProvider'] != null) {
      await setTranslationProvider(settings['translationProvider']);
    }
    if (settings['autoDownloadModels'] != null) {
      await setAutoDownloadModels(settings['autoDownloadModels']);
    }
    if (settings['maxStorageMB'] != null) {
      await setMaxStorageMB(settings['maxStorageMB']);
    }
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