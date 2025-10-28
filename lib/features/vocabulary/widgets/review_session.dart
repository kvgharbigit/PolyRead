// Review Session - SRS vocabulary review interface
// Manages review flow, progress tracking, and session statistics

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vocabulary_item.dart';
import '../services/vocabulary_service.dart';
import 'vocabulary_card.dart';

class ReviewSession extends StatefulWidget {
  final List<VocabularyItem> items;
  final VocabularyService vocabularyService;
  final VoidCallback? onSessionComplete;
  final Function(ReviewSessionStats)? onStatsUpdate;

  const ReviewSession({
    super.key,
    required this.items,
    required this.vocabularyService,
    this.onSessionComplete,
    this.onStatsUpdate,
  });

  @override
  State<ReviewSession> createState() => _ReviewSessionState();
}

class _ReviewSessionState extends State<ReviewSession>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _cardController;
  late Animation<double> _progressAnimation;
  late Animation<Offset> _cardSlideAnimation;
  
  int _currentIndex = 0;
  int _correctCount = 0;
  int _totalReviews = 0;
  DateTime? _sessionStartTime;
  bool _sessionCompleted = false;
  bool _isPaused = false;
  
  final List<ReviewResult> _sessionResults = [];

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
    
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    ));
    
    _sessionStartTime = DateTime.now();
    _updateProgress();
    _cardController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    final progress = widget.items.isEmpty ? 0.0 : _currentIndex / widget.items.length;
    _progressController.animateTo(progress);
  }

  Future<void> _handleReview(ReviewResult result) async {
    if (_sessionCompleted) return;

    HapticFeedback.lightImpact();
    
    setState(() {
      _sessionResults.add(result);
      _totalReviews++;
      if (result.correct) _correctCount++;
    });

    // Record review in database
    try {
      await widget.vocabularyService.recordReview(
        vocabularyId: widget.items[_currentIndex].id!,
        result: result,
      );
    } catch (e) {
      // Handle error but don't stop session
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save review: $e')),
      );
    }

    // Update session stats
    final stats = _calculateSessionStats();
    widget.onStatsUpdate?.call(stats);

    // Move to next card
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex >= widget.items.length - 1) {
      _completeSession();
      return;
    }

    _cardController.reset();
    setState(() {
      _currentIndex++;
    });
    _updateProgress();
    _cardController.forward();
  }

  void _completeSession() {
    setState(() {
      _sessionCompleted = true;
    });
    
    HapticFeedback.mediumImpact();
    widget.onSessionComplete?.call();
  }

  void _pauseSession() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _exitSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Review Session'),
        content: const Text(
          'Are you sure you want to exit? Your progress will be saved but the session will end.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Reviewing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit Session'),
          ),
        ],
      ),
    );
  }

  ReviewSessionStats _calculateSessionStats() {
    final sessionDuration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;
    
    return ReviewSessionStats(
      totalItems: widget.items.length,
      reviewedItems: _totalReviews,
      correctAnswers: _correctCount,
      sessionDuration: sessionDuration,
      averageResponseTime: _calculateAverageResponseTime(),
    );
  }

  Duration _calculateAverageResponseTime() {
    final validResults = _sessionResults
        .where((r) => r.responseTime != null)
        .map((r) => r.responseTime!)
        .toList();
    
    if (validResults.isEmpty) return Duration.zero;
    
    final totalMs = validResults.fold(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: (totalMs / validResults.length).round());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _buildEmptyState();
    }

    if (_sessionCompleted) {
      return _buildCompletionState();
    }

    if (_isPaused) {
      return _buildPausedState();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProgressSection(),
          Expanded(
            child: _buildCardSection(),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('Review Session'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: _exitSession,
        icon: const Icon(Icons.close),
      ),
      actions: [
        IconButton(
          onPressed: _pauseSession,
          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} of ${widget.items.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_correctCount}/${_totalReviews} correct',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    return SlideTransition(
      position: _cardSlideAnimation,
      child: VocabularyCard(
        item: widget.items[_currentIndex],
        onReview: _handleReview,
        showControls: true,
        autoFlip: false,
      ),
    );
  }

  Widget _buildBottomControls() {
    final stats = _calculateSessionStats();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Accuracy',
              '${stats.accuracyPercentage.toStringAsFixed(1)}%',
              Icons.target,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Avg Time',
              _formatDuration(stats.averageResponseTime),
              Icons.timer,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Remaining',
              '${widget.items.length - _currentIndex - 1}',
              Icons.pending_actions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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

  Widget _buildEmptyState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Session')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No items to review',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'All caught up! Come back later for more reviews.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPausedState() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pause_circle_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Session Paused',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a break! Tap resume when ready.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pauseSession,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
                OutlinedButton.icon(
                  onPressed: _exitSession,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Exit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionState() {
    final stats = _calculateSessionStats();
    
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.celebration,
                  size: 60,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Session Complete!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Great job on completing your review session',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildStatsCard(stats),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(ReviewSessionStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Session Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Accuracy',
                    '${stats.accuracyPercentage.toStringAsFixed(1)}%',
                    Icons.target,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Time',
                    _formatDuration(stats.sessionDuration),
                    Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Reviewed',
                    '${stats.reviewedItems}',
                    Icons.quiz,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Response',
                    _formatDuration(stats.averageResponseTime),
                    Icons.timer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }
}

class ReviewSessionStats {
  final int totalItems;
  final int reviewedItems;
  final int correctAnswers;
  final Duration sessionDuration;
  final Duration averageResponseTime;

  const ReviewSessionStats({
    required this.totalItems,
    required this.reviewedItems,
    required this.correctAnswers,
    required this.sessionDuration,
    required this.averageResponseTime,
  });

  double get accuracyPercentage {
    return reviewedItems > 0 ? (correctAnswers / reviewedItems) * 100 : 0.0;
  }

  double get completionPercentage {
    return totalItems > 0 ? (reviewedItems / totalItems) * 100 : 0.0;
  }
}