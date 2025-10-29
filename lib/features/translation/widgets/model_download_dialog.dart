// Model Download Dialog
// Prompts user to download ML Kit translation models

import 'package:flutter/material.dart';
import 'package:polyread/features/translation/providers/ml_kit_provider.dart';

class ModelDownloadDialog extends StatefulWidget {
  final String sourceLanguage;
  final String targetLanguage;
  final MlKitTranslationProvider mlKitProvider;
  final VoidCallback? onDownloadComplete;

  const ModelDownloadDialog({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.mlKitProvider,
    this.onDownloadComplete,
  });

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  bool _downloadCompleted = false;

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
    
    final sourceName = sourceMap[widget.sourceLanguage] ?? widget.sourceLanguage.toUpperCase();
    final targetName = sourceMap[widget.targetLanguage] ?? widget.targetLanguage.toUpperCase();
    
    return '$sourceName → $targetName';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.download,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Download Translation Models'),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isDownloading && !_downloadCompleted) ...[
              Text(
                'Translation models are required for offline translation from $_languagePairName.',
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
                          'Download Details',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Size: ~30-40 MB per language\n'
                      '• Works offline after download\n'
                      '• One-time download per language pair\n'
                      '• Recommended for frequent translation',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isDownloading) ...[
              Text(
                'Downloading $_languagePairName translation models...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _downloadProgress > 0
                    ? '${(_downloadProgress * 100).toInt()}% complete'
                    : 'Preparing download...',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (_downloadCompleted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Complete!',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_languagePairName models are ready for offline translation.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading && !_downloadCompleted) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: _startDownload,
            child: const Text('Download'),
          ),
        ] else if (_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ] else if (_downloadCompleted) ...[
          FilledButton(
            onPressed: () {
              widget.onDownloadComplete?.call();
              Navigator.of(context).pop(true);
            },
            child: const Text('Continue'),
          ),
        ],
      ],
    );
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      // Start download with progress tracking
      await widget.mlKitProvider.downloadModels(
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      // Download completed successfully
      setState(() {
        _isDownloading = false;
        _downloadCompleted = true;
      });

    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorStr.contains('storage') || errorStr.contains('space')) {
      return 'Insufficient storage space. Please free up some space.';
    } else if (errorStr.contains('wifi')) {
      return 'Download requires Wi-Fi connection for large files.';
    } else {
      return 'Download failed. Please try again later.';
    }
  }
}

class UserModelDownloadResult {
  final bool downloaded;
  final bool userCancelled;
  final String? errorMessage;

  const UserModelDownloadResult({
    required this.downloaded,
    required this.userCancelled,
    this.errorMessage,
  });

  factory UserModelDownloadResult.success() {
    return const UserModelDownloadResult(
      downloaded: true,
      userCancelled: false,
    );
  }

  factory UserModelDownloadResult.cancelled() {
    return const UserModelDownloadResult(
      downloaded: false,
      userCancelled: true,
    );
  }

  factory UserModelDownloadResult.error(String message) {
    return UserModelDownloadResult(
      downloaded: false,
      userCancelled: false,
      errorMessage: message,
    );
  }
}

/// Show model download dialog and return the result
Future<UserModelDownloadResult> showModelDownloadDialog({
  required BuildContext context,
  required String sourceLanguage,
  required String targetLanguage,
  required MlKitTranslationProvider mlKitProvider,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ModelDownloadDialog(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      mlKitProvider: mlKitProvider,
    ),
  );

  if (result == true) {
    return UserModelDownloadResult.success();
  } else {
    return UserModelDownloadResult.cancelled();
  }
}