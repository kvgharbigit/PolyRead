// Simple Dictionary Initialization Dialog
// Quick dialog to prompt for dictionary initialization when translation fails

import 'package:flutter/material.dart';
import 'package:polyread/core/services/dictionary_loader_service.dart';
import 'package:polyread/core/database/app_database.dart';

class SimpleDictionaryInitDialog extends StatefulWidget {
  final AppDatabase database;
  final VoidCallback? onComplete;

  const SimpleDictionaryInitDialog({
    super.key,
    required this.database,
    this.onComplete,
  });

  @override
  State<SimpleDictionaryInitDialog> createState() => _SimpleDictionaryInitDialogState();
}

class _SimpleDictionaryInitDialogState extends State<SimpleDictionaryInitDialog> {
  bool _isLoading = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dictionary Not Found'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No dictionary entries found. Please download real dictionary data from language packs. Sample dictionaries are not supported.'),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_status),
            ],
          ],
        ],
      ),
      actions: [
        if (!_isLoading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go to Settings'),
          ),
        ],
      ],
    );
  }

  // No longer load fake sample dictionaries - method removed
}

Future<bool?> showSimpleDictionaryInitDialog({
  required BuildContext context,
  required AppDatabase database,
  VoidCallback? onComplete,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SimpleDictionaryInitDialog(
      database: database,
      onComplete: onComplete,
    ),
  );
}