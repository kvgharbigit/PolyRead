// Language Pack Manager - Main UI for browsing and managing language packs
// Shows available packs, download progress, and storage management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_progress.dart';
import 'storage_chart.dart';
import '../providers/language_packs_provider.dart';
import '../services/drift_language_pack_service.dart';
import '../services/language_pack_registry_service.dart' as registry_service;
import '../../../core/providers/database_provider.dart' as db;


class LanguagePackManager extends ConsumerStatefulWidget {
  const LanguagePackManager({super.key});

  @override
  ConsumerState<LanguagePackManager> createState() => _LanguagePackManagerState();
}

class _LanguagePackManagerState extends ConsumerState<LanguagePackManager>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final registry_service.LanguagePackRegistryService _registryService = registry_service.LanguagePackRegistryService();
  List<registry_service.LanguagePackInfo>? _availablePacks;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAvailablePacks();
  }
  
  Future<void> _loadAvailablePacks() async {
    try {
      final packs = await _registryService.getAvailableLanguagePacks();
      if (mounted) {
        setState(() {
          _availablePacks = packs;
        });
      }
    } catch (e) {
      print('LanguagePackManager: Failed to load available packs: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Packs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.translate), text: 'Language Packs'),
            Tab(icon: Icon(Icons.storage), text: 'Storage'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLanguagePacksTab(),
          _buildStorageTab(),
        ],
      ),
    );
  }

  Widget _buildLanguagePacksTab() {
    return RefreshIndicator(
      onRefresh: _refreshAvailablePacks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLanguagePacksList(),
        ],
      ),
    );
  }

  Widget _buildLanguagePacksList() {
    return Column(
      children: [
        // Header with refresh button
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.translate,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language Packs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Install dictionary + offline translation models',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await ref.read(languagePacksProvider.notifier).refresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Refreshed')),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Language packs list with progress stream
        StreamBuilder<DownloadProgress>(
          stream: ref.watch(combinedLanguagePackServiceProvider).progressStream,
          builder: (context, progressSnapshot) {
            // Load available language packs from registry
            return _buildAvailableLanguagePacks();
          },
        ),
      ],
    );
  }

  Widget _buildAvailableLanguagePacks() {
    if (_availablePacks == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading available language packs...'),
            ],
          ),
        ),
      );
    }
    
    if (_availablePacks!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.warning, size: 48, color: Colors.orange),
              SizedBox(height: 16),
              Text('No language packs available'),
              SizedBox(height: 8),
              Text('Check your internet connection or try again later.'),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: [
        // Available packs section
        Text(
          'Available Language Packs',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Download dictionaries and offline translation models',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        
        // Available packs
        ..._availablePacks!.map((pack) => _buildLanguagePackTile(
          pack.displayLabel,
          pack.sourceLanguage,
          pack.targetLanguage,
          description: pack.displayDescription,
          priority: pack.priority,
        )),
      ],
    );
  }

  Widget _buildLanguagePackTile(
    String label, 
    String sourceCode, 
    String targetCode, {
    String? description,
    String priority = 'medium',
  }) {
    final packId = '$sourceCode-$targetCode';
    final languagePacksState = ref.watch(languagePacksProvider);
    final combinedService = ref.watch(combinedLanguagePackServiceProvider);
    
    // Check if this pack is installed (bidirectional support)
    final reversePackId = '$targetCode-$sourceCode';
    final isInstalled = languagePacksState.installedPackIds.contains(packId) || 
                       languagePacksState.installedPackIds.contains(reversePackId);
    
    // Get download progress if it exists
    DownloadProgress? downloadProgress;
    try {
      downloadProgress = combinedService.activeDownloads.firstWhere((download) => 
          download.packId == packId || download.packId == reversePackId);
    } catch (e) {
      downloadProgress = null;
    }
    
    // Check download state
    final isDownloading = downloadProgress?.status == DownloadStatus.downloading;
    final isFailed = downloadProgress?.status == DownloadStatus.failed;
    final isComingSoon = priority == 'coming-soon';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDownloading
              ? Theme.of(context).colorScheme.primaryContainer
              : isFailed
                  ? Colors.red.shade100
                  : isInstalled 
                      ? Colors.green.shade100
                      : isComingSoon
                          ? Colors.orange.shade100
                          : Theme.of(context).colorScheme.surfaceVariant,
          child: isDownloading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: downloadProgress?.progressPercent != null 
                        ? downloadProgress!.progressPercent / 100 
                        : null,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  isFailed 
                      ? Icons.error 
                      : isInstalled 
                          ? Icons.check
                          : isComingSoon
                              ? Icons.schedule
                              : Icons.download,
                  color: isFailed
                      ? Colors.red.shade700
                      : isInstalled 
                          ? Colors.green.shade700
                          : isComingSoon
                              ? Colors.orange.shade700
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          isDownloading
              ? '${downloadProgress?.stageDescription ?? "Downloading..."} • ${downloadProgress?.progressPercent.toStringAsFixed(1) ?? "0.0"}%'
              : isFailed
                  ? 'Installation failed - Tap to retry'
                  : isInstalled 
                      ? 'Installed • Bidirectional support'
                      : isComingSoon
                          ? description ?? 'Coming soon'
                          : description ?? 'Dictionary + ML Kit models • ~50MB',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDownloading
                ? Theme.of(context).colorScheme.primary
                : isFailed
                    ? Colors.red.shade700
                    : isInstalled 
                        ? Colors.green.shade700
                        : isComingSoon
                            ? Colors.orange.shade700
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: _buildActionWidget(isInstalled, isDownloading, isFailed, downloadProgress, sourceCode, targetCode, isComingSoon),
        onTap: isInstalled || isDownloading || isComingSoon ? null : () => _installLanguagePair(sourceCode, targetCode),
      ),
    );
  }


  


  Widget _buildStorageTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StorageChart(),
        const SizedBox(height: 16),
        _buildStorageActions(),
      ],
    );
  }

  Widget _buildStorageActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('Clean Up Unused Packs'),
              subtitle: const Text('Remove packs not used in 30 days'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _cleanupStorage,
            ),
            ListTile(
              leading: const Icon(Icons.verified),
              title: const Text('Validate All Packs'),
              subtitle: const Text('Check integrity of installed packs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _validateAllPacks,
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Storage Settings'),
              subtitle: const Text('Configure storage limits and behavior'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openStorageSettings,
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _installLanguagePair(String sourceLanguage, String targetLanguage) async {
    print('');
    print('LanguagePackManager._installLanguagePair: Called with source=$sourceLanguage, target=$targetLanguage');
    
    final packId = '$sourceLanguage-$targetLanguage';
    print('LanguagePackManager._installLanguagePair: Generated pack ID: $packId');
    
    await _installLanguagePack(packId);
    
    print('LanguagePackManager._installLanguagePair: Completed for $packId');
  }

  Future<void> _uninstallLanguagePair(String sourceLanguage, String targetLanguage) async {
    print('');
    print('LanguagePackManager._uninstallLanguagePair: Called with source=$sourceLanguage, target=$targetLanguage');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall Language Pack'),
        content: Text('Are you sure you want to uninstall the $sourceLanguage ↔ $targetLanguage language pack?\\n\\nThis will remove both dictionary data and ML Kit models.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final combinedService = ref.read(combinedLanguagePackServiceProvider);
        await combinedService.removeLanguagePack(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        // Refresh the provider state
        await ref.read(languagePacksProvider.notifier).refresh();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uninstalled $sourceLanguage-$targetLanguage successfully')),
          );
        }
      } catch (e) {
        print('LanguagePackManager._uninstallLanguagePair: Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to uninstall: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _reinstallLanguagePair(String sourceLanguage, String targetLanguage) async {
    print('');
    print('LanguagePackManager._reinstallLanguagePair: Called with source=$sourceLanguage, target=$targetLanguage');
    
    try {
      // First uninstall
      final combinedService = ref.read(combinedLanguagePackServiceProvider);
      await combinedService.removeLanguagePack(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      
      // Then install
      await _installLanguagePair(sourceLanguage, targetLanguage);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reinstallation completed')),
        );
      }
    } catch (e) {
      print('LanguagePackManager._reinstallLanguagePair: Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reinstallation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildActionWidget(
    bool isInstalled, 
    bool isDownloading, 
    bool isFailed,
    DownloadProgress? downloadProgress,
    String sourceCode, 
    String targetCode,
    bool isComingSoon,
  ) {
    if (isDownloading && downloadProgress != null) {
      // Show cancel button during download
      return TextButton(
        onPressed: () => _cancelDownload('$sourceCode-$targetCode'),
        child: const Text('Cancel'),
      );
    } else if (isFailed) {
      // Show retry button for failed downloads
      return TextButton(
        onPressed: () {
          // Clear the failed download and retry
          _clearFailedDownload('$sourceCode-$targetCode');
          _installLanguagePair(sourceCode, targetCode);
        },
        child: const Text('Retry'),
      );
    } else if (isInstalled) {
      // Show menu for installed packs
      return PopupMenuButton<String>(
        onSelected: (action) {
          if (action == 'uninstall') {
            _uninstallLanguagePair(sourceCode, targetCode);
          } else if (action == 'reinstall') {
            _reinstallLanguagePair(sourceCode, targetCode);
          } else if (action == 'force-remove') {
            _forceRemoveLanguagePair(sourceCode, targetCode);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'reinstall',
            child: ListTile(
              leading: Icon(Icons.refresh),
              title: Text('Reinstall'),
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: 'uninstall',
            child: ListTile(
              leading: Icon(Icons.delete),
              title: Text('Uninstall'),
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: 'force-remove',
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Force Remove', style: TextStyle(color: Colors.red)),
              dense: true,
            ),
          ),
        ],
      );
    } else if (isComingSoon) {
      // Show coming soon indicator
      return TextButton(
        onPressed: null,
        child: Text(
          'Coming Soon',
          style: TextStyle(color: Colors.orange.shade700),
        ),
      );
    } else {
      // Show install button for available packs
      return ElevatedButton(
        onPressed: () => _installLanguagePair(sourceCode, targetCode),
        child: const Text('Install'),
      );
    }
  }

  Future<void> _forceRemoveLanguagePair(String sourceLanguage, String targetLanguage) async {
    print('');
    print('LanguagePackManager._forceRemoveLanguagePair: Called with source=$sourceLanguage, target=$targetLanguage');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Remove Language Pack'),
        content: Text('This will force remove ALL data for $sourceLanguage ↔ $targetLanguage, including:\n\n• Database entries\n• Downloaded files\n• Registry entries\n• ML Kit models\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Force Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        print('LanguagePackManager._forceRemoveLanguagePair: Starting force removal...');
        
        // Use the service's remove method which should handle cleanup
        final combinedService = ref.read(combinedLanguagePackServiceProvider);
        await combinedService.removeLanguagePack(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        
        // Force refresh the provider state multiple times to ensure UI updates
        print('LanguagePackManager._forceRemoveLanguagePair: Refreshing provider state...');
        await ref.read(languagePacksProvider.notifier).refresh();
        
        // Wait a moment and refresh again to ensure state is updated
        await Future.delayed(const Duration(milliseconds: 500));
        await ref.read(languagePacksProvider.notifier).refresh();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Force removed $sourceLanguage-$targetLanguage successfully')),
          );
        }
        
        print('LanguagePackManager._forceRemoveLanguagePair: Force removal completed');
      } catch (e) {
        print('LanguagePackManager._forceRemoveLanguagePair: Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Force removal completed with warnings: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  // Action methods
  Future<void> _refreshAvailablePacks() async {
    await _loadAvailablePacks();
    await ref.read(languagePacksProvider.notifier).refresh();
  }

  /// Install a language pack (combined dictionary + ML Kit)
  Future<void> _installLanguagePack(String packId) async {
    print('');
    print('========================================');
    print('LanguagePackManager: STARTING INSTALLATION');
    print('LanguagePackManager: Pack ID: $packId');
    print('LanguagePackManager: Timestamp: ${DateTime.now().toIso8601String()}');
    print('========================================');
    
    try {
      print('LanguagePackManager: Step 1 - Calling provider downloadPack...');
      print('LanguagePackManager: Provider state before call: ${ref.read(languagePacksProvider)}');
      
      await ref.read(languagePacksProvider.notifier).downloadPack(packId);
      
      print('');
      print('LanguagePackManager: Step 2 - Download call completed successfully');
      print('LanguagePackManager: Provider state after call: ${ref.read(languagePacksProvider)}');
      print('LanguagePackManager: SUCCESS - Installation process completed');
      
      if (mounted) {
        print('LanguagePackManager: Showing success snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Language pack installation started!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('LanguagePackManager: WARNING - Widget not mounted, skipping snackbar');
      }
    } catch (e) {
      print('');
      print('LanguagePackManager: ❌ INSTALLATION FAILED ❌');
      print('LanguagePackManager: Error: $e');
      print('LanguagePackManager: Error type: ${e.runtimeType}');
      print('LanguagePackManager: Stack trace:');
      print(StackTrace.current);
      
      if (mounted) {
        print('LanguagePackManager: Showing error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        print('LanguagePackManager: WARNING - Widget not mounted, skipping error snackbar');
      }
    }
    
    print('========================================');
    print('LanguagePackManager: INSTALLATION PROCESS ENDED');
    print('========================================');
    print('');
  }



  Future<void> _cancelDownload(String packId) async {
    await ref.read(languagePacksProvider.notifier).cancelDownload(packId);
  }

  void _clearFailedDownload(String packId) {
    final combinedService = ref.read(combinedLanguagePackServiceProvider);
    combinedService.clearFailedDownload(packId);
  }



  void _cleanupStorage() {
    // Clean up unused storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleaning up storage...')),
    );
  }

  Future<void> _validateAllPacks() async {
    print('LanguagePackManager._validateAllPacks: Starting validation...');
    
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Validating all packs...')),
      );
    }
    
    try {
      final driftService = DriftLanguagePackService(ref.read(db.databaseProvider));
      
      // Detect broken packs
      final brokenPacks = await driftService.detectBrokenPacks();
      
      if (mounted) {
        if (brokenPacks.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All language packs are valid'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Show dialog with broken packs and repair options
          _showBrokenPacksDialog(brokenPacks);
        }
      }
      
    } catch (e) {
      print('LanguagePackManager._validateAllPacks: Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showBrokenPacksDialog(List<String> brokenPacks) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broken Language Packs Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following language packs have issues:'),
            const SizedBox(height: 8),
            ...brokenPacks.map((packId) => Text('• $packId')),
            const SizedBox(height: 16),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _repairBrokenPacks(brokenPacks);
            },
            child: const Text('Repair All'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _removeBrokenPacks(brokenPacks);
            },
            child: const Text('Remove All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _repairBrokenPacks(List<String> brokenPacks) async {
    print('LanguagePackManager._repairBrokenPacks: Repairing ${brokenPacks.length} packs...');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repairing ${brokenPacks.length} broken packs...')),
      );
    }
    
    for (final packId in brokenPacks) {
      try {
        // Extract language codes and reinstall
        final parts = packId.split('-');
        if (parts.length >= 2) {
          await _reinstallLanguagePair(parts[0], parts[1]);
        }
      } catch (e) {
        print('LanguagePackManager._repairBrokenPacks: Failed to repair $packId: $e');
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Repair completed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  Future<void> _removeBrokenPacks(List<String> brokenPacks) async {
    print('LanguagePackManager._removeBrokenPacks: Removing ${brokenPacks.length} packs...');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removing ${brokenPacks.length} broken packs...')),
      );
    }
    
    for (final packId in brokenPacks) {
      try {
        // Extract language codes and force remove
        final parts = packId.split('-');
        if (parts.length >= 2) {
          await _forceRemoveLanguagePair(parts[0], parts[1]);
        }
      } catch (e) {
        print('LanguagePackManager._removeBrokenPacks: Failed to remove $packId: $e');
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Broken packs removed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _openStorageSettings() {
    // Open storage settings
  }

}