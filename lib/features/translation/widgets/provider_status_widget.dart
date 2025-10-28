// Provider Status Widget - Shows status of translation providers
// Displays availability, model download status, and performance metrics

import 'package:flutter/material.dart';
import '../services/translation_service.dart';

class ProviderStatusWidget extends StatelessWidget {
  final List<ProviderStatus> providers;
  final Function(String providerId)? onProviderTap;
  final bool showPerformanceMetrics;

  const ProviderStatusWidget({
    super.key,
    required this.providers,
    this.onProviderTap,
    this.showPerformanceMetrics = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.translate,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Translation Providers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...providers.map((provider) => _buildProviderTile(context, provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderTile(BuildContext context, ProviderStatus provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onProviderTap != null ? () => onProviderTap!(provider.providerId) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildProviderIcon(context, provider),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.providerName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        _buildStatusIndicator(context, provider),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          provider.isOfflineCapable ? Icons.offline_bolt : Icons.cloud,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.isOfflineCapable ? 'Offline' : 'Online',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        if (provider.additionalInfo != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${provider.additionalInfo}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (showPerformanceMetrics) ...[
                      const SizedBox(height: 8),
                      _buildPerformanceMetrics(context, provider),
                    ],
                  ],
                ),
              ),
              if (onProviderTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderIcon(BuildContext context, ProviderStatus provider) {
    IconData icon;
    Color color;

    switch (provider.providerId) {
      case 'dictionary':
        icon = Icons.menu_book;
        color = Colors.blue;
        break;
      case 'ml_kit':
        icon = Icons.offline_bolt;
        color = Colors.green;
        break;
      case 'google_translate_free':
        icon = Icons.cloud;
        color = Colors.orange;
        break;
      case 'bergamot_wasm':
        icon = Icons.web;
        color = Colors.purple;
        break;
      default:
        icon = Icons.translate;
        color = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, ProviderStatus provider) {
    Color color;
    String label;
    IconData icon;

    if (provider.isAvailable) {
      color = Colors.green;
      label = 'Ready';
      icon = Icons.check_circle;
    } else {
      color = Colors.red;
      label = 'Unavailable';
      icon = Icons.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(BuildContext context, ProviderStatus provider) {
    // Mock performance data - in real implementation would come from service
    final metrics = _getMockMetrics(provider.providerId);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  context,
                  'Avg Speed',
                  '${metrics.averageLatencyMs}ms',
                  Icons.speed,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  context,
                  'Success Rate',
                  '${(metrics.successRate * 100).toInt()}%',
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          if (provider.providerId == 'dictionary') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    context,
                    'Entries',
                    '${metrics.totalEntries}',
                    Icons.library_books,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    context,
                    'Cache Hits',
                    '${(metrics.cacheHitRate * 100).toInt()}%',
                    Icons.cached,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  ProviderMetrics _getMockMetrics(String providerId) {
    switch (providerId) {
      case 'dictionary':
        return const ProviderMetrics(
          averageLatencyMs: 5,
          successRate: 0.95,
          totalEntries: 50000,
          cacheHitRate: 0.85,
        );
      case 'ml_kit':
        return const ProviderMetrics(
          averageLatencyMs: 250,
          successRate: 0.92,
          totalEntries: 0,
          cacheHitRate: 0.75,
        );
      case 'google_translate_free':
        return const ProviderMetrics(
          averageLatencyMs: 800,
          successRate: 0.98,
          totalEntries: 0,
          cacheHitRate: 0.60,
        );
      default:
        return const ProviderMetrics(
          averageLatencyMs: 0,
          successRate: 0.0,
          totalEntries: 0,
          cacheHitRate: 0.0,
        );
    }
  }
}

class ProviderMetrics {
  final int averageLatencyMs;
  final double successRate;
  final int totalEntries;
  final double cacheHitRate;

  const ProviderMetrics({
    required this.averageLatencyMs,
    required this.successRate,
    required this.totalEntries,
    required this.cacheHitRate,
  });
}