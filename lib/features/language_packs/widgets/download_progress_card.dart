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
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress.progressPercent / 100,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    _progressController.forward();
  }

  @override
  void didUpdateWidget(DownloadProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.progressPercent != widget.progress.progressPercent) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.progress.progressPercent / 100,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ));
      _progressController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
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
            _buildProgressBar(),
            const SizedBox(height: 8),
            _buildProgressDetails(),
            if (widget.progress.currentFile != null) ...[
              const SizedBox(height: 8),
              _buildCurrentFileInfo(),
            ],
            const SizedBox(height: 12),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildStatusIcon(),
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
                ),
              ),
            ],
          ),
        ),
        Text(
          '${widget.progress.progressPercent.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    Widget icon;
    Color color;

    switch (widget.progress.status) {
      case DownloadStatus.downloading:
        icon = const CircularProgressIndicator(strokeWidth: 2);
        color = Theme.of(context).colorScheme.primary;
        break;
      case DownloadStatus.paused:
        icon = const Icon(Icons.pause_circle_outline);
        color = Colors.orange;
        break;
      case DownloadStatus.completed:
        icon = const Icon(Icons.check_circle);
        color = Colors.green;
        break;
      case DownloadStatus.failed:
        icon = const Icon(Icons.error);
        color = Colors.red;
        break;
      case DownloadStatus.cancelled:
        icon = const Icon(Icons.cancel);
        color = Colors.grey;
        break;
      default:
        icon = const Icon(Icons.download);
        color = Theme.of(context).colorScheme.primary;
    }

    return SizedBox(
      width: 24,
      height: 24,
      child: widget.progress.status == DownloadStatus.downloading
          ? icon
          : Icon(
              (icon as Icon).icon,
              color: color,
              size: 24,
            ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: _progressAnimation.value,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.progress.isFailed
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  Widget _buildProgressDetails() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.progress.formattedProgress,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (widget.progress.downloadSpeed != null)
          Text(
            widget.progress.downloadSpeed!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (widget.progress.estimatedTimeRemaining != null)
          Text(
            widget.progress.estimatedTimeRemaining!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildCurrentFileInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            Icons.file_download,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.progress.currentFile!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${widget.progress.filesCompleted}/${widget.progress.totalFiles}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.progress.status == DownloadStatus.downloading) ...[
          TextButton.icon(
            onPressed: widget.onPause,
            icon: const Icon(Icons.pause, size: 16),
            label: const Text('Pause'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
          ),
        ] else if (widget.progress.status == DownloadStatus.paused) ...[
          TextButton.icon(
            onPressed: widget.onResume,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Resume'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
          ),
        ] else if (widget.progress.status == DownloadStatus.failed) ...[
          TextButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Remove'),
          ),
        ] else if (widget.progress.status == DownloadStatus.completed) ...[
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'Completed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  String _getStatusText() {
    switch (widget.progress.status) {
      case DownloadStatus.pending:
        return 'Preparing download...';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Download completed';
      case DownloadStatus.failed:
        return 'Download failed: ${widget.progress.error ?? 'Unknown error'}';
      case DownloadStatus.cancelled:
        return 'Download cancelled';
    }
  }

  Color _getStatusColor() {
    switch (widget.progress.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.pending:
        return Theme.of(context).colorScheme.primary;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
    }
  }
}