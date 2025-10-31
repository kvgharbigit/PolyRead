// Reader Settings Dialog
// Elegant reading experience customization with PolyRead design

import 'package:flutter/material.dart';
import 'package:polyread/features/reader/models/reader_settings.dart';
import 'package:polyread/core/themes/polyread_spacing.dart';
import 'package:polyread/core/themes/polyread_typography.dart';
import 'package:polyread/core/themes/polyread_theme.dart';

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PolyReadSpacing.dialogRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(PolyReadSpacing.dialogRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElegantHeader(context),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: PolyReadSpacing.sectionSpacing,
                ),
                children: [
                  const SizedBox(height: PolyReadSpacing.elementSpacing),
                  _buildElegantTextSection(),
                  const SizedBox(height: PolyReadSpacing.majorSpacing),
                  _buildElegantThemeSection(),
                  const SizedBox(height: PolyReadSpacing.majorSpacing),
                  _buildElegantLayoutSection(),
                  const SizedBox(height: PolyReadSpacing.majorSpacing),
                  _buildElegantReadingSection(),
                  const SizedBox(height: PolyReadSpacing.majorSpacing),
                ],
              ),
            ),
            _buildElegantActions(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildElegantHeader(BuildContext context) {
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
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
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
              Icons.auto_stories_rounded,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: PolyReadSpacing.elementSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading Preferences',
                  style: PolyReadTypography.interfaceTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: PolyReadSpacing.microSpacing),
                Text(
                  'Customize your perfect reading experience',
                  style: PolyReadTypography.interfaceCaption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
              child: Container(
                padding: const EdgeInsets.all(PolyReadSpacing.smallSpacing),
                child: Icon(
                  Icons.close_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildElegantTextSection() {
    return _buildElegantSection(
      title: 'Typography & Fonts',
      subtitle: 'Customize text appearance for comfortable reading',
      icon: Icons.font_download_rounded,
      children: [
        _buildElegantSlider(
          title: 'Reading Font Size',
          subtitle: 'Adjust text size for your comfort',
          icon: Icons.format_size_rounded,
          value: _settings.fontSize,
          min: 14,
          max: 32,
          divisions: 18,
          suffix: 'pt',
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(fontSize: value));
          },
        ),
        const SizedBox(height: PolyReadSpacing.elementSpacing),
        _buildElegantSlider(
          title: 'Line Spacing',
          subtitle: 'Space between lines for better readability',
          icon: Icons.format_line_spacing_rounded,
          value: _settings.lineHeight,
          min: 1.0,
          max: 2.5,
          divisions: 15,
          suffix: 'x',
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(lineHeight: value));
          },
        ),
        const SizedBox(height: PolyReadSpacing.elementSpacing),
        _buildElegantDropdown(
          title: 'Reading Font',
          subtitle: 'Choose your preferred reading typeface',
          icon: Icons.font_download_outlined,
          value: _settings.fontFamily,
          items: ReaderSettings.availableFonts,
          onChanged: (value) {
            if (value != null) {
              setState(() => _settings = _settings.copyWith(fontFamily: value));
            }
          },
        ),
      ],
    );
  }
  
  Widget _buildElegantThemeSection() {
    return _buildElegantSection(
      title: 'Reading Themes',
      subtitle: 'Choose colors optimized for different reading conditions',
      icon: Icons.palette_rounded,
      children: [
        _buildElegantThemeSelector(),
        
        if (_settings.theme == ReadingThemeType.custom) ...[
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          _buildElegantSlider(
            title: 'Custom Brightness',
            subtitle: 'Adjust brightness level for your environment',
            icon: Icons.brightness_6_rounded,
            value: _settings.brightness,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            suffix: '%',
            onChanged: (value) {
              setState(() => _settings = _settings.copyWith(brightness: value));
            },
          ),
        ],
      ],
    );
  }
  
  Widget _buildElegantLayoutSection() {
    return _buildElegantSection(
      title: 'Layout & Spacing',
      subtitle: 'Optimize page layout for your reading comfort',
      icon: Icons.view_column_rounded,
      children: [
        _buildElegantSlider(
          title: 'Page Margins',
          subtitle: 'Space around text content',
          icon: Icons.border_all_rounded,
          value: _settings.pageMargins,
          min: 16,
          max: 64,
          divisions: 12,
          suffix: 'px',
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(pageMargins: value));
          },
        ),
        const SizedBox(height: PolyReadSpacing.elementSpacing),
        _buildElegantDropdown<TextAlign>(
          title: 'Text Alignment',
          subtitle: 'How text is aligned on the page',
          icon: Icons.format_align_left_rounded,
          value: _settings.textAlign,
          items: const [TextAlign.left, TextAlign.justify, TextAlign.center],
          itemBuilder: (align) {
            switch (align) {
              case TextAlign.left:
                return 'Left Aligned';
              case TextAlign.justify:
                return 'Justified';
              case TextAlign.center:
                return 'Centered';
              default:
                return 'Left Aligned';
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
  
  Widget _buildElegantReadingSection() {
    return _buildElegantSection(
      title: 'Reading Behavior',
      subtitle: 'Configure reading assistance and display options',
      icon: Icons.auto_stories_rounded,
      children: [
        _buildElegantSwitch(
          title: 'Auto-Scroll Reading',
          subtitle: 'Automatically scroll through content while reading',
          icon: Icons.fast_forward_rounded,
          value: _settings.autoScroll,
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(autoScroll: value));
          },
        ),
        
        if (_settings.autoScroll) ...[
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          _buildElegantSlider(
            title: 'Auto-Scroll Speed',
            subtitle: 'How fast content scrolls automatically',
            icon: Icons.speed_rounded,
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
        
        const SizedBox(height: PolyReadSpacing.elementSpacing),
        
        _buildElegantSwitch(
          title: 'Keep Screen Awake',
          subtitle: 'Prevent screen from dimming during reading sessions',
          icon: Icons.lightbulb_outline_rounded,
          value: _settings.keepScreenOn,
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(keepScreenOn: value));
          },
        ),
        
        const SizedBox(height: PolyReadSpacing.elementSpacing),
        
        _buildElegantSwitch(
          title: 'Immersive Reading Mode',
          subtitle: 'Hide system UI for distraction-free reading',
          icon: Icons.fullscreen_rounded,
          value: _settings.fullScreenMode,
          onChanged: (value) {
            setState(() => _settings = _settings.copyWith(fullScreenMode: value));
          },
        ),
      ],
    );
  }
  
  /// Build elegant section container with header and content
  Widget _buildElegantSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
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
  
  /// Build elegant slider with descriptive labels and value display
  Widget _buildElegantSlider({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
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
                  '${value.toStringAsFixed(suffix == 'pt' || suffix == 'px' ? 0 : 1)}$suffix',
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
  
  /// Build elegant dropdown with icon and descriptive labels
  Widget _buildElegantDropdown<T>({
    required String title,
    required String subtitle,
    required IconData icon,
    required T value,
    required List<T> items,
    String Function(T)? itemBuilder,
    required ValueChanged<T?> onChanged,
  }) {
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
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemBuilder?.call(item) ?? item.toString(),
                  style: PolyReadTypography.interfaceBodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            underline: const SizedBox(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build elegant switch with icon and descriptive labels
  Widget _buildElegantSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
  
  /// Build elegant theme selector with PolyRead themes
  Widget _buildElegantThemeSelector() {
    final themes = [
      (ReadingThemeType.warmLight, 'Warm Light', const Color(0xFFFDF6E3), const Color(0xFF2E2A24)),
      (ReadingThemeType.trueDark, 'True Dark', const Color(0xFF1A1A1A), const Color(0xFFE8E6E3)),
      (ReadingThemeType.enhancedSepia, 'Enhanced Sepia', const Color(0xFFF4ECD8), const Color(0xFF5D4E37)),
      (ReadingThemeType.blueFilter, 'Blue Filter', const Color(0xFFFFF8E1), const Color(0xFF3E2723)),
      (ReadingThemeType.custom, 'Custom', Colors.grey.shade300, Colors.grey.shade700),
    ];
    
    return Container(
      padding: const EdgeInsets.all(PolyReadSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading Themes',
            style: PolyReadTypography.interfaceBody.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          Wrap(
            spacing: PolyReadSpacing.elementSpacing,
            runSpacing: PolyReadSpacing.elementSpacing,
            children: themes.map((theme) {
              final isSelected = _settings.theme == theme.$1;
              
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _settings = _settings.copyWith(theme: theme.$1));
                  },
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  child: Container(
                    width: 90,
                    height: 70,
                    decoration: BoxDecoration(
                      color: theme.$3,
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                      boxShadow: isSelected 
                          ? PolyReadSpacing.subtleShadow 
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Text preview lines
                        Container(
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: theme.$4,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                          margin: const EdgeInsets.only(bottom: 3),
                        ),
                        Container(
                          width: 36,
                          height: 2,
                          decoration: BoxDecoration(
                            color: theme.$4.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(1),
                          ),
                          margin: const EdgeInsets.only(bottom: 3),
                        ),
                        Container(
                          width: 32,
                          height: 2,
                          decoration: BoxDecoration(
                            color: theme.$4.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          theme.$2,
                          style: PolyReadTypography.interfaceCaption.copyWith(
                            fontSize: 10,
                            color: theme.$4,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// Build elegant action buttons for dialog
  Widget _buildElegantActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Reset button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _settings = ReaderSettings.defaultSettings());
              },
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PolyReadSpacing.elementSpacing,
                  vertical: PolyReadSpacing.smallSpacing,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: PolyReadSpacing.microSpacing),
                    Text(
                      'Reset',
                      style: PolyReadTypography.interfaceButton.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Action buttons
          Row(
            children: [
              // Cancel button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PolyReadSpacing.elementSpacing,
                      vertical: PolyReadSpacing.smallSpacing,
                    ),
                    child: Text(
                      'Cancel',
                      style: PolyReadTypography.interfaceButton.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: PolyReadSpacing.elementSpacing),
              
              // Apply button
              Material(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                child: InkWell(
                  onTap: () {
                    widget.onSettingsChanged(_settings);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PolyReadSpacing.sectionSpacing,
                      vertical: PolyReadSpacing.elementSpacing,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        const SizedBox(width: PolyReadSpacing.microSpacing),
                        Text(
                          'Apply Settings',
                          style: PolyReadTypography.interfaceButton.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}