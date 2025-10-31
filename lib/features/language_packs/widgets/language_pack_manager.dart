// Language Pack Manager - Elegant UI for browsing and managing language packs
// Enhanced with PolyRead design system for premium experience

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/download_progress.dart';
import 'storage_chart.dart';
import '../providers/language_packs_provider.dart';
import '../services/drift_language_pack_service.dart';
import '../services/language_pack_registry_service.dart' as registry_service;
import '../../../core/providers/database_provider.dart' as db;
import '../../../core/themes/polyread_spacing.dart';
import '../../../core/themes/polyread_typography.dart';

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
  
  // Timer to prevent memory leaks from auto-cleanup timers
  Timer? _cleanupTimer;

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
    _cleanupTimer?.cancel(); // Prevent memory leaks from timers
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
            // Auto-cleanup after success with proper timer management
            _cleanupTimer?.cancel(); // Cancel any existing timer
            _cleanupTimer = Timer(const Duration(seconds: 2), () {
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
      appBar: _buildElegantAppBar(context),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLanguagePacksTab(),
          _buildStorageTab(),
        ],
      ),
    );
  }
  
  /// Build elegant app bar with tabs
  PreferredSizeWidget _buildElegantAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'Language Packs',
        style: PolyReadTypography.interfaceTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Theme.of(context).colorScheme.primary,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        labelStyle: PolyReadTypography.interfaceBodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: PolyReadTypography.interfaceBodyMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.translate_rounded),
            text: 'Language Packs',
          ),
          Tab(
            icon: Icon(Icons.storage_rounded),
            text: 'Storage',
          ),
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
        physics: const BouncingScrollPhysics(),
        padding: PolyReadSpacing.getResponsivePadding(context),
        children: [
          _buildElegantHeader(),
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          _buildPacksList(),
        ],
      ),
    );
  }

  /// Build elegant header with welcome message and refresh action
  Widget _buildElegantHeader() {
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
        borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
        boxShadow: PolyReadSpacing.subtleShadow,
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
              Icons.translate_rounded,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: PolyReadSpacing.elementSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language Packs',
                  style: PolyReadTypography.interfaceHeadline.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: PolyReadSpacing.microSpacing),
                Text(
                  'Install dictionaries and offline translation models for enhanced reading',
                  style: PolyReadTypography.interfaceBody.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await ref.read(languagePacksProvider.notifier).refresh();
                _showSuccess('Refreshed');
              },
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
              child: Container(
                padding: const EdgeInsets.all(PolyReadSpacing.smallSpacing),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPacksList() {
    // Error state
    if (_lastError != null && _availablePacks == null) {
      return _buildElegantErrorState();
    }
    
    // Loading state (initial load or retry)
    if (_availablePacks == null || _isRetrying) {
      return _buildElegantLoadingState();
    }
    
    // Empty state
    if (_availablePacks!.isEmpty) {
      return _buildElegantEmptyState();
    }
    
    // Packs list
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
                  Icons.download_rounded,
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
                      'Available Language Packs',
                      style: PolyReadTypography.interfaceSubheadline.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Tap to install • Swipe for options',
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
        
        // Elegant pack list container
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
            child: Column(
              children: _availablePacks!.asMap().entries.map((entry) {
                final index = entry.key;
                final pack = entry.value;
                final isLast = index == _availablePacks!.length - 1;
                return _buildElegantPackTile(pack, isLast);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Build elegant pack tile with enhanced visual design
  Widget _buildElegantPackTile(registry_service.LanguagePackInfo pack, bool isLast) {
    final packId = '${pack.sourceLanguage}-${pack.targetLanguage}';
    final languagePacksState = ref.watch(languagePacksProvider);
    final combinedService = ref.watch(combinedLanguagePackServiceProvider);
    
    // Check states
    final isInstalled = languagePacksState.installedPackIds.contains(packId);
    final progress = _activeProgress[packId] ?? 
        combinedService.activeDownloads[packId];
    final isDownloading = progress?.status == DownloadStatus.downloading || 
                         progress?.status == DownloadStatus.pending;
    final isFailed = progress?.status == DownloadStatus.failed;
    final isComingSoon = pack.priority == 'coming-soon';

    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInstalled 
              ? () => _showElegantPackDetails(pack.sourceLanguage, pack.targetLanguage, pack.displayLabel)
              : isDownloading || isComingSoon 
                  ? null 
                  : () => _installPack(pack.sourceLanguage, pack.targetLanguage),
          child: Padding(
            padding: const EdgeInsets.all(PolyReadSpacing.cardPadding),
            child: Row(
              children: [
                _buildElegantPackIcon(isInstalled, isDownloading, isFailed, isComingSoon, progress),
                const SizedBox(width: PolyReadSpacing.elementSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.displayLabel,
                        style: PolyReadTypography.interfaceBody.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: PolyReadSpacing.microSpacing),
                      Text(
                        _getElegantStatusText(isInstalled, isDownloading, isFailed, isComingSoon, progress),
                        style: PolyReadTypography.interfaceCaption.copyWith(
                          color: _getStatusColor(context, isInstalled, isDownloading, isFailed, isComingSoon),
                        ),
                      ),
                      if (isDownloading && progress != null) ...[
                        const SizedBox(height: PolyReadSpacing.microSpacing),
                        _buildElegantProgressIndicator(progress),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: PolyReadSpacing.elementSpacing),
                _buildElegantActionButton(
                  packId, isInstalled, isDownloading, isFailed, isComingSoon, 
                  pack.sourceLanguage, pack.targetLanguage
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build elegant pack icon with enhanced visual states
  Widget _buildElegantPackIcon(bool isInstalled, bool isDownloading, bool isFailed, bool isComingSoon, DownloadProgress? progress) {
    if (isDownloading) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: progress?.progressPercent != null ? progress!.progressPercent / 100 : null,
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            Icon(
              Icons.download_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
    }
    
    Color backgroundColor;
    IconData iconData;
    Color iconColor;
    
    if (isFailed) {
      backgroundColor = Theme.of(context).colorScheme.errorContainer;
      iconData = Icons.error_outline_rounded;
      iconColor = Theme.of(context).colorScheme.error;
    } else if (isInstalled) {
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
      iconData = Icons.check_circle_outline_rounded;
      iconColor = Theme.of(context).colorScheme.primary;
    } else if (isComingSoon) {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      iconData = Icons.schedule_rounded;
      iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      iconData = Icons.download_rounded;
      iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
      ),
      child: Icon(
        iconData, 
        color: iconColor,
        size: 24,
      ),
    );
  }

  /// Get elegant status text with enhanced descriptions
  String _getElegantStatusText(bool isInstalled, bool isDownloading, bool isFailed, bool isComingSoon, DownloadProgress? progress) {
    if (isDownloading) {
      final phase = progress != null ? _getProgressPhase(progress) : "Installing";
      final percent = progress != null ? progress.progressPercent.toStringAsFixed(0) : "0";
      return '$phase • $percent% complete';
    } else if (isFailed) {
      return 'Installation failed • Tap to retry';
    } else if (isInstalled) {
      return '✨ Installed • Bidirectional translation ready';
    } else if (isComingSoon) {
      return '🚧 Coming soon • Check back later';
    } else {
      return '📚 Vuizur dictionary + offline ML Kit models';
    }
  }
  
  /// Get color for status text based on state
  Color _getStatusColor(BuildContext context, bool isInstalled, bool isDownloading, bool isFailed, bool isComingSoon) {
    if (isFailed) {
      return Theme.of(context).colorScheme.error;
    } else if (isInstalled) {
      return Theme.of(context).colorScheme.primary;
    } else if (isDownloading) {
      return Theme.of(context).colorScheme.primary;
    } else {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  /// Build elegant progress indicator with enhanced styling
  Widget _buildElegantProgressIndicator(DownloadProgress progress) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progress.progressPercent / 100,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
          minHeight: 6,
        ),
      ),
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

  /// Build elegant action button with enhanced styling
  Widget _buildElegantActionButton(String packId, bool isInstalled, bool isDownloading, bool isFailed, 
                           bool isComingSoon, String sourceCode, String targetCode) {
    if (isDownloading) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _cancelDownload(packId),
          borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PolyReadSpacing.elementSpacing,
              vertical: PolyReadSpacing.smallSpacing,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: PolyReadSpacing.microSpacing),
                Text(
                  'Cancel',
                  style: PolyReadTypography.interfaceCaption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (isFailed) {
      return Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
        child: InkWell(
          onTap: () => _installPack(sourceCode, targetCode),
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
                  size: 16,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: PolyReadSpacing.microSpacing),
                Text(
                  'Retry',
                  style: PolyReadTypography.interfaceCaption.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
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
        icon: Container(
          padding: const EdgeInsets.all(PolyReadSpacing.smallSpacing),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
          ),
          child: Icon(
            Icons.more_vert_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'reinstall',
            child: Row(
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: PolyReadSpacing.elementSpacing),
                Text(
                  'Reinstall',
                  style: PolyReadTypography.interfaceBody.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'uninstall',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: PolyReadSpacing.elementSpacing),
                Text(
                  'Uninstall',
                  style: PolyReadTypography.interfaceBody.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (isComingSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PolyReadSpacing.elementSpacing,
          vertical: PolyReadSpacing.smallSpacing,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
        ),
        child: Text(
          'Soon',
          style: PolyReadTypography.interfaceCaption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      return Material(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
        child: InkWell(
          onTap: () => _installPack(sourceCode, targetCode),
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
                  Icons.download_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: PolyReadSpacing.microSpacing),
                Text(
                  'Install',
                  style: PolyReadTypography.interfaceCaption.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildStorageTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: PolyReadSpacing.getResponsivePadding(context),
      children: [
        const StorageChart(),
        const SizedBox(height: PolyReadSpacing.majorSpacing),
        _buildElegantStorageActions(),
      ],
    );
  }

  /// Build elegant storage management section
  Widget _buildElegantStorageActions() {
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
                  Icons.settings_rounded,
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
                      'Storage Management',
                      style: PolyReadTypography.interfaceSubheadline.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Maintain and optimize your language packs',
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
        
        // Elegant actions container
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _validateAllPacks,
                child: Padding(
                  padding: const EdgeInsets.all(PolyReadSpacing.cardPadding),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(PolyReadSpacing.smallSpacing),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                        ),
                        child: Icon(
                          Icons.verified_rounded,
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
                              'Validate All Packs',
                              style: PolyReadTypography.interfaceBody.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: PolyReadSpacing.microSpacing),
                            Text(
                              'Check integrity and repair corrupted language packs',
                              style: PolyReadTypography.interfaceCaption.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build elegant error state with retry option
  Widget _buildElegantErrorState() {
    return Container(
      padding: const EdgeInsets.all(PolyReadSpacing.majorSpacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          Text(
            'Connection Error',
            style: PolyReadTypography.interfaceHeadline.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          Text(
            'Failed to load available language packs. Please check your internet connection and try again.',
            style: PolyReadTypography.interfaceBody.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          Material(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
            child: InkWell(
              onTap: _isRetrying ? null : _loadAvailablePacks,
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PolyReadSpacing.sectionSpacing,
                  vertical: PolyReadSpacing.elementSpacing,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRetrying)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    else
                      Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    const SizedBox(width: PolyReadSpacing.smallSpacing),
                    Text(
                      _isRetrying ? 'Retrying...' : 'Try Again',
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
    );
  }

  /// Build elegant loading state with clear loading indicator
  Widget _buildElegantLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
        boxShadow: PolyReadSpacing.cardShadow,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PolyReadSpacing.majorSpacing),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading spinner
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: PolyReadSpacing.sectionSpacing),
            
            // Loading text
            Text(
              'Fetching Available Language Packs...',
              style: PolyReadTypography.interfaceHeadline.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PolyReadSpacing.elementSpacing),
            
            // Subtitle
            Text(
              'Checking GitHub for the latest dictionary packages',
              style: PolyReadTypography.interfaceCaption.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build elegant shimmer loading state for when showing placeholders
  Widget _buildShimmerLoadingState() {
    return Container(
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
        child: Column(
          children: List.generate(3, (index) {
            final isLast = index == 2;
            return Container(
              decoration: BoxDecoration(
                border: isLast ? null : Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(PolyReadSpacing.cardPadding),
              child: Row(
                children: [
                  // Leading icon placeholder
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                    ),
                  ),
                  const SizedBox(width: PolyReadSpacing.elementSpacing),
                  // Content placeholder
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: PolyReadSpacing.microSpacing),
                        Container(
                          height: 12,
                          width: 180,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: PolyReadSpacing.elementSpacing),
                  // Trailing button placeholder
                  Container(
                    width: 60,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Build elegant empty state
  Widget _buildElegantEmptyState() {
    return Container(
      padding: const EdgeInsets.all(PolyReadSpacing.majorSpacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          Text(
            'No Language Packs Available',
            style: PolyReadTypography.interfaceHeadline.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          Text(
            'Language packs are being prepared and will be available soon. Check back later for new translation options.',
            style: PolyReadTypography.interfaceBody.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

  /// Show elegant pack details dialog
  Future<void> _showElegantPackDetails(String sourceCode, String targetCode, String label) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PolyReadSpacing.dialogRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(PolyReadSpacing.dialogRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
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
                        Icons.info_outline_rounded,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: PolyReadSpacing.elementSpacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: PolyReadTypography.interfaceHeadline.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: PolyReadSpacing.microSpacing),
                          Text(
                            'Language Pack Details',
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
              
              // Content
              Padding(
                padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
                child: Column(
                  children: [
                    _buildDetailRow('Status', '✅ Installed and Ready'),
                    _buildDetailRow('Features', '🔄 Bidirectional Translation'),
                    _buildDetailRow('Dictionary', '📚 Vuizur Wiktionary Database'),
                    _buildDetailRow('Offline Mode', '📱 ML Kit Models Included'),
                  ],
                ),
              ),
              
              // Actions
              Container(
                padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PolyReadSpacing.sectionSpacing,
                            vertical: PolyReadSpacing.elementSpacing,
                          ),
                          child: Text(
                            'Close',
                            style: PolyReadTypography.interfaceButton.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build detail row for pack information
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PolyReadSpacing.elementSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: PolyReadTypography.interfaceBody.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: PolyReadTypography.interfaceBody.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Elegant helper methods
  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Theme.of(context).colorScheme.onInverseSurface,
                size: 20,
              ),
              const SizedBox(width: PolyReadSpacing.elementSpacing),
              Expanded(
                child: Text(
                  message,
                  style: PolyReadTypography.interfaceBody.copyWith(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
          ),
          margin: PolyReadSpacing.getResponsivePadding(context),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 20,
              ),
              const SizedBox(width: PolyReadSpacing.elementSpacing),
              Expanded(
                child: Text(
                  message,
                  style: PolyReadTypography.interfaceBody.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
          ),
          margin: PolyReadSpacing.getResponsivePadding(context),
        ),
      );
    }
  }

  /// Show elegant confirmation dialog
  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PolyReadSpacing.dialogRadius),
        ),
        child: Container(
          padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(PolyReadSpacing.dialogRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: PolyReadSpacing.elementSpacing),
                  Expanded(
                    child: Text(
                      title,
                      style: PolyReadTypography.interfaceHeadline.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PolyReadSpacing.majorSpacing),
              Text(
                content,
                style: PolyReadTypography.interfaceBody.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: PolyReadSpacing.majorSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, false),
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
                  Material(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, true),
                      borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PolyReadSpacing.sectionSpacing,
                          vertical: PolyReadSpacing.elementSpacing,
                        ),
                        child: Text(
                          'Confirm',
                          style: PolyReadTypography.interfaceButton.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }
}