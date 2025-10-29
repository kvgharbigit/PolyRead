// Dictionary Initialization Dialog
// Shows dialog to prompt user to initialize dictionary when not available

import 'package:flutter/material.dart';
import 'package:polyread/core/services/dictionary_management_service.dart';

class DictionaryInitializationDialog extends StatefulWidget {
  final String sourceLanguage;
  final String targetLanguage;
  final DictionaryManagementService dictionaryService;
  final VoidCallback? onInitializationComplete;

  const DictionaryInitializationDialog({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.dictionaryService,
    this.onInitializationComplete,
  });

  @override
  State<DictionaryInitializationDialog> createState() => _DictionaryInitializationDialogState();
}

class _DictionaryInitializationDialogState extends State<DictionaryInitializationDialog> {
  bool _isInitializing = false;
  String _statusMessage = '';
  DictionaryInitializationResult? _result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.book, color: Colors.blue),
          SizedBox(width: 8),
          Text('Dictionary Not Available'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No dictionary data is available for ${widget.sourceLanguage.toUpperCase()} → ${widget.targetLanguage.toUpperCase()} translation.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to initialize the built-in sample dictionary? This includes common words and phrases for offline translation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sample dictionary includes ~60 common English-Spanish words and phrases.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isInitializing) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  LinearProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage.isEmpty ? 'Initializing dictionary...' : _statusMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _result!.success 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _result!.success ? Icons.check_circle : Icons.error,
                      color: _result!.success ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _result!.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _result!.success ? Colors.green : Colors.red,
                        ),
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
        if (!_isInitializing && _result == null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              UserDictionaryInitializationResult(initialized: false),
            ),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: _initializeDictionary,
            child: const Text('Initialize Dictionary'),
          ),
        ] else if (_result != null) ...[
          if (!_result!.success)
            TextButton(
              onPressed: _initializeDictionary,
              child: const Text('Retry'),
            ),
          ElevatedButton(
            onPressed: () {
              widget.onInitializationComplete?.call();
              Navigator.of(context).pop(
                UserDictionaryInitializationResult(
                  initialized: _result!.success,
                  entriesLoaded: _result!.entriesLoaded,
                ),
              );
            },
            child: Text(_result!.success ? 'Continue' : 'Close'),
          ),
        ],
      ],
    );
  }

  Future<void> _initializeDictionary() async {
    setState(() {
      _isInitializing = true;
      _statusMessage = '';
      _result = null;
    });

    try {
      final result = await widget.dictionaryService.initializeSampleDictionary(
        forceReload: false,
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _statusMessage = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _result = DictionaryInitializationResult(
            success: false,
            entriesLoaded: 0,
            message: 'Failed to initialize dictionary: $e',
            error: e.toString(),
          );
        });
      }
    }
  }
}

class UserDictionaryInitializationResult {
  final bool initialized;
  final int entriesLoaded;
  final String? error;

  const UserDictionaryInitializationResult({
    required this.initialized,
    this.entriesLoaded = 0,
    this.error,
  });
}

/// Show dictionary initialization dialog
Future<UserDictionaryInitializationResult?> showDictionaryInitializationDialog({
  required BuildContext context,
  required String sourceLanguage,
  required String targetLanguage,
  required DictionaryManagementService dictionaryService,
  VoidCallback? onInitializationComplete,
}) async {
  return showDialog<UserDictionaryInitializationResult>(
    context: context,
    barrierDismissible: false, // Force user to make a choice
    builder: (context) => DictionaryInitializationDialog(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      dictionaryService: dictionaryService,
      onInitializationComplete: onInitializationComplete,
    ),
  );
}