// Storage Chart - Visual representation of storage usage with breakdown
// Shows storage quota, usage by language pack, and available space

import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/download_progress.dart';

class StorageChart extends StatefulWidget {
  final StorageQuota? quota;
  final bool showLegend;
  final bool animated;

  const StorageChart({
    super.key,
    this.quota,
    this.showLegend = true,
    this.animated = true,
  });

  @override
  State<StorageChart> createState() => _StorageChartState();
}

class _StorageChartState extends State<StorageChart>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  StorageQuota? _currentQuota;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _currentQuota = widget.quota ?? _getMockStorageQuota();
    
    if (widget.animated) {
      _animationController.forward();
    } else {
      _animation = AlwaysStoppedAnimation<double>(1.0);
    }
  }

  @override
  void didUpdateWidget(StorageChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.quota != oldWidget.quota) {
      setState(() {
        _currentQuota = widget.quota ?? _getMockStorageQuota();
      });
      
      if (widget.animated) {
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuota == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStorageChart(),
            if (widget.showLegend) ...[
              const SizedBox(height: 20),
              _buildLegend(),
            ],
            const SizedBox(height: 16),
            _buildStorageInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.storage,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Storage Usage',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getUsageColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${_currentQuota!.usagePercent.toStringAsFixed(1)}% used',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _getUsageColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageChart() {
    return SizedBox(
      height: 200,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            size: const Size.fromHeight(200),
            painter: StorageChartPainter(
              quota: _currentQuota!,
              animationValue: _animation.value,
              colorScheme: Theme.of(context).colorScheme,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    final packColors = _getPackColors();
    final sortedPacks = _currentQuota!.packUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Storage Breakdown',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
            ...sortedPacks.map((entry) {
              final packId = entry.key;
              final size = entry.value;
              final color = packColors[packId] ?? Colors.grey;
              
              return _buildLegendItem(
                packId,
                _formatBytes(size),
                color,
              );
            }),
            _buildLegendItem(
              'Available',
              _formatBytes(_currentQuota!.availableBytes),
              Colors.grey.shade300,
            ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, String size, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 4),
        Text(
          size,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoItem(
              'Total Limit',
              _formatBytes(_currentQuota!.totalLimitBytes),
              Icons.folder,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          Expanded(
            child: _buildInfoItem(
              'Used',
              _formatBytes(_currentQuota!.currentUsageBytes),
              Icons.folder_open,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          Expanded(
            child: _buildInfoItem(
              'Available',
              _formatBytes(_currentQuota!.availableBytes),
              Icons.folder_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Color _getUsageColor() {
    final usagePercent = _currentQuota!.usagePercent;
    if (usagePercent >= 90) return Colors.red;
    if (usagePercent >= 75) return Colors.orange;
    if (usagePercent >= 50) return Colors.amber;
    return Colors.green;
  }

  Map<String, Color> _getPackColors() {
    final packs = _currentQuota!.packUsage.keys.toList();
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    
    final packColors = <String, Color>{};
    for (int i = 0; i < packs.length; i++) {
      packColors[packs[i]] = colors[i % colors.length];
    }
    
    return packColors;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  StorageQuota _getMockStorageQuota() {
    return StorageQuota.create(
      totalLimitBytes: 500 * 1024 * 1024, // 500MB
      packUsage: {
        'en-es-v1.0': 25 * 1024 * 1024,
        'en-fr-v1.2': 35 * 1024 * 1024,
        'es-en-v1.0': 20 * 1024 * 1024,
        'fr-en-v1.1': 30 * 1024 * 1024,
      },
    );
  }
}

class StorageChartPainter extends CustomPainter {
  final StorageQuota quota;
  final double animationValue;
  final ColorScheme colorScheme;

  StorageChartPainter({
    required this.quota,
    required this.animationValue,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    
    // Draw background circle
    final backgroundPaint = Paint()
      ..color = colorScheme.surfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw usage arcs
    double startAngle = -math.pi / 2; // Start from top
    final totalUsage = quota.currentUsageBytes;
    
    if (totalUsage > 0) {
      final packColors = _getPackColors();
      final sortedPacks = quota.packUsage.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      for (final entry in sortedPacks) {
        final packSize = entry.value;
        final sweepAngle = (packSize / quota.totalLimitBytes) * 2 * math.pi * animationValue;
        
        final paint = Paint()
          ..color = packColors[entry.key] ?? Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round;
        
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
        
        startAngle += sweepAngle;
      }
    }
    
    // Draw center text
    final usagePercent = quota.usagePercent * animationValue;
    final textStyle = TextStyle(
      color: colorScheme.onSurface,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    );
    
    final textSpan = TextSpan(
      text: '${usagePercent.toStringAsFixed(1)}%',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
    
    // Draw "used" label
    final labelStyle = TextStyle(
      color: colorScheme.onSurface.withOpacity(0.6),
      fontSize: 12,
    );
    
    final labelSpan = TextSpan(
      text: 'used',
      style: labelStyle,
    );
    
    final labelPainter = TextPainter(
      text: labelSpan,
      textDirection: TextDirection.ltr,
    );
    
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      center + Offset(-labelPainter.width / 2, textPainter.height / 2 + 4),
    );
  }

  Map<String, Color> _getPackColors() {
    final packs = quota.packUsage.keys.toList();
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    
    final packColors = <String, Color>{};
    for (int i = 0; i < packs.length; i++) {
      packColors[packs[i]] = colors[i % colors.length];
    }
    
    return packColors;
  }

  @override
  bool shouldRepaint(covariant StorageChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.quota != quota;
  }
}