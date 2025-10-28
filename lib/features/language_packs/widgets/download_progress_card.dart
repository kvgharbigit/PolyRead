// Download Progress Card - Shows real-time download progress with controls
// Displays speed, ETA, file progress, and cancel/pause options

import 'package:flutter/material.dart';
import '../models/download_progress.dart';

class DownloadProgressCard extends StatefulWidget {
  final DownloadProgress progress;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;

  const DownloadProgressCard({
    super.key,
    required this.progress,
    this.onCancel,
    this.onPause,
    this.onResume,
    this.onRetry,
  });

  @override
  State<DownloadProgressCard> createState() => _DownloadProgressCardState();
}

class _DownloadProgressCardState extends State<DownloadProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress.progressPercent / 100,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void didUpdateWidget(DownloadProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.progress.progressPercent != widget.progress.progressPercent) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.progress.progressPercent / 100,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
      
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildProgressSection(),
            const SizedBox(height: 12),
            _buildDetailsSection(),
            if (_shouldShowActions()) ...[
              const SizedBox(height: 12),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.progress.packName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getStatusText(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (widget.progress.isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.progress.progressPercent.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getStatusColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _progressAnimation.value,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              minHeight: 6,
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.progress.formattedProgress,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (widget.progress.downloadSpeed != null)
              Text(
                widget.progress.downloadSpeed!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      children: [
        if (widget.progress.currentFile != null) ...[
          Row(
            children: [
              Icon(
                Icons.file_present,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Downloading: ${widget.progress.currentFile}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Icon(
              Icons.inventory,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              'Files: ${widget.progress.filesCompleted}/${widget.progress.totalFiles}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.progress.estimatedTimeRemaining != null) ...[
              const SizedBox(width: 16),
              Icon(
                Icons.schedule,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                'ETA: ${widget.progress.estimatedTimeRemaining}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        if (widget.progress.error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.progress.error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.progress.isFailed && widget.onRetry != null)
          TextButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        
        if (widget.progress.status == DownloadStatus.paused && widget.onResume != null)
          TextButton.icon(
            onPressed: widget.onResume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
          ),
        
        if (widget.progress.status == DownloadStatus.downloading && widget.onPause != null)
          TextButton.icon(
            onPressed: widget.onPause,
            icon: const Icon(Icons.pause),
            label: const Text('Pause'),
          ),
        
        if (widget.progress.isActive && widget.onCancel != null) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _showCancelDialog(),
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ],
      ],
    );
  }

  bool _shouldShowActions() {
    return widget.progress.isActive || 
           widget.progress.isFailed || 
           widget.progress.status == DownloadStatus.paused;
  }

  Color _getStatusColor() {
    switch (widget.progress.status) {
      case DownloadStatus.pending:
        return Colors.orange;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
      case DownloadStatus.paused:
        return Colors.amber;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.progress.status) {
      case DownloadStatus.pending:
        return Icons.schedule;
      case DownloadStatus.downloading:
        return Icons.download;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
      case DownloadStatus.paused:
        return Icons.pause_circle;
    }
  }

  String _getStatusText() {
    switch (widget.progress.status) {
      case DownloadStatus.pending:
        return 'Waiting to start...';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.completed:
        return 'Download complete';
      case DownloadStatus.failed:
        return 'Download failed';
      case DownloadStatus.cancelled:
        return 'Download cancelled';
      case DownloadStatus.paused:
        return 'Download paused';
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download'),
        content: Text(
          'Are you sure you want to cancel downloading "${widget.progress.packName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Downloading'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancel?.call();
            },
            child: const Text('Cancel Download'),
          ),
        ],
      ),
    );
  }
}