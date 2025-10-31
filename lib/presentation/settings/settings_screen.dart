// Settings Screen
// Elegant user preferences and app configuration with PolyRead design

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/core/providers/settings_provider.dart';
import 'package:polyread/core/themes/polyread_spacing.dart';
import 'package:polyread/core/themes/polyread_typography.dart';
import 'package:polyread/core/utils/constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    
    return Scaffold(
      appBar: _buildElegantAppBar(context),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: PolyReadSpacing.getResponsivePadding(context),
        children: [
          // Header with user welcome
          _buildWelcomeHeader(context),
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          
          // Language Settings
          _ElegantSettingsSection(
            title: 'Language Preferences',
            subtitle: 'Configure your reading and translation languages',
            icon: Icons.language_rounded,
            children: [
              _ElegantDropdown(
                title: 'Reading Language',
                subtitle: 'Primary language of your books',
                icon: Icons.auto_stories_outlined,
                value: settings.defaultSourceLanguage,
                items: AppConstants.supportedLanguages
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Row(
                            children: [
                              Text('🌍', style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: PolyReadSpacing.smallSpacing),
                              Text(AppConstants.languageNames[code] ?? code),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setDefaultSourceLanguage(value);
                  }
                },
              ),
              _ElegantDropdown(
                title: 'Translation Language',
                subtitle: 'Language to translate unknown words to',
                icon: Icons.translate_rounded,
                value: settings.defaultTargetLanguage,
                items: AppConstants.supportedLanguages
                    .where((code) => code != 'auto')
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Row(
                            children: [
                              Text('🗣️', style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: PolyReadSpacing.smallSpacing),
                              Text(AppConstants.languageNames[code] ?? code),
                            ],
                          ),
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
          
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          
          // Reading Experience Settings
          _ElegantSettingsSection(
            title: 'Reading Experience',
            subtitle: 'Customize your reading comfort and appearance',
            icon: Icons.auto_stories_rounded,
            children: [
              _ElegantSlider(
                title: 'Reading Font Size',
                subtitle: 'Adjust text size for comfortable reading',
                icon: Icons.format_size_rounded,
                value: settings.fontSize,
                min: AppConstants.minFontSize,
                max: AppConstants.maxFontSize,
                divisions: ((AppConstants.maxFontSize - AppConstants.minFontSize) / 2).round(),
                valueLabel: '${settings.fontSize.toInt()}pt',
                onChanged: (value) {
                  settingsNotifier.setFontSize(value);
                },
              ),
              _ElegantDropdown(
                title: 'App Theme',
                subtitle: 'Choose your preferred visual appearance',
                icon: Icons.palette_outlined,
                value: settings.themeMode,
                items: const [
                  DropdownMenuItem(
                    value: 'system', 
                    child: Row(
                      children: [
                        Text('🔄', style: TextStyle(fontSize: 20)),
                        SizedBox(width: PolyReadSpacing.smallSpacing),
                        Text('System Default'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'light', 
                    child: Row(
                      children: [
                        Text('☀️', style: TextStyle(fontSize: 20)),
                        SizedBox(width: PolyReadSpacing.smallSpacing),
                        Text('Light Theme'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'dark', 
                    child: Row(
                      children: [
                        Text('🌙', style: TextStyle(fontSize: 20)),
                        SizedBox(width: PolyReadSpacing.smallSpacing),
                        Text('Dark Theme'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setThemeMode(value);
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          
          // Translation Settings
          _ElegantSettingsSection(
            title: 'Translation & Learning',
            subtitle: 'Configure translation services and learning features',
            icon: Icons.translate_rounded,
            children: [
              _ElegantDropdown(
                title: 'Translation Service',
                subtitle: 'Choose your preferred translation provider',
                icon: Icons.cloud_outlined,
                value: settings.translationProvider,
                items: const [
                  DropdownMenuItem(
                    value: 'ml_kit', 
                    child: Row(
                      children: [
                        Text('📱', style: TextStyle(fontSize: 20)),
                        SizedBox(width: PolyReadSpacing.smallSpacing),
                        Text('ML Kit (Offline)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'google', 
                    child: Row(
                      children: [
                        Text('🌐', style: TextStyle(fontSize: 20)),
                        SizedBox(width: PolyReadSpacing.smallSpacing),
                        Text('Google Translate'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'bergamot', 
                    child: Row(
                      children: [
                        Text('🔗', style: TextStyle(fontSize: 20)),
                        SizedBox(width: PolyReadSpacing.smallSpacing),
                        Text('Bergamot (Web)'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setTranslationProvider(value);
                  }
                },
              ),
              _ElegantSwitch(
                title: 'Smart Model Downloads',
                subtitle: 'Automatically download translation models when needed',
                icon: Icons.download_rounded,
                value: settings.autoDownloadModels,
                onChanged: (value) {
                  settingsNotifier.setAutoDownloadModels(value);
                },
              ),
            ],
          ),
          
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          
          // Storage & Performance Settings
          _ElegantSettingsSection(
            title: 'Storage & Performance',
            subtitle: 'Manage app storage and optimize performance',
            icon: Icons.storage_rounded,
            children: [
              _ElegantSlider(
                title: 'Storage Limit',
                subtitle: 'Maximum storage for books and language data',
                icon: Icons.folder_outlined,
                value: settings.maxStorageMB.toDouble(),
                min: AppConstants.minStorageMB.toDouble(),
                max: AppConstants.maxStorageMB.toDouble(),
                divisions: ((AppConstants.maxStorageMB - AppConstants.minStorageMB) / 100).round(),
                valueLabel: '${settings.maxStorageMB} MB',
                onChanged: (value) {
                  settingsNotifier.setMaxStorageMB(value.round());
                },
              ),
            ],
          ),
          
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          
          // About & Support Section
          _ElegantSettingsSection(
            title: 'About PolyRead',
            subtitle: 'App information and support options',
            icon: Icons.info_outline_rounded,
            children: [
              _ElegantInfoTile(
                title: 'App Version',
                subtitle: AppConstants.appVersion,
                icon: Icons.tag_rounded,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PolyReadSpacing.elementSpacing,
                    vertical: PolyReadSpacing.microSpacing,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  ),
                  child: Text(
                    'v${AppConstants.appVersion}',
                    style: PolyReadTypography.interfaceCaption.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _ElegantActionTile(
                title: 'Reset to Defaults',
                subtitle: 'Restore all settings to their original values',
                icon: Icons.restart_alt_rounded,
                onTap: () => _showElegantResetDialog(context, settingsNotifier),
                isDestructive: true,
              ),
            ],
          ),
          
          // Bottom spacing for better scrolling
          const SizedBox(height: PolyReadSpacing.majorSpacing),
        ],
      ),
    );
  }
  
  /// Build elegant app bar
  PreferredSizeWidget _buildElegantAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'Settings',
        style: PolyReadTypography.interfaceTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
    );
  }
  
  /// Build welcome header
  Widget _buildWelcomeHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
        boxShadow: PolyReadSpacing.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(PolyReadSpacing.elementSpacing),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
            ),
            child: Icon(
              Icons.settings_rounded,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: PolyReadSpacing.elementSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize PolyRead',
                  style: PolyReadTypography.interfaceHeadline.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: PolyReadSpacing.microSpacing),
                Text(
                  'Personalize your reading experience',
                  style: PolyReadTypography.interfaceBody.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showElegantResetDialog(BuildContext context, SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PolyReadSpacing.dialogRadius),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: PolyReadSpacing.elementSpacing),
            Text(
              'Reset Settings',
              style: PolyReadTypography.interfaceHeadline,
            ),
          ],
        ),
        content: Text(
          'This will restore all settings to their default values. Your books and vocabulary will not be affected.',
          style: PolyReadTypography.interfaceBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: PolyReadTypography.interfaceButton,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.resetToDefaults();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Settings restored to defaults',
                    style: PolyReadTypography.interfaceBody.copyWith(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(
              'Reset',
              style: PolyReadTypography.interfaceButton,
            ),
          ),
        ],
      ),
    );
  }

}

class _ElegantSettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  
  const _ElegantSettingsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: PolyReadSpacing.elementSpacing),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(PolyReadSpacing.smallSpacing),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: PolyReadSpacing.elementSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PolyReadTypography.interfaceSubheadline.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: PolyReadTypography.interfaceCaption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Elegant card container
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
            boxShadow: PolyReadSpacing.cardShadow,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _ElegantDropdown<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  
  const _ElegantDropdown({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PolyReadSpacing.cardPadding,
          vertical: PolyReadSpacing.smallSpacing,
        ),
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          title,
          style: PolyReadTypography.interfaceBody.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: PolyReadTypography.interfaceCaption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PolyReadSpacing.elementSpacing,
            vertical: PolyReadSpacing.microSpacing,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox(),
            style: PolyReadTypography.interfaceBodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ElegantSlider extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  
  const _ElegantSlider({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: PolyReadSpacing.cardPadding,
        vertical: PolyReadSpacing.elementSpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: PolyReadSpacing.elementSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PolyReadTypography.interfaceBody.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: PolyReadTypography.interfaceCaption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PolyReadSpacing.elementSpacing,
                  vertical: PolyReadSpacing.microSpacing,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                ),
                child: Text(
                  valueLabel,
                  style: PolyReadTypography.interfaceCaption.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PolyReadSpacing.smallSpacing),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              thumbColor: Theme.of(context).colorScheme.primary,
              overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElegantSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  
  const _ElegantSwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PolyReadSpacing.cardPadding,
          vertical: PolyReadSpacing.smallSpacing,
        ),
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          title,
          style: PolyReadTypography.interfaceBody.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: PolyReadTypography.interfaceCaption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          inactiveThumbColor: Theme.of(context).colorScheme.outline,
          inactiveTrackColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _ElegantInfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  
  const _ElegantInfoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PolyReadSpacing.cardPadding,
          vertical: PolyReadSpacing.smallSpacing,
        ),
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          title,
          style: PolyReadTypography.interfaceBody.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: PolyReadTypography.interfaceCaption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

class _ElegantActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  
  const _ElegantActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final color = isDestructive 
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PolyReadSpacing.cardPadding,
            vertical: PolyReadSpacing.elementSpacing,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
              ),
              const SizedBox(width: PolyReadSpacing.elementSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PolyReadTypography.interfaceBody.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: PolyReadTypography.interfaceCaption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}