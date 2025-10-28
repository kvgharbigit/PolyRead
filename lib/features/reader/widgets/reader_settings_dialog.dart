// Reader Settings Dialog
// Provides reading experience customization across all formats

import 'package:flutter/material.dart';
import 'package:polyread/features/reader/models/reader_settings.dart';

class ReaderSettingsDialog extends StatefulWidget {
  final ReaderSettings initialSettings;
  final Function(ReaderSettings) onSettingsChanged;
  
  const ReaderSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
  });

  @override
  State<ReaderSettingsDialog> createState() => _ReaderSettingsDialogState();
}

class _ReaderSettingsDialogState extends State<ReaderSettingsDialog> {
  late ReaderSettings _settings;
  
  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings.copy();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _buildTextSection(),
                  const SizedBox(height: 24),
                  _buildThemeSection(),
                  const SizedBox(height: 24),
                  _buildLayoutSection(),
                  const SizedBox(height: 24),
                  _buildReadingSection(),
                ],
              ),
            ),
            const Divider(),
            _buildActions(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.tune, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Reading Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
  
  Widget _buildTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Text', Icons.text_fields),
        const SizedBox(height: 16),
        
        // Font Size
        _buildSliderSetting(
          title: 'Font Size',
          value: _settings.fontSize,
          min: 12,
          max: 28,
          divisions: 16,
          suffix: 'pt',
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(fontSize: value));
          },
        ),
        
        // Line Height
        _buildSliderSetting(
          title: 'Line Spacing',
          value: _settings.lineHeight,
          min: 1.0,
          max: 2.5,
          divisions: 15,
          suffix: 'x',
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(lineHeight: value));
          },
        ),
        
        // Font Family
        _buildDropdownSetting<String>(
          title: 'Font Family',
          value: _settings.fontFamily,
          items: const [
            'System Default',
            'Georgia',
            'Times New Roman',
            'Arial',
            'Helvetica',
            'Open Sans',
            'Roboto',
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _settings = _settings.copyWith(fontFamily: value));
            }
          },
        ),
      ],
    );
  }
  
  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Theme', Icons.palette),
        const SizedBox(height: 16),
        
        // Reading Theme
        _buildThemeSelector(),
        
        const SizedBox(height: 16),
        
        // Custom brightness (only for custom theme)
        if (_settings.theme == ReaderTheme.custom) ...[
          _buildSliderSetting(
            title: 'Brightness',
            value: _settings.brightness,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            suffix: '',
            onChanged: (value) {
              setState(() => _settings = _settings.copyWith(brightness: value));
            },
          ),
        ],
      ],
    );
  }
  
  Widget _buildLayoutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Layout', Icons.view_column),
        const SizedBox(height: 16),
        
        // Page Margins
        _buildSliderSetting(
          title: 'Page Margins',
          value: _settings.pageMargins,
          min: 8,
          max: 48,
          divisions: 10,
          suffix: 'px',
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(pageMargins: value));
          },
        ),
        
        // Text Alignment
        _buildDropdownSetting<TextAlign>(
          title: 'Text Alignment',
          value: _settings.textAlign,
          items: const [TextAlign.left, TextAlign.justify, TextAlign.center],
          itemBuilder: (align) {
            switch (align) {
              case TextAlign.left:
                return 'Left';
              case TextAlign.justify:
                return 'Justified';
              case TextAlign.center:
                return 'Center';
              default:
                return 'Left';
            }
          },
          onChanged: (value) {
            if (value != null) {
              setState(() => _settings = _settings.copyWith(textAlign: value));
            }
          },
        ),
      ],
    );
  }
  
  Widget _buildReadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Reading', Icons.auto_stories),
        const SizedBox(height: 16),
        
        // Auto-scroll
        _buildSwitchSetting(
          title: 'Auto-scroll',
          subtitle: 'Automatically scroll while reading',
          value: _settings.autoScroll,
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(autoScroll: value));
          },
        ),
        
        // Auto-scroll speed (only if auto-scroll is enabled)
        if (_settings.autoScroll) ...[
          const SizedBox(height: 8),
          _buildSliderSetting(
            title: 'Scroll Speed',
            value: _settings.autoScrollSpeed,
            min: 0.5,
            max: 3.0,
            divisions: 10,
            suffix: 'x',
            onChanged: (value) {
              setState(() => _settings = _settings.copyWith(autoScrollSpeed: value));
            },
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Keep screen on
        _buildSwitchSetting(
          title: 'Keep Screen On',
          subtitle: 'Prevent screen from turning off while reading',
          value: _settings.keepScreenOn,
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(keepScreenOn: value));
          },
        ),
        
        // Full screen mode
        _buildSwitchSetting(
          title: 'Full Screen Mode',
          subtitle: 'Hide status bar and navigation',
          value: _settings.fullScreenMode,
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(fullScreenMode: value));
          },
        ),
      ],
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '${value.toStringAsFixed(suffix == 'pt' || suffix == 'px' ? 0 : 1)}$suffix',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  Widget _buildDropdownSetting<T>({
    required String title,
    required T value,
    required List<T> items,
    String Function(T)? itemBuilder,
    required Function(T?) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        DropdownButton<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemBuilder?.call(item) ?? item.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  Widget _buildSwitchSetting({
    required String title,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  Widget _buildThemeSelector() {
    final themes = [
      (ReaderTheme.light, 'Light', Colors.white, Colors.black),
      (ReaderTheme.sepia, 'Sepia', const Color(0xFFFDF6E3), const Color(0xFF5D4E37)),
      (ReaderTheme.dark, 'Dark', const Color(0xFF1A1A1A), Colors.white),
      (ReaderTheme.custom, 'Custom', Colors.grey.shade300, Colors.grey.shade700),
    ];
    
    return Wrap(
      spacing: 12,
      children: themes.map((theme) {
        final isSelected = _settings.theme == theme.$1;
        
        return GestureDetector(
          onTap: () {
            setState(() => _settings = _settings.copyWith(theme: theme.$1));
          },
          child: Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: theme.$3,
              border: Border.all(
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 3,
                  color: theme.$4,
                  margin: const EdgeInsets.only(bottom: 2),
                ),
                Container(
                  width: 32,
                  height: 2,
                  color: theme.$4.withOpacity(0.7),
                  margin: const EdgeInsets.only(bottom: 2),
                ),
                Container(
                  width: 28,
                  height: 2,
                  color: theme.$4.withOpacity(0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  theme.$2,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.$4,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () {
            setState(() => _settings = ReaderSettings.defaultSettings());
          },
          child: const Text('Reset to Default'),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                widget.onSettingsChanged(_settings);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    );
  }
}