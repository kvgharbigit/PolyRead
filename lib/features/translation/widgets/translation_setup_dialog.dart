// Translation Setup Dialog
// Unified dialog for setting up both dictionary and ML Kit models

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:polyread/core/services/dictionary_management_service.dart';
import 'package:polyread/features/translation/providers/ml_kit_provider.dart';
import 'package:polyread/core/navigation/app_router.dart';

class TranslationSetupDialog extends StatefulWidget {
  final String sourceLanguage;
  final String targetLanguage;
  final DictionaryManagementService dictionaryService;
  final MlKitTranslationProvider mlKitProvider;
  final VoidCallback? onSetupComplete;
  final String? title;
  final String? subtitle;

  const TranslationSetupDialog({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.dictionaryService,
    required this.mlKitProvider,
    this.onSetupComplete,
    this.title,
    this.subtitle,
  });

  @override
  State<TranslationSetupDialog> createState() => _TranslationSetupDialogState();
}

class _TranslationSetupDialogState extends State<TranslationSetupDialog> {
  bool _isChecking = true;
  bool _isSetupInProgress = false;
  
  // Status tracking
  bool _dictionaryAvailable = false;
  bool _mlKitModelsAvailable = false;
  bool _mlKitSupported = false;
  
  // Setup results
  DictionaryInitializationResult? _dictionaryResult;
  ModelDownloadResult? _mlKitResult;
  
  String _statusMessage = '';
  double _progress = 0.0;
  
  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.title ?? 'Translation Setup';
    final displaySubtitle = widget.subtitle ?? 
        'Setting up translation for ${widget.sourceLanguage.toUpperCase()} → ${widget.targetLanguage.toUpperCase()}';
    
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.translate, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(displayTitle)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (widget.subtitle != null) ...[
              Text(
                displaySubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isChecking) _buildCheckingStatus(),
            if (!_isChecking && !_isSetupInProgress) _buildAvailabilityStatus(),
            if (_isSetupInProgress) _buildSetupProgress(),
            if (!_isSetupInProgress && (_dictionaryResult != null || _mlKitResult != null)) 
              _buildResults(),
              ],
            ),
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildCheckingStatus() {
    return Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Checking translation capabilities for ${widget.sourceLanguage.toUpperCase()} → ${widget.targetLanguage.toUpperCase()}...',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildAvailabilityStatus() {
    final needsSetup = !_dictionaryAvailable || (!_mlKitModelsAvailable && _mlKitSupported);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Translation Status for ${widget.sourceLanguage.toUpperCase()} → ${widget.targetLanguage.toUpperCase()}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Dictionary status
        _buildStatusItem(
          icon: Icons.book,
          title: 'Offline Dictionary',
          subtitle: _dictionaryAvailable 
            ? 'Available for word definitions and translations'
            : 'No language packs installed. Use "Download Packs" below.',
          isAvailable: _dictionaryAvailable,
        ),
        
        const SizedBox(height: 12),
        
        // ML Kit status
        _buildStatusItem(
          icon: Icons.offline_bolt,
          title: 'Offline Translation Models',
          subtitle: _mlKitSupported
            ? (_mlKitModelsAvailable 
                ? 'Models downloaded and ready'
                : 'Models not downloaded - will download automatically')
            : 'Not supported for this language pair',
          isAvailable: _mlKitModelsAvailable,
          isSupported: _mlKitSupported,
        ),
        
        if (needsSetup) ...[
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
                    'Setup will enable offline translation with improved accuracy and speed.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isAvailable,
    bool isSupported = true,
  }) {
    Color color;
    IconData statusIcon;
    
    if (!isSupported) {
      color = Colors.grey;
      statusIcon = Icons.not_interested;
    } else if (isAvailable) {
      color = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      color = Colors.orange;
      statusIcon = Icons.download_outlined;
    }
    
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(statusIcon, color: color, size: 16),
                ],
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetupProgress() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _progress,
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        const SizedBox(height: 16),
        Text(
          _statusMessage.isEmpty ? 'Setting up translation...' : _statusMessage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildResults() {
    final hasErrors = (_dictionaryResult?.success == false) || (_mlKitResult?.success == false);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasErrors 
              ? Colors.red.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                hasErrors ? Icons.warning : Icons.check_circle,
                color: hasErrors ? Colors.red : Colors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasErrors 
                    ? 'Setup completed with some issues'
                    : 'Translation setup completed successfully!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasErrors ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        if (_dictionaryResult != null) ...[
          const SizedBox(height: 8),
          Text(
            'Dictionary: ${_dictionaryResult!.message}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _dictionaryResult!.success ? Colors.green : Colors.red,
            ),
          ),
        ],
        
        if (_mlKitResult != null) ...[
          const SizedBox(height: 4),
          Text(
            'ML Kit: ${_mlKitResult!.success ? "Models downloaded successfully" : "Model download failed"}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _mlKitResult!.success ? Colors.green : Colors.red,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_isChecking || _isSetupInProgress) {
      return [];
    }
    
    final needsSetup = !_dictionaryAvailable || (!_mlKitModelsAvailable && _mlKitSupported);
    final hasResults = _dictionaryResult != null || _mlKitResult != null;
    
    if (!needsSetup || hasResults) {
      return [
        if (hasResults && (_dictionaryResult?.success == false || _mlKitResult?.success == false))
          TextButton(
            onPressed: _performSetup,
            child: const Text('Retry'),
          ),
        ElevatedButton(
          onPressed: () {
            widget.onSetupComplete?.call();
            Navigator.of(context).pop(TranslationSetupResult(
              completed: true,
              dictionaryInitialized: _dictionaryResult?.success ?? _dictionaryAvailable,
              mlKitDownloaded: _mlKitResult?.success ?? _mlKitModelsAvailable,
            ));
          },
          child: const Text('Continue'),
        ),
      ];
    }
    
    return [
      // Add "Go to Settings" button when no dictionary available
      if (!_dictionaryAvailable)
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(TranslationSetupResult(
              completed: false,
              cancelled: false,
              dictionaryInitialized: false,
              mlKitDownloaded: false,
            ));
            // Navigate directly to Language Packs page
            context.go(AppRoutes.languagePacks);
          },
          child: const Text('Go to Language Packs'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(TranslationSetupResult(
          completed: false,
          cancelled: true,
          dictionaryInitialized: false,
          mlKitDownloaded: false,
        )),
        child: const Text('Skip'),
      ),
    ];
  }

  Future<void> _checkAvailability() async {
    try {
      // Check dictionary availability
      final dictionaryStatus = await widget.dictionaryService.getAvailabilityStatus(
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );
      
      // Check ML Kit availability
      final mlKitSupported = await widget.mlKitProvider.supportsLanguagePair(
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );
      
      bool mlKitModelsAvailable = false;
      if (mlKitSupported) {
        mlKitModelsAvailable = await widget.mlKitProvider.areModelsDownloaded(
          sourceLanguage: widget.sourceLanguage,
          targetLanguage: widget.targetLanguage,
        );
      }
      
      if (mounted) {
        setState(() {
          _dictionaryAvailable = dictionaryStatus.isAvailable;
          _mlKitSupported = mlKitSupported;
          _mlKitModelsAvailable = mlKitModelsAvailable;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _statusMessage = 'Error checking availability: $e';
        });
      }
    }
  }

  Future<void> _performSetup() async {
    setState(() {
      _isSetupInProgress = true;
      _progress = 0.0;
      _statusMessage = 'Starting setup...';
      _dictionaryResult = null;
      _mlKitResult = null;
    });

    try {
      // Step 1: Initialize dictionary if needed
      if (!_dictionaryAvailable) {
        setState(() {
          _statusMessage = 'Initializing offline dictionary...';
          _progress = 0.1;
        });
        
        _dictionaryResult = await widget.dictionaryService.initializeRealDictionary(
          onProgress: (message) {
            if (mounted) {
              setState(() {
                _statusMessage = message;
                _progress = 0.1 + (_progress < 0.4 ? 0.1 : 0.0);
              });
            }
          },
        );
        
        setState(() {
          _progress = 0.5;
        });
      }
      
      // Step 2: Download ML Kit models if needed and supported
      if (_mlKitSupported && !_mlKitModelsAvailable) {
        setState(() {
          _statusMessage = 'Downloading offline translation models...';
          _progress = 0.6;
        });
        
        _mlKitResult = await widget.mlKitProvider.downloadModels(
          sourceLanguage: widget.sourceLanguage,
          targetLanguage: widget.targetLanguage,
          wifiOnly: true,
        );
        
        setState(() {
          _progress = 0.9;
        });
      }
      
      setState(() {
        _statusMessage = 'Setup complete!';
        _progress = 1.0;
        _isSetupInProgress = false;
      });
      
    } catch (e) {
      setState(() {
        _isSetupInProgress = false;
        _statusMessage = 'Setup failed: $e';
      });
    }
  }
}

class TranslationSetupResult {
  final bool completed;
  final bool cancelled;
  final bool dictionaryInitialized;
  final bool mlKitDownloaded;
  final String? error;

  const TranslationSetupResult({
    required this.completed,
    this.cancelled = false,
    required this.dictionaryInitialized,
    required this.mlKitDownloaded,
    this.error,
  });
}

/// Show unified translation setup dialog
Future<TranslationSetupResult?> showTranslationSetupDialog({
  required BuildContext context,
  required String sourceLanguage,
  required String targetLanguage,
  required DictionaryManagementService dictionaryService,
  required MlKitTranslationProvider mlKitProvider,
  VoidCallback? onSetupComplete,
  String? title,
  String? subtitle,
}) async {
  return showDialog<TranslationSetupResult>(
    context: context,
    barrierDismissible: false, // Force user to make a choice
    builder: (context) => TranslationSetupDialog(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      dictionaryService: dictionaryService,
      mlKitProvider: mlKitProvider,
      onSetupComplete: onSetupComplete,
      title: title,
      subtitle: subtitle,
    ),
  );
}