// Translation Preferences Service
// Manages user preferences for translation gestures and provider selection

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum TranslationGesture {
  singleTap,
  doubleTap,
  longPress,
  disabled,
}

enum TranslationAction {
  wordTranslation,
  sentenceTranslation,
  disabled,
}

enum ProviderPreference {
  dictionaryFirst,
  mlKitFirst,
  serverFirst,
  automatic,
}

class TranslationPreferences {
  final Map<TranslationGesture, TranslationAction> gestureMapping;
  final ProviderPreference providerPreference;
  final String defaultSourceLanguage;
  final String defaultTargetLanguage;
  final bool showProviderIndicator;
  final bool enableHapticFeedback;
  final bool autoDetectLanguage;
  final Duration tapTimeout;
  final bool cacheTranslations;
  
  const TranslationPreferences({
    required this.gestureMapping,
    this.providerPreference = ProviderPreference.automatic,
    this.defaultSourceLanguage = 'en',
    this.defaultTargetLanguage = 'es',
    this.showProviderIndicator = true,
    this.enableHapticFeedback = true,
    this.autoDetectLanguage = false,
    this.tapTimeout = const Duration(milliseconds: 300),
    this.cacheTranslations = true,
  });

  static TranslationPreferences get defaultPreferences {
    return const TranslationPreferences(
      gestureMapping: {
        TranslationGesture.singleTap: TranslationAction.wordTranslation,
        TranslationGesture.doubleTap: TranslationAction.sentenceTranslation,
        TranslationGesture.longPress: TranslationAction.sentenceTranslation,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gestureMapping': gestureMapping.map(
        (key, value) => MapEntry(key.name, value.name),
      ),
      'providerPreference': providerPreference.name,
      'defaultSourceLanguage': defaultSourceLanguage,
      'defaultTargetLanguage': defaultTargetLanguage,
      'showProviderIndicator': showProviderIndicator,
      'enableHapticFeedback': enableHapticFeedback,
      'autoDetectLanguage': autoDetectLanguage,
      'tapTimeoutMs': tapTimeout.inMilliseconds,
      'cacheTranslations': cacheTranslations,
    };
  }

  factory TranslationPreferences.fromMap(Map<String, dynamic> map) {
    final gestureMap = <TranslationGesture, TranslationAction>{};
    final gestureMappingMap = map['gestureMapping'] as Map<String, dynamic>? ?? {};
    
    for (final entry in gestureMappingMap.entries) {
      final gesture = TranslationGesture.values.firstWhere(
        (g) => g.name == entry.key,
        orElse: () => TranslationGesture.disabled,
      );
      final action = TranslationAction.values.firstWhere(
        (a) => a.name == entry.value,
        orElse: () => TranslationAction.disabled,
      );
      gestureMap[gesture] = action;
    }

    return TranslationPreferences(
      gestureMapping: gestureMap,
      providerPreference: ProviderPreference.values.firstWhere(
        (p) => p.name == map['providerPreference'],
        orElse: () => ProviderPreference.automatic,
      ),
      defaultSourceLanguage: map['defaultSourceLanguage'] ?? 'en',
      defaultTargetLanguage: map['defaultTargetLanguage'] ?? 'es',
      showProviderIndicator: map['showProviderIndicator'] ?? true,
      enableHapticFeedback: map['enableHapticFeedback'] ?? true,
      autoDetectLanguage: map['autoDetectLanguage'] ?? false,
      tapTimeout: Duration(milliseconds: map['tapTimeoutMs'] ?? 300),
      cacheTranslations: map['cacheTranslations'] ?? true,
    );
  }

  TranslationPreferences copyWith({
    Map<TranslationGesture, TranslationAction>? gestureMapping,
    ProviderPreference? providerPreference,
    String? defaultSourceLanguage,
    String? defaultTargetLanguage,
    bool? showProviderIndicator,
    bool? enableHapticFeedback,
    bool? autoDetectLanguage,
    Duration? tapTimeout,
    bool? cacheTranslations,
  }) {
    return TranslationPreferences(
      gestureMapping: gestureMapping ?? this.gestureMapping,
      providerPreference: providerPreference ?? this.providerPreference,
      defaultSourceLanguage: defaultSourceLanguage ?? this.defaultSourceLanguage,
      defaultTargetLanguage: defaultTargetLanguage ?? this.defaultTargetLanguage,
      showProviderIndicator: showProviderIndicator ?? this.showProviderIndicator,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      autoDetectLanguage: autoDetectLanguage ?? this.autoDetectLanguage,
      tapTimeout: tapTimeout ?? this.tapTimeout,
      cacheTranslations: cacheTranslations ?? this.cacheTranslations,
    );
  }
}

class TranslationPreferencesService {
  static const String _prefsKey = 'translation_preferences';
  SharedPreferences? _prefs;
  TranslationPreferences _currentPreferences = TranslationPreferences.defaultPreferences;

  TranslationPreferences get currentPreferences => _currentPreferences;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (_prefs == null) return;

    final prefsJson = _prefs!.getString(_prefsKey);
    if (prefsJson != null) {
      try {
        final map = jsonDecode(prefsJson) as Map<String, dynamic>;
        _currentPreferences = TranslationPreferences.fromMap(map);
      } catch (e) {
        // If loading fails, use default preferences
        _currentPreferences = TranslationPreferences.defaultPreferences;
      }
    }
  }

  Future<void> updatePreferences(TranslationPreferences preferences) async {
    if (_prefs == null) return;

    _currentPreferences = preferences;
    final prefsJson = jsonEncode(preferences.toMap());
    await _prefs!.setString(_prefsKey, prefsJson);
  }

  /// Get the action for a specific gesture
  TranslationAction getActionForGesture(TranslationGesture gesture) {
    return _currentPreferences.gestureMapping[gesture] ?? TranslationAction.disabled;
  }

  /// Update gesture mapping
  Future<void> updateGestureMapping(TranslationGesture gesture, TranslationAction action) async {
    final newMapping = Map<TranslationGesture, TranslationAction>.from(_currentPreferences.gestureMapping);
    newMapping[gesture] = action;
    
    await updatePreferences(_currentPreferences.copyWith(gestureMapping: newMapping));
  }

  /// Update provider preference
  Future<void> updateProviderPreference(ProviderPreference preference) async {
    await updatePreferences(_currentPreferences.copyWith(providerPreference: preference));
  }

  /// Update default languages
  Future<void> updateDefaultLanguages({
    String? sourceLanguage,
    String? targetLanguage,
  }) async {
    await updatePreferences(_currentPreferences.copyWith(
      defaultSourceLanguage: sourceLanguage,
      defaultTargetLanguage: targetLanguage,
    ));
  }

  /// Check if a gesture is enabled
  bool isGestureEnabled(TranslationGesture gesture) {
    return getActionForGesture(gesture) != TranslationAction.disabled;
  }

  /// Get preferred provider order based on preferences
  List<String> getProviderOrder() {
    switch (_currentPreferences.providerPreference) {
      case ProviderPreference.dictionaryFirst:
        return ['dictionary', 'ml_kit', 'google_translate_free'];
      case ProviderPreference.mlKitFirst:
        return ['ml_kit', 'dictionary', 'google_translate_free'];
      case ProviderPreference.serverFirst:
        return ['google_translate_free', 'ml_kit', 'dictionary'];
      case ProviderPreference.automatic:
      default:
        return ['dictionary', 'ml_kit', 'google_translate_free'];
    }
  }

  /// Reset to default preferences
  Future<void> resetToDefaults() async {
    await updatePreferences(TranslationPreferences.defaultPreferences);
  }

  /// Export preferences as JSON string
  String exportPreferences() {
    return jsonEncode(_currentPreferences.toMap());
  }

  /// Import preferences from JSON string
  Future<bool> importPreferences(String preferencesJson) async {
    try {
      final map = jsonDecode(preferencesJson) as Map<String, dynamic>;
      final preferences = TranslationPreferences.fromMap(map);
      await updatePreferences(preferences);
      return true;
    } catch (e) {
      return false;
    }
  }
}