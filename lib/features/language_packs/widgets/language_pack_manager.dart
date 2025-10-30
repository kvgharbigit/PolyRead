// Language Pack Manager - Main UI for browsing and managing language packs
// Shows available packs, download progress, and storage management

import 'dart:async';
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
  final registry_service.LanguagePackRegistryService _registryService = 
      registry_service.LanguagePackRegistryService();
  List<registry_service.LanguagePackInfo>? _availablePacks;
  
  // Progress tracking
  StreamSubscription<DownloadProgress>? _progressSubscription;
  final Map<String, DownloadProgress> _activeProgress = {};
  
  // Error state
  String? _lastError;
  bool _isRetrying = false;
  
  // Animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadAvailablePacks();
    _setupProgressStreaming();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _progressSubscription?.cancel();
    super.dispose();
  }

  /// Setup real-time progress streaming
  void _setupProgressStreaming() {
    final combinedService = ref.read(combinedLanguagePackServiceProvider);
    _progressSubscription = combinedService.progressStream.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _activeProgress[progress.packId] = progress;
          });
          
          // Show completion message
          if (progress.status == DownloadStatus.completed) {
            _showSuccess('${progress.packId} installed successfully!');
            // Auto-cleanup after success
            Timer(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() => _activeProgress.remove(progress.packId));
                ref.read(languagePacksProvider.notifier).refresh();
              }
            });
          }
        }
      },
    );
  }

  Future<void> _loadAvailablePacks() async {
    if (_isRetrying) return;
    
    try {
      setState(() {
        _isRetrying = true;
        _lastError = null;
      });
      
      final packs = await _registryService.getAvailableLanguagePacks();
      
      if (mounted) {
        setState(() {
          _availablePacks = packs;
          _isRetrying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastError = e.toString();
          _isRetrying = false;
        });
      }
    }
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
      onRefresh: () async {
        await _loadAvailablePacks();
        await ref.read(languagePacksProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildPacksList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.translate, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Language Packs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Install dictionary + offline translation models',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                await ref.read(languagePacksProvider.notifier).refresh();
                _showSuccess('Refreshed');
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacksList() {
    // Error state
    if (_lastError != null && _availablePacks == null) {
      return _buildErrorState();
    }
    
    // Loading state
    if (_availablePacks == null) {
      return _buildLoadingState();
    }
    
    // Empty state
    if (_availablePacks!.isEmpty) {
      return _buildEmptyState();
    }
    
    // Packs list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Language Packs',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Download dictionaries and offline translation models',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        ..._availablePacks!.map((pack) => _buildPackTile(pack)),
      ],
    );
  }

  Widget _buildPackTile(registry_service.LanguagePackInfo pack) {
    final packId = '${pack.sourceLanguage}-${pack.targetLanguage}';
    final languagePacksState = ref.watch(languagePacksProvider);
    final combinedService = ref.watch(combinedLanguagePackServiceProvider);
    
    // Check states
    final isInstalled = languagePacksState.installedPackIds.contains(packId);
    final progress = _activeProgress[packId] ?? 
        combinedService.activeDownloads.where((d) => d.packId == packId).firstOrNull;
    final isDownloading = progress?.status == DownloadStatus.downloading || 
                         progress?.status == DownloadStatus.pending;
    final isFailed = progress?.status == DownloadStatus.failed;
    final isComingSoon = pack.priority == 'coming-soon';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildPackIcon(isInstalled, isDownloading, isFailed, isComingSoon, progress),
        title: Text(
          pack.displayLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getStatusText(isInstalled, isDownloading, isFailed, isComingSoon, progress)),
            if (isDownloading && progress != null) _buildProgressIndicator(progress),
          ],
        ),
        trailing: _buildActionButton(
          packId, isInstalled, isDownloading, isFailed, isComingSoon, 
          pack.sourceLanguage, pack.targetLanguage
        ),
        onTap: isInstalled 
            ? () => _showPackDetails(pack.sourceLanguage, pack.targetLanguage, pack.displayLabel)
            : isDownloading || isComingSoon 
                ? null 
                : () => _installPack(pack.sourceLanguage, pack.targetLanguage),
      ),
    );
  }

  Widget _buildPackIcon(bool isInstalled, bool isDownloading, bool isFailed, bool isComingSoon, DownloadProgress? progress) {
    if (isDownloading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          value: progress?.progressPercent != null ? progress!.progressPercent / 100 : null,
          strokeWidth: 3,
        ),
      );
    }
    
    Color backgroundColor;
    IconData iconData;
    Color iconColor;
    
    if (isFailed) {
      backgroundColor = Colors.red.shade100;
      iconData = Icons.error;
      iconColor = Colors.red.shade700;
    } else if (isInstalled) {
      backgroundColor = Colors.green.shade100;
      iconData = Icons.check;
      iconColor = Colors.green.shade700;
    } else if (isComingSoon) {
      backgroundColor = Colors.orange.shade100;
      iconData = Icons.schedule;
      iconColor = Colors.orange.shade700;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      iconData = Icons.download;
      iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    
    return CircleAvatar(
      backgroundColor: backgroundColor,
      child: Icon(iconData, color: iconColor),
    );
  }

  String _getStatusText(bool isInstalled, bool isDownloading, bool isFailed, bool isComingSoon, DownloadProgress? progress) {
    if (isDownloading) {
      final phase = progress != null ? _getProgressPhase(progress) : "Installing";
      final percent = progress?.progressPercent?.toStringAsFixed(0) ?? "0";
      return '$phase • $percent%';
    } else if (isFailed) {
      return 'Installation failed - Tap to retry';
    } else if (isInstalled) {
      return 'Installed • Bidirectional support';
    } else if (isComingSoon) {
      return 'Coming soon';
    } else {
      return 'Vuizur dictionary + ML Kit models';
    }
  }

  Widget _buildProgressIndicator(DownloadProgress progress) {
    return Column(
      children: [
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.progressPercent / 100,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          minHeight: 2,
        ),
      ],
    );
  }

  String _getProgressPhase(DownloadProgress progress) {
    final stageDesc = progress.stageDescription ?? "";
    final currentFile = progress.currentFile ?? "";
    
    // Debug logging (commented out to reduce console spam)
    // print('Phase detection - stageDesc: "$stageDesc", currentFile: "$currentFile", progress: ${progress.progressPercent.toStringAsFixed(1)}%');
    
    // Check stage description first (most reliable)
    if (stageDesc.contains("Preparing") || stageDesc.contains("Starting")) return "Setup";
    if (stageDesc.contains("Checking ML Kit")) return "Setup";
    
    // Downloading phase - only for actual file downloads
    if (stageDesc.contains("Downloading") && (stageDesc.contains("dictionary") || stageDesc.contains("Wiktionary") || stageDesc.contains(".zip"))) return "Downloading";
    
    // Installing phase - database import and processing (most important)
    if (stageDesc.contains("Installing") || stageDesc.contains("Importing") || stageDesc.contains("Processing")) return "Installing";
    if (stageDesc.contains("Extracting") || stageDesc.contains("Loading dictionary")) return "Installing";
    if (stageDesc.contains("entries") || stageDesc.contains("database")) return "Installing";
    
    // ML Kit phase  
    if (stageDesc.contains("ML Kit")) return "ML Kit";
    
    // Completion phase
    if (stageDesc.contains("completed") || stageDesc.contains("Installation completed")) return "Complete";
    
    // Check current file as secondary indicator
    if (currentFile.isNotEmpty) {
      if (currentFile.contains("sqlite") || currentFile.contains(".zip")) return "Downloading";
      if (currentFile == 'ml-kit-models') return "ML Kit";
      if (currentFile == 'installation-complete') return "Complete";
    }
    
    // Fallback based on new progress percentage thresholds
    if (progress.progressPercent < 20) return "Downloading";       // 5-20%
    if (progress.progressPercent < 25) return "Extracting";        // 20-25%
    if (progress.progressPercent < 85) return "Installing";        // 25-85% (Main phase)
    if (progress.progressPercent < 95) return "ML Kit";            // 85-95%
    if (progress.progressPercent >= 95) return "Complete";         // 95-100%
    
    return "Installing";
  }

  Widget _buildActionButton(String packId, bool isInstalled, bool isDownloading, bool isFailed, 
                           bool isComingSoon, String sourceCode, String targetCode) {
    if (isDownloading) {
      return TextButton(
        onPressed: () => _cancelDownload(packId),
        child: const Text('Cancel'),
      );
    } else if (isFailed) {
      return TextButton(
        onPressed: () => _installPack(sourceCode, targetCode),
        child: const Text('Retry'),
      );
    } else if (isInstalled) {
      return PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'uninstall':
              _uninstallPack(sourceCode, targetCode);
              break;
            case 'reinstall':
              _reinstallPack(sourceCode, targetCode);
              break;
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
        ],
      );
    } else if (isComingSoon) {
      return const TextButton(
        onPressed: null,
        child: Text('Coming Soon'),
      );
    } else {
      return ElevatedButton(
        onPressed: () => _installPack(sourceCode, targetCode),
        child: const Text('Install'),
      );
    }
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.verified),
              title: const Text('Validate All Packs'),
              subtitle: const Text('Check integrity of installed packs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _validateAllPacks,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text('Failed to load language packs'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isRetrying ? null : _loadAvailablePacks,
              icon: _isRetrying 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(_isRetrying ? 'Retrying...' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(3, (index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest),
          title: Container(
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Container(
            height: 12,
            width: 200,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No language packs available'),
            SizedBox(height: 8),
            Text('Check back later for new language packs.'),
          ],
        ),
      ),
    );
  }

  // Action methods
  Future<void> _installPack(String sourceLanguage, String targetLanguage) async {
    final packId = '$sourceLanguage-$targetLanguage';
    try {
      await ref.read(languagePacksProvider.notifier).downloadPack(packId);
    } catch (e) {
      _showError('Installation failed: $e');
    }
  }

  Future<void> _cancelDownload(String packId) async {
    await ref.read(languagePacksProvider.notifier).cancelDownload(packId);
  }

  Future<void> _uninstallPack(String sourceLanguage, String targetLanguage) async {
    final confirmed = await _showConfirmDialog(
      'Uninstall Language Pack',
      'Are you sure you want to uninstall the $sourceLanguage ↔ $targetLanguage language pack?',
    );
    
    if (confirmed) {
      try {
        final combinedService = ref.read(combinedLanguagePackServiceProvider);
        await combinedService.removeLanguagePack(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
        await ref.read(languagePacksProvider.notifier).refresh();
        _showSuccess('Uninstalled successfully');
      } catch (e) {
        _showError('Failed to uninstall: $e');
      }
    }
  }

  Future<void> _reinstallPack(String sourceLanguage, String targetLanguage) async {
    try {
      final combinedService = ref.read(combinedLanguagePackServiceProvider);
      await combinedService.removeLanguagePack(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      await _installPack(sourceLanguage, targetLanguage);
      _showSuccess('Reinstallation started');
    } catch (e) {
      _showError('Reinstallation failed: $e');
    }
  }

  Future<void> _validateAllPacks() async {
    try {
      final driftService = DriftLanguagePackService(ref.read(db.databaseProvider));
      final brokenPacks = await driftService.detectBrokenPacks();
      
      if (brokenPacks.isEmpty) {
        _showSuccess('✅ All language packs are valid');
      } else {
        _showError('Found ${brokenPacks.length} broken packs');
      }
    } catch (e) {
      _showError('Validation failed: $e');
    }
  }

  Future<void> _showPackDetails(String sourceCode, String targetCode, String label) async {
    // Simplified pack details - just show basic info
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📊 $label'),
        content: const Text('Pack details will be loaded here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }
}