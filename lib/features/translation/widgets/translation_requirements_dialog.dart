// Unified Translation Requirements Dialog
// Handles missing dictionaries, ML Kit models, and other translation prerequisites

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum MissingComponent {
  dictionary,
  mlKitModel,
  both,
}

class TranslationRequirementsDialog extends StatelessWidget {
  final String sourceLanguage;
  final String targetLanguage;
  final MissingComponent missingComponent;
  final String? specificLanguagePack; // e.g., "es-en" for dictionary

  const TranslationRequirementsDialog({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.missingComponent,
    this.specificLanguagePack,
  });

  String get _languagePairName {
    final sourceMap = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'ar': 'Arabic',
      'ru': 'Russian',
    };
    
    final sourceName = sourceMap[sourceLanguage] ?? sourceLanguage.toUpperCase();
    final targetName = sourceMap[targetLanguage] ?? targetLanguage.toUpperCase();
    
    return '$sourceName → $targetName';
  }

  String get _title {
    switch (missingComponent) {
      case MissingComponent.dictionary:
        return 'Dictionary Required';
      case MissingComponent.mlKitModel:
        return 'Translation Model Required';
      case MissingComponent.both:
        return 'Translation Components Required';
    }
  }

  String get _description {
    switch (missingComponent) {
      case MissingComponent.dictionary:
        return 'A dictionary is required for offline translation from $_languagePairName.';
      case MissingComponent.mlKitModel:
        return 'Translation models are required for offline translation from $_languagePairName.';
      case MissingComponent.both:
        return 'Both dictionary and translation models are required for offline translation from $_languagePairName.';
    }
  }

  List<String> get _missingItems {
    switch (missingComponent) {
      case MissingComponent.dictionary:
        return ['${specificLanguagePack ?? '$sourceLanguage-$targetLanguage'} Dictionary Pack'];
      case MissingComponent.mlKitModel:
        return ['$_languagePairName ML Kit Models (~30-40 MB)'];
      case MissingComponent.both:
        return [
          '${specificLanguagePack ?? '$sourceLanguage-$targetLanguage'} Dictionary Pack',
          '$_languagePairName ML Kit Models (~30-40 MB)'
        ];
    }
  }

  String get _primaryAction {
    switch (missingComponent) {
      case MissingComponent.dictionary:
        return 'Install Dictionary';
      case MissingComponent.mlKitModel:
        return 'Download Models';
      case MissingComponent.both:
        return 'Install Components';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            missingComponent == MissingComponent.dictionary
                ? Icons.book_outlined
                : Icons.download_outlined,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_title),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Missing Components',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._missingItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Install components to enable offline translation',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => _navigateToInstallation(context),
          child: Text(_primaryAction),
        ),
      ],
    );
  }

  void _navigateToInstallation(BuildContext context) {
    Navigator.of(context).pop(true);
    
    switch (missingComponent) {
      case MissingComponent.dictionary:
      case MissingComponent.both:
        // Navigate to Language Pack Manager
        context.push('/language-packs');
        break;
      case MissingComponent.mlKitModel:
        // For ML Kit only, could navigate to a specific ML Kit download page
        // or to language packs page as well since it's unified
        context.push('/language-packs');
        break;
    }
  }
}

/// Show unified translation requirements dialog
Future<bool> showTranslationRequirementsDialog({
  required BuildContext context,
  required String sourceLanguage,
  required String targetLanguage,
  required MissingComponent missingComponent,
  String? specificLanguagePack,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => TranslationRequirementsDialog(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      missingComponent: missingComponent,
      specificLanguagePack: specificLanguagePack,
    ),
  );

  return result ?? false;
}