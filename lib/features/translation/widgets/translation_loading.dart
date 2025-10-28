// Translation Loading Widget - Shows loading states for different providers
// Displays current provider being tried and estimated time

import 'package:flutter/material.dart';

class TranslationLoading extends StatefulWidget {
  final String selectedText;
  final String sourceLanguage;
  final String targetLanguage;
  final TranslationLoadingState state;
  final VoidCallback? onCancel;

  const TranslationLoading({
    super.key,
    required this.selectedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.state,
    this.onCancel,
  });

  @override
  State<TranslationLoading> createState() => _TranslationLoadingState();
}

class _TranslationLoadingState extends State<TranslationLoading>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    
    _updateProgress();
  }

  @override
  void didUpdateWidget(TranslationLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateProgress();
    }
  }

  void _updateProgress() {
    final progress = _getProgressForState(widget.state);
    _progressController.animateTo(progress);
  }

  double _getProgressForState(TranslationLoadingState state) {
    switch (state) {
      case TranslationLoadingState.searchingDictionary:
        return 0.2;
      case TranslationLoadingState.downloadingModels:
        return 0.4;
      case TranslationLoadingState.translatingOffline:
        return 0.7;
      case TranslationLoadingState.translatingOnline:
        return 0.9;
      case TranslationLoadingState.completed:
        return 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildLoadingIndicator(),
          const SizedBox(height: 16),
          _buildProgressBar(),
          const SizedBox(height: 16),
          _buildStatusText(),
          if (widget.onCancel != null) ...[
            const SizedBox(height: 20),
            _buildCancelButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.selectedText,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.sourceLanguage.toUpperCase()} → ${widget.targetLanguage.toUpperCase()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(
              _getIconForState(widget.state),
              size: 30,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForState(TranslationLoadingState state) {
    switch (state) {
      case TranslationLoadingState.searchingDictionary:
        return Icons.menu_book;
      case TranslationLoadingState.downloadingModels:
        return Icons.download;
      case TranslationLoadingState.translatingOffline:
        return Icons.offline_bolt;
      case TranslationLoadingState.translatingOnline:
        return Icons.cloud;
      case TranslationLoadingState.completed:
        return Icons.check;
    }
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _progressAnimation.value,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProgressStep(
              'Dictionary',
              Icons.menu_book,
              TranslationLoadingState.searchingDictionary,
            ),
            _buildProgressStep(
              'Models',
              Icons.download,
              TranslationLoadingState.downloadingModels,
            ),
            _buildProgressStep(
              'Offline',
              Icons.offline_bolt,
              TranslationLoadingState.translatingOffline,
            ),
            _buildProgressStep(
              'Online',
              Icons.cloud,
              TranslationLoadingState.translatingOnline,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressStep(
    String label,
    IconData icon,
    TranslationLoadingState stepState,
  ) {
    final isActive = _getStateOrder(widget.state) >= _getStateOrder(stepState);
    final isCurrent = widget.state == stepState;
    
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceVariant,
            border: isCurrent
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Icon(
            icon,
            size: 12,
            color: isActive
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  int _getStateOrder(TranslationLoadingState state) {
    switch (state) {
      case TranslationLoadingState.searchingDictionary:
        return 0;
      case TranslationLoadingState.downloadingModels:
        return 1;
      case TranslationLoadingState.translatingOffline:
        return 2;
      case TranslationLoadingState.translatingOnline:
        return 3;
      case TranslationLoadingState.completed:
        return 4;
    }
  }

  Widget _buildStatusText() {
    String statusText;
    String? detailText;

    switch (widget.state) {
      case TranslationLoadingState.searchingDictionary:
        statusText = 'Searching dictionary...';
        detailText = 'Looking for exact matches';
        break;
      case TranslationLoadingState.downloadingModels:
        statusText = 'Downloading translation models...';
        detailText = 'This may take a moment on first use';
        break;
      case TranslationLoadingState.translatingOffline:
        statusText = 'Translating offline...';
        detailText = 'Using local ML Kit models';
        break;
      case TranslationLoadingState.translatingOnline:
        statusText = 'Translating online...';
        detailText = 'Using Google Translate';
        break;
      case TranslationLoadingState.completed:
        statusText = 'Translation complete';
        detailText = null;
        break;
    }

    return Column(
      children: [
        Text(
          statusText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        if (detailText != null) ...[
          const SizedBox(height: 4),
          Text(
            detailText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: widget.onCancel,
        child: const Text('Cancel'),
      ),
    );
  }
}

enum TranslationLoadingState {
  searchingDictionary,
  downloadingModels,
  translatingOffline,
  translatingOnline,
  completed,
}