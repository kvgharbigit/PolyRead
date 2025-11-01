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
  
  // Translation and storage settings removed - handled automatically
  
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
  final bool showOnboarding;
  
  const SettingsState({
    required this.defaultSourceLanguage,
    required this.defaultTargetLanguage,
    required this.themeMode,
    required this.fontSize,
    required this.showOnboarding,
  });
  
  factory SettingsState.initial() {
    return const SettingsState(
      defaultSourceLanguage: 'auto',
      defaultTargetLanguage: 'en',
      themeMode: 'system',
      fontSize: 16.0,
      showOnboarding: true,
    );
  }
  
  SettingsState copyWith({
    String? defaultSourceLanguage,
    String? defaultTargetLanguage,
    String? themeMode,
    double? fontSize,
    bool? showOnboarding,
  }) {
    return SettingsState(
      defaultSourceLanguage: defaultSourceLanguage ?? this.defaultSourceLanguage,
      defaultTargetLanguage: defaultTargetLanguage ?? this.defaultTargetLanguage,
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      showOnboarding: showOnboarding ?? this.showOnboarding,
    );
  }
}