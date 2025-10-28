// Settings Provider
// Riverpod provider for app settings and preferences

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/core/services/settings_service.dart';

// Settings service provider
final settingsServiceProvider = Provider<SettingsService>((ref) {
  final service = SettingsService();
  // Initialize in main.dart before runApp
  return service;
});

// Settings state provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final service = ref.watch(settingsServiceProvider);
  return SettingsNotifier(service);
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _service;
  
  SettingsNotifier(this._service) : super(SettingsState.initial()) {
    _loadSettings();
  }
  
  void _loadSettings() {
    state = SettingsState(
      defaultSourceLanguage: _service.defaultSourceLanguage,
      defaultTargetLanguage: _service.defaultTargetLanguage,
      themeMode: _service.themeMode,
      fontSize: _service.fontSize,
      translationProvider: _service.translationProvider,
      autoDownloadModels: _service.autoDownloadModels,
      maxStorageMB: _service.maxStorageMB,
      showOnboarding: _service.showOnboarding,
    );
  }
  
  Future<void> setDefaultSourceLanguage(String language) async {
    await _service.setDefaultSourceLanguage(language);
    state = state.copyWith(defaultSourceLanguage: language);
  }
  
  Future<void> setDefaultTargetLanguage(String language) async {
    await _service.setDefaultTargetLanguage(language);
    state = state.copyWith(defaultTargetLanguage: language);
  }
  
  Future<void> setThemeMode(String mode) async {
    await _service.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }
  
  Future<void> setFontSize(double size) async {
    await _service.setFontSize(size);
    state = state.copyWith(fontSize: size);
  }
  
  Future<void> setTranslationProvider(String provider) async {
    await _service.setTranslationProvider(provider);
    state = state.copyWith(translationProvider: provider);
  }
  
  Future<void> setAutoDownloadModels(bool enabled) async {
    await _service.setAutoDownloadModels(enabled);
    state = state.copyWith(autoDownloadModels: enabled);
  }
  
  Future<void> setMaxStorageMB(int mb) async {
    await _service.setMaxStorageMB(mb);
    state = state.copyWith(maxStorageMB: mb);
  }
  
  Future<void> setShowOnboarding(bool show) async {
    await _service.setShowOnboarding(show);
    state = state.copyWith(showOnboarding: show);
  }
  
  Future<void> resetToDefaults() async {
    await _service.resetToDefaults();
    _loadSettings();
  }
}

class SettingsState {
  final String defaultSourceLanguage;
  final String defaultTargetLanguage;
  final String themeMode;
  final double fontSize;
  final String translationProvider;
  final bool autoDownloadModels;
  final int maxStorageMB;
  final bool showOnboarding;
  
  const SettingsState({
    required this.defaultSourceLanguage,
    required this.defaultTargetLanguage,
    required this.themeMode,
    required this.fontSize,
    required this.translationProvider,
    required this.autoDownloadModels,
    required this.maxStorageMB,
    required this.showOnboarding,
  });
  
  factory SettingsState.initial() {
    return const SettingsState(
      defaultSourceLanguage: 'auto',
      defaultTargetLanguage: 'en',
      themeMode: 'system',
      fontSize: 16.0,
      translationProvider: 'ml_kit',
      autoDownloadModels: true,
      maxStorageMB: 500,
      showOnboarding: true,
    );
  }
  
  SettingsState copyWith({
    String? defaultSourceLanguage,
    String? defaultTargetLanguage,
    String? themeMode,
    double? fontSize,
    String? translationProvider,
    bool? autoDownloadModels,
    int? maxStorageMB,
    bool? showOnboarding,
  }) {
    return SettingsState(
      defaultSourceLanguage: defaultSourceLanguage ?? this.defaultSourceLanguage,
      defaultTargetLanguage: defaultTargetLanguage ?? this.defaultTargetLanguage,
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      translationProvider: translationProvider ?? this.translationProvider,
      autoDownloadModels: autoDownloadModels ?? this.autoDownloadModels,
      maxStorageMB: maxStorageMB ?? this.maxStorageMB,
      showOnboarding: showOnboarding ?? this.showOnboarding,
    );
  }
}