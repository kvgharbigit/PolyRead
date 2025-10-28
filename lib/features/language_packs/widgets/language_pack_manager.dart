// Language Pack Manager - Main UI for browsing and managing language packs
// Shows available packs, download progress, and storage management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/language_pack_manifest.dart';
import '../models/download_progress.dart';
import 'download_progress_card.dart';
import 'storage_chart.dart';

// Temporary model classes (to be moved to separate files)
enum PackInstallationStatus { installed, updating, corrupted }

class LanguagePackInstallation {
  final String packId;
  final String version;
  final DateTime installedAt;
  final DateTime lastUsed;
  final PackInstallationStatus status;
  final List<String> installedFiles;
  final int totalSize;
  
  const LanguagePackInstallation({
    required this.packId,
    required this.version,
    required this.installedAt,
    required this.lastUsed,
    required this.status,
    required this.installedFiles,
    required this.totalSize,
  });
}

class LanguagePackManager extends ConsumerStatefulWidget {
  const LanguagePackManager({super.key});

  @override
  ConsumerState<LanguagePackManager> createState() => _LanguagePackManagerState();
}

class _LanguagePackManagerState extends ConsumerState<LanguagePackManager>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(icon: Icon(Icons.cloud_download), text: 'Available'),
            Tab(icon: Icon(Icons.download_done), text: 'Installed'),
            Tab(icon: Icon(Icons.storage), text: 'Storage'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableTab(),
          _buildInstalledTab(),
          _buildStorageTab(),
        ],
      ),
    );
  }

  Widget _buildAvailableTab() {
    return RefreshIndicator(
      onRefresh: _refreshAvailablePacks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildQuickInstallSection(),
          const SizedBox(height: 16),
          _buildAvailablePacksList(),
        ],
      ),
    );
  }

  Widget _buildQuickInstallSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Install',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Popular language pairs for quick setup',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickInstallChip('English-Spanish', 'en-es'),
                _buildQuickInstallChip('English-French', 'en-fr'),
                _buildQuickInstallChip('English-German', 'en-de'),
                _buildQuickInstallChip('English-Japanese', 'en-ja'),
                _buildQuickInstallChip('Spanish-English', 'es-en'),
                _buildQuickInstallChip('French-English', 'fr-en'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInstallChip(String label, String packId) {
    return ActionChip(
      avatar: const Icon(Icons.download, size: 18),
      label: Text(label),
      onPressed: () => _installLanguagePack(packId),
    );
  }

  Widget _buildAvailablePacksList() {
    final availablePacks = _getMockAvailablePacks();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Available Packs',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...availablePacks.map((pack) => _buildPackCard(pack)),
      ],
    );
  }

  Widget _buildPackCard(LanguagePackManifest pack) {
    final isInstalled = _isPackInstalled(pack.id);
    final hasUpdate = _hasUpdateAvailable(pack.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showPackDetails(pack),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.translate,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pack.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isInstalled) ...[
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (hasUpdate) ...[
                              Icon(
                                Icons.update,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pack.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(pack.language.toUpperCase()),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pack.formattedSize,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'v${pack.version}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const Spacer(),
                  if (isInstalled && hasUpdate)
                    OutlinedButton(
                      onPressed: () => _updateLanguagePack(pack.id),
                      child: const Text('Update'),
                    )
                  else if (isInstalled)
                    OutlinedButton(
                      onPressed: () => _uninstallLanguagePack(pack.id),
                      child: const Text('Remove'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _installLanguagePack(pack.id),
                      child: const Text('Install'),
                    ),
                ],
              ),
              if (pack.supportedTargetLanguages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Supports: ${pack.supportedTargetLanguages.take(3).join(', ')}${pack.supportedTargetLanguages.length > 3 ? ' +${pack.supportedTargetLanguages.length - 3} more' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstalledTab() {
    final installedPacks = _getMockInstalledPacks();
    final activeDownloads = _getMockActiveDownloads();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeDownloads.isNotEmpty) ...[
          _buildActiveDownloadsSection(activeDownloads),
          const SizedBox(height: 16),
        ],
        _buildInstalledPacksSection(installedPacks),
      ],
    );
  }

  Widget _buildActiveDownloadsSection(List<DownloadProgress> downloads) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Downloads',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...downloads.map((download) => DownloadProgressCard(
          progress: download,
          onCancel: () => _cancelDownload(download.packId),
          onPause: () => _pauseDownload(download.packId),
        )),
      ],
    );
  }

  Widget _buildInstalledPacksSection(List<LanguagePackInstallation> packs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Installed Packs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _cleanupStorage,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Cleanup'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (packs.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.download_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No language packs installed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Download language packs to enable offline translation',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('Browse Available Packs'),
                ),
              ],
            ),
          )
        else
          ...packs.map((pack) => _buildInstalledPackCard(pack)),
      ],
    );
  }

  Widget _buildInstalledPackCard(LanguagePackInstallation pack) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.translate,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(pack.packId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${pack.version}'),
            Text(
              'Installed ${_formatDate(pack.installedAt)} • Last used ${_formatDate(pack.lastUsed)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _formatBytes(pack.totalSize),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handlePackAction(pack.packId, action),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'update',
              child: ListTile(
                leading: Icon(Icons.update),
                title: Text('Check for Update'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'validate',
              child: ListTile(
                leading: Icon(Icons.verified),
                title: Text('Validate'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Remove'),
                dense: true,
              ),
            ),
          ],
        ),
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

  // Mock data methods
  List<LanguagePackManifest> _getMockAvailablePacks() {
    return [
      LanguagePackManifest(
        id: 'en-es-v1.0',
        name: 'English-Spanish Dictionary',
        language: 'en',
        version: '1.0.0',
        description: 'Comprehensive English to Spanish dictionary with 50K+ entries',
        totalSize: 25 * 1024 * 1024, // 25MB
        files: [],
        supportedTargetLanguages: ['es'],
        releaseDate: DateTime.now().subtract(const Duration(days: 7)),
        author: 'PolyRead Team',
        license: 'CC BY-SA 4.0',
      ),
      LanguagePackManifest(
        id: 'en-fr-v1.2',
        name: 'English-French Complete',
        language: 'en',
        version: '1.2.0',
        description: 'English-French dictionary with pronunciation and examples',
        totalSize: 35 * 1024 * 1024, // 35MB
        files: [],
        supportedTargetLanguages: ['fr'],
        releaseDate: DateTime.now().subtract(const Duration(days: 3)),
        author: 'Community',
        license: 'MIT',
      ),
    ];
  }

  List<LanguagePackInstallation> _getMockInstalledPacks() {
    return [
      LanguagePackInstallation(
        packId: 'en-es-v1.0',
        version: '1.0.0',
        installedAt: DateTime.now().subtract(const Duration(days: 5)),
        lastUsed: DateTime.now().subtract(const Duration(hours: 2)),
        status: PackInstallationStatus.installed,
        installedFiles: ['dictionary.db', 'manifest.json'],
        totalSize: 25 * 1024 * 1024,
      ),
    ];
  }

  List<DownloadProgress> _getMockActiveDownloads() {
    return [
      DownloadProgress(
        packId: 'en-de-v1.0',
        packName: 'English-German Dictionary',
        status: DownloadStatus.downloading,
        downloadedBytes: 15 * 1024 * 1024,
        totalBytes: 30 * 1024 * 1024,
        progressPercent: 50.0,
        currentFile: 'dictionary.db',
        filesCompleted: 1,
        totalFiles: 3,
        startTime: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ];
  }

  bool _isPackInstalled(String packId) {
    return packId == 'en-es-v1.0';
  }

  bool _hasUpdateAvailable(String packId) {
    return packId == 'en-fr-v1.2';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // Action methods
  Future<void> _refreshAvailablePacks() async {
    // Refresh available packs from repository
    await Future.delayed(const Duration(seconds: 1));
  }

  void _installLanguagePack(String packId) {
    // Start pack installation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Installing $packId...')),
    );
  }

  void _updateLanguagePack(String packId) {
    // Update existing pack
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updating $packId...')),
    );
  }

  void _uninstallLanguagePack(String packId) {
    // Remove installed pack
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Language Pack'),
        content: Text('Are you sure you want to remove $packId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed $packId')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _cancelDownload(String packId) {
    // Cancel active download
  }

  void _pauseDownload(String packId) {
    // Pause active download
  }

  void _showPackDetails(LanguagePackManifest pack) {
    // Show detailed pack information
  }

  void _cleanupStorage() {
    // Clean up unused storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleaning up storage...')),
    );
  }

  void _validateAllPacks() {
    // Validate integrity of all packs
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Validating all packs...')),
    );
  }

  void _openStorageSettings() {
    // Open storage settings
  }

  void _handlePackAction(String packId, String action) {
    switch (action) {
      case 'update':
        _updateLanguagePack(packId);
        break;
      case 'validate':
        // Validate single pack
        break;
      case 'remove':
        _uninstallLanguagePack(packId);
        break;
    }
  }
}