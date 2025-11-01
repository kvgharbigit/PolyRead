// Compact Language Pack Manager - Minimalist design with full functionality
// Streamlined UI that removes redundancy while maintaining all features

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_progress.dart';
import '../providers/language_packs_provider.dart';
import '../services/language_pack_registry_service.dart' as registry_service;

class LanguagePackManager extends ConsumerStatefulWidget {
  const LanguagePackManager({super.key});

  @override
  ConsumerState<LanguagePackManager> createState() => _LanguagePackManagerState();
}

class _LanguagePackManagerState extends ConsumerState<LanguagePackManager> {
  final registry_service.LanguagePackRegistryService _registryService = 
      registry_service.LanguagePackRegistryService();
  List<registry_service.LanguagePackInfo>? _availablePacks;
  
  StreamSubscription<DownloadProgress>? _progressSubscription;
  final Map<String, DownloadProgress> _activeProgress = {};
  final Map<String, bool> _checkingInstallation = {};
  final Map<String, bool> _stuckInstallations = {};
  String? _lastError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPacks();
    _setupProgressStreaming();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _setupProgressStreaming() {
    final combinedService = ref.read(combinedLanguagePackServiceProvider);
    _progressSubscription = combinedService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _activeProgress[progress.packId] = progress;
          // Clear stuck installation flag when we get new progress
          _stuckInstallations.remove(progress.packId);
        });
        
        if (progress.status == DownloadStatus.completed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${progress.packId} installed successfully!'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _activeProgress.remove(progress.packId);
                _stuckInstallations.remove(progress.packId);
              });
              ref.read(languagePacksProvider.notifier).refresh();
            }
          });
        } else if (progress.status == DownloadStatus.failed) {
          // Mark as stuck if download failed
          setState(() => _stuckInstallations[progress.packId] = true);
        }
      }
    });
  }

  Future<void> _loadPacks() async {
    try {
      setState(() => _isLoading = true);
      final packs = await _registryService.getAvailableLanguagePacks();
      if (mounted) {
        setState(() {
          _availablePacks = packs;
          _isLoading = false;
          _lastError = null;
        });
        
        // Check for stuck installations after loading packs
        _checkForStuckInstallations();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Check for installations that might be stuck (progress shown but actually complete)
  void _checkForStuckInstallations() {
    if (_activeProgress.isEmpty) return;
    
    final combinedService = ref.read(combinedLanguagePackServiceProvider);
    final languagePacksState = ref.read(languagePacksProvider);
    
    for (final entry in _activeProgress.entries) {
      final packId = entry.key;
      final progress = entry.value;
      
      // If progress shows downloading but pack is actually installed, mark as stuck
      if (progress.status == DownloadStatus.downloading && 
          languagePacksState.installedPackIds.contains(packId)) {
        setState(() => _stuckInstallations[packId] = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Packs'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // Clear any stuck states when manually refreshing
              setState(() {
                _activeProgress.clear();
                _stuckInstallations.clear();
                _checkingInstallation.clear();
              });
              
              await _loadPacks();
              await ref.read(languagePacksProvider.notifier).refresh();
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final languagePacksState = ref.watch(languagePacksProvider);
    
    if (_lastError != null && _availablePacks == null) {
      return _buildErrorState();
    }
    
    if (_isLoading || languagePacksState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_availablePacks?.isEmpty ?? true) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadPacks();
        await ref.read(languagePacksProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildPacksList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.translate_rounded,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Dictionaries',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Install language packs for offline translation',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Widget _buildPacksList() {
    return Column(
      children: _availablePacks!.map((pack) => _buildPackTile(pack)).toList(),
    );
  }

  Widget _buildPackTile(registry_service.LanguagePackInfo pack) {
    final packId = '${pack.sourceLanguage}-${pack.targetLanguage}';
    final languagePacksState = ref.watch(languagePacksProvider);
    final combinedService = ref.watch(combinedLanguagePackServiceProvider);
    
    final isInstalled = languagePacksState.installedPackIds.contains(packId);
    final isCheckingInstallation = _checkingInstallation[packId] ?? false;
    final progress = _activeProgress[packId] ?? combinedService.activeDownloads[packId];
    final isDownloading = progress?.status == DownloadStatus.downloading || 
                         progress?.status == DownloadStatus.pending;
    final isFailed = progress?.status == DownloadStatus.failed;
    final isComingSoon = pack.priority == 'coming-soon';
    final isStuck = _stuckInstallations[packId] ?? false;
    
    // Auto-detect stuck installation: showing progress but actually installed
    final autoDetectedStuck = isDownloading && isInstalled && !isStuck;
    if (autoDetectedStuck) {
      // Mark as stuck and clear progress
      Future.microtask(() {
        setState(() {
          _stuckInstallations[packId] = true;
          _activeProgress.remove(packId);
        });
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: isStuck
            ? () => _showStuckInstallationDialog(pack)
            : isInstalled 
                ? () => _showPackDetails(pack)
                : isDownloading || isComingSoon || isCheckingInstallation
                    ? null 
                    : () => _downloadPack(pack),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Language flag/icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isInstalled 
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isCheckingInstallation
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        isStuck 
                            ? Icons.error_outline
                            : isInstalled 
                                ? Icons.check_circle 
                                : Icons.language,
                        color: isStuck
                            ? Theme.of(context).colorScheme.error
                            : isInstalled 
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(width: 16),
              
              // Pack info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.displayLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPackSubtitle(pack, isInstalled, isDownloading, isComingSoon, isCheckingInstallation, isStuck),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isDownloading && progress != null) ...[
                      const SizedBox(height: 8),
                      _buildProgressIndicator(progress),
                    ],
                  ],
                ),
              ),
              
              // Status/Action
              _buildActionButton(pack, isInstalled, isDownloading, isFailed, isComingSoon, isCheckingInstallation, isStuck),
            ],
          ),
        ),
      ),
    );
  }

  String _getPackSubtitle(
    registry_service.LanguagePackInfo pack, 
    bool isInstalled, 
    bool isDownloading, 
    bool isComingSoon,
    bool isCheckingInstallation,
    bool isStuck,
  ) {
    if (isStuck) return 'Installation stuck - tap to fix';
    if (isComingSoon) return 'Coming soon';
    if (isCheckingInstallation) return 'Checking installation status...';
    if (isInstalled) return 'Installed • ${(pack.sizeMb).toStringAsFixed(1)}MB';
    if (isDownloading) return 'Downloading...';
    return '${(pack.sizeMb).toStringAsFixed(1)}MB • ${pack.entries.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} words';
  }

  Widget _buildProgressIndicator(DownloadProgress progress) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress.progressPercent / 100,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.progressPercent.toInt()}%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    registry_service.LanguagePackInfo pack,
    bool isInstalled,
    bool isDownloading,
    bool isFailed,
    bool isComingSoon,
    bool isCheckingInstallation,
    bool isStuck,
  ) {
    if (isComingSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Soon',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (isStuck) {
      return Icon(
        Icons.build,
        color: Theme.of(context).colorScheme.error,
        size: 20,
      );
    }

    if (isCheckingInstallation) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (isDownloading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (isInstalled) {
      return IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showPackOptions(pack),
        iconSize: 20,
      );
    }

    return IconButton(
      icon: Icon(
        isFailed ? Icons.refresh : Icons.download,
        color: isFailed 
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
      onPressed: () => _downloadPack(pack),
      iconSize: 20,
    );
  }

  Future<void> _downloadPack(registry_service.LanguagePackInfo pack) async {
    final packId = '${pack.sourceLanguage}-${pack.targetLanguage}';
    final combinedService = ref.read(combinedLanguagePackServiceProvider);
    
    print('📱 UI DOWNLOAD: Starting download for $packId');
    print('📱 UI DOWNLOAD: Pack info - ${pack.displayLabel}, ${pack.sizeMb}MB, ${pack.entries} entries');
    
    // Show checking state first
    setState(() {
      _checkingInstallation[packId] = true;
    });
    print('📱 UI STATE: Set checking installation to true for $packId');
    
    try {
      print('📱 UI INSTALL: Calling installLanguagePack service...');
      await combinedService.installLanguagePack(
        sourceLanguage: pack.sourceLanguage,
        targetLanguage: pack.targetLanguage,
      );
      
      print('📱 UI INSTALL: Installation completed successfully for $packId');
      
      // Clear checking state on success
      setState(() {
        _checkingInstallation.remove(packId);
      });
      print('📱 UI STATE: Cleared checking installation for $packId');
    } catch (e) {
      print('📱 UI ERROR: Installation failed for $packId: $e');
      
      // Clear checking state on error
      setState(() {
        _checkingInstallation.remove(packId);
      });
      print('📱 UI STATE: Cleared checking installation for $packId (error)');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showStuckInstallationDialog(registry_service.LanguagePackInfo pack) {
    final packId = '${pack.sourceLanguage}-${pack.targetLanguage}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Installation Issue'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The installation of ${pack.displayLabel} appears to be stuck or incomplete.'),
              const SizedBox(height: 16),
              const Text('What would you like to do?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearStuckInstallation(packId);
            },
            child: const Text('Clear Progress'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryInstallation(pack);
            },
            child: const Text('Retry Install'),
          ),
        ],
      ),
    );
  }

  void _clearStuckInstallation(String packId) {
    setState(() {
      _activeProgress.remove(packId);
      _stuckInstallations.remove(packId);
      _checkingInstallation.remove(packId);
    });
    
    // Refresh the language packs state
    ref.read(languagePacksProvider.notifier).refresh();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Installation progress cleared for $packId'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _retryInstallation(registry_service.LanguagePackInfo pack) async {
    final packId = '${pack.sourceLanguage}-${pack.targetLanguage}';
    
    // Clear stuck state first
    setState(() {
      _activeProgress.remove(packId);
      _stuckInstallations.remove(packId);
      _checkingInstallation.remove(packId);
    });
    
    // Try to remove any partial installation
    try {
      final combinedService = ref.read(combinedLanguagePackServiceProvider);
      await combinedService.removeLanguagePack(
        sourceLanguage: pack.sourceLanguage,
        targetLanguage: pack.targetLanguage,
      );
    } catch (e) {
      print('Warning: Failed to clean up partial installation: $e');
    }
    
    // Retry the installation
    await _downloadPack(pack);
  }

  void _showPackDetails(registry_service.LanguagePackInfo pack) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pack.displayLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Size: ${(pack.sizeMb).toStringAsFixed(1)}MB'),
            Text('Dictionary Count: ${pack.entries.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} entries'),
            const Text('Status: Installed'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPackOptions(registry_service.LanguagePackInfo pack) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Details'),
              onTap: () {
                Navigator.of(context).pop();
                _showPackDetails(pack);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Remove Pack',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _removePack(pack),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _removePack(registry_service.LanguagePackInfo pack) async {
    Navigator.of(context).pop();
    
    final packId = '${pack.sourceLanguage}-${pack.targetLanguage}';
    print('📱 UI REMOVE: Starting removal process for $packId');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Language Pack'),
        content: Text('Remove ${pack.displayLabel}? This will delete the offline dictionary.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      print('📱 UI REMOVE: User confirmed removal of $packId');
      try {
        final combinedService = ref.read(combinedLanguagePackServiceProvider);
        print('📱 UI REMOVE: Calling removeLanguagePack service...');
        await combinedService.removeLanguagePack(
          sourceLanguage: pack.sourceLanguage,
          targetLanguage: pack.targetLanguage,
        );
        print('📱 UI REMOVE: Service call completed, refreshing provider state...');
        await ref.read(languagePacksProvider.notifier).refresh();
        print('📱 UI REMOVE: Provider state refreshed');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${pack.displayLabel} removed'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          print('📱 UI REMOVE: Success snackbar shown');
        }
      } catch (e) {
        print('📱 UI REMOVE ERROR: Failed to remove $packId: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove pack: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          print('📱 UI REMOVE ERROR: Error snackbar shown');
        }
      }
    } else {
      print('📱 UI REMOVE: User cancelled removal of $packId');
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load language packs',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _lastError ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPacks,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.language_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Language Packs Available',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPacks,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}