// Settings Screen
// User preferences and app configuration

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/core/providers/settings_provider.dart';
import 'package:polyread/core/utils/constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          // Language Settings
          _SettingsSection(
            title: 'Language',
            children: [
              _SettingsDropdown(
                title: 'Source Language',
                subtitle: 'Language of books you read',
                value: settings.defaultSourceLanguage,
                items: AppConstants.supportedLanguages
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Text(AppConstants.languageNames[code] ?? code),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setDefaultSourceLanguage(value);
                  }
                },
              ),
              _SettingsDropdown(
                title: 'Target Language',
                subtitle: 'Language to translate to',
                value: settings.defaultTargetLanguage,
                items: AppConstants.supportedLanguages
                    .where((code) => code != 'auto')
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Text(AppConstants.languageNames[code] ?? code),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setDefaultTargetLanguage(value);
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // Reading Settings
          _SettingsSection(
            title: 'Reading',
            children: [
              _SettingsSlider(
                title: 'Font Size',
                subtitle: '${settings.fontSize.toInt()}pt',
                value: settings.fontSize,
                min: AppConstants.minFontSize,
                max: AppConstants.maxFontSize,
                divisions: ((AppConstants.maxFontSize - AppConstants.minFontSize) / 2).round(),
                onChanged: (value) {
                  settingsNotifier.setFontSize(value);
                },
              ),
              _SettingsDropdown(
                title: 'Theme',
                subtitle: 'App appearance',
                value: settings.themeMode,
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('System')),
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setThemeMode(value);
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // Translation Settings
          _SettingsSection(
            title: 'Translation',
            children: [
              _SettingsDropdown(
                title: 'Translation Provider',
                subtitle: 'Service used for translation',
                value: settings.translationProvider,
                items: const [
                  DropdownMenuItem(value: 'ml_kit', child: Text('ML Kit (Offline)')),
                  DropdownMenuItem(value: 'google', child: Text('Google Translate')),
                  DropdownMenuItem(value: 'bergamot', child: Text('Bergamot (Web)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setTranslationProvider(value);
                  }
                },
              ),
              _SettingsSwitch(
                title: 'Auto-download Models',
                subtitle: 'Automatically download translation models',
                value: settings.autoDownloadModels,
                onChanged: (value) {
                  settingsNotifier.setAutoDownloadModels(value);
                },
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // Storage Settings
          _SettingsSection(
            title: 'Storage',
            children: [
              _SettingsSlider(
                title: 'Max Storage',
                subtitle: '${settings.maxStorageMB} MB',
                value: settings.maxStorageMB.toDouble(),
                min: AppConstants.minStorageMB.toDouble(),
                max: AppConstants.maxStorageMB.toDouble(),
                divisions: ((AppConstants.maxStorageMB - AppConstants.minStorageMB) / 100).round(),
                onChanged: (value) {
                  settingsNotifier.setMaxStorageMB(value.round());
                },
              ),
            ],
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // About Section
          _SettingsSection(
            title: 'About',
            children: [
              ListTile(
                title: const Text('Version'),
                subtitle: Text(AppConstants.appVersion),
                trailing: const Icon(Icons.info_outline),
              ),
              ListTile(
                title: const Text('Reset Settings'),
                subtitle: const Text('Reset all settings to defaults'),
                trailing: const Icon(Icons.restore),
                onTap: () {
                  _showResetDialog(context, settingsNotifier);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showResetDialog(BuildContext context, SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.resetToDefaults();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  
  const _SettingsSection({
    required this.title,
    required this.children,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: AppConstants.smallPadding),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  
  const _SettingsDropdown({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox(),
      ),
    );
  }
}

class _SettingsSlider extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  
  const _SettingsSlider({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  
  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}