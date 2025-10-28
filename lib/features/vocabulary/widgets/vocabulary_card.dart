// Vocabulary Card - Interactive SRS review card with flip animation
// Shows word/translation with context and allows rating

import 'package:flutter/material.dart';
import '../models/vocabulary_item.dart';

class VocabularyCard extends StatefulWidget {
  final VocabularyItem item;
  final bool showTranslation;
  final Function(ReviewResult)? onReview;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final bool showControls;
  final bool autoFlip;

  const VocabularyCard({
    super.key,
    required this.item,
    this.showTranslation = false,
    this.onReview,
    this.onNext,
    this.onPrevious,
    this.showControls = true,
    this.autoFlip = false,
  });

  @override
  State<VocabularyCard> createState() => _VocabularyCardState();
}

class _VocabularyCardState extends State<VocabularyCard>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _shakeController;
  late Animation<double> _flipAnimation;
  late Animation<double> _shakeAnimation;
  
  bool _isFlipped = false;
  DateTime? _reviewStartTime;
  
  @override
  void initState() {
    super.initState();
    
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));
    
    _isFlipped = widget.showTranslation;
    if (_isFlipped) {
      _flipController.value = 1.0;
    }
    
    _reviewStartTime = DateTime.now();
    
    if (widget.autoFlip) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_isFlipped) {
          _flip();
        }
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _shake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  void _handleReview(bool correct, {int? quality}) {
    final responseTime = _reviewStartTime != null 
        ? DateTime.now().difference(_reviewStartTime!)
        : null;
    
    final result = ReviewResult(
      correct: correct,
      quality: quality,
      responseTime: responseTime,
      timestamp: DateTime.now(),
    );
    
    widget.onReview?.call(result);
    
    if (!correct) {
      _shake();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final shakeOffset = _shakeAnimation.value * 10 * 
              (1 - _shakeAnimation.value);
          
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: GestureDetector(
              onTap: _flip,
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  final isShowingFront = _flipAnimation.value < 0.5;
                  
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(_flipAnimation.value * 3.14159),
                    child: isShowingFront
                        ? _buildFrontCard()
                        : Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(3.14159),
                            child: _buildBackCard(),
                          ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrontCard() {
    return _buildCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDifficultyIndicator(),
          const SizedBox(height: 20),
          _buildWordSection(),
          if (widget.item.context != null) ...[
            const SizedBox(height: 20),
            _buildContextSection(),
          ],
          const SizedBox(height: 20),
          _buildFlipHint(),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    return _buildCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTranslationSection(),
          if (widget.item.definition != null) ...[
            const SizedBox(height: 16),
            _buildDefinitionSection(),
          ],
          if (widget.item.bookTitle != null) ...[
            const SizedBox(height: 16),
            _buildSourceSection(),
          ],
          const SizedBox(height: 24),
          if (widget.showControls) _buildReviewButtons(),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: 350,
      height: 500,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }

  Widget _buildDifficultyIndicator() {
    final difficulty = widget.item.difficultyLevel;
    Color color;
    String label;
    IconData icon;

    switch (difficulty) {
      case DifficultyLevel.learning:
        color = Colors.blue;
        label = 'Learning';
        icon = Icons.school;
        break;
      case DifficultyLevel.easy:
        color = Colors.green;
        label = 'Easy';
        icon = Icons.check_circle;
        break;
      case DifficultyLevel.medium:
        color = Colors.orange;
        label = 'Medium';
        icon = Icons.remove_circle;
        break;
      case DifficultyLevel.hard:
        color = Colors.red;
        label = 'Hard';
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
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

  Widget _buildWordSection() {
    return Column(
      children: [
        Text(
          widget.item.word,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${widget.item.sourceLanguage.toUpperCase()} → ${widget.item.targetLanguage.toUpperCase()}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContextSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                'Context',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.item.context!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFlipHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.touch_app,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
        const SizedBox(width: 4),
        Text(
          'Tap to reveal',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationSection() {
    return Column(
      children: [
        Text(
          widget.item.translation,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Translation',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDefinitionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                'Definition',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.item.definition!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.book,
            size: 16,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'From: ${widget.item.bookTitle}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewButtons() {
    return Column(
      children: [
        Text(
          'How well did you know this?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildReviewButton(
                'Again',
                Colors.red,
                Icons.close,
                () => _handleReview(false, quality: 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildReviewButton(
                'Hard',
                Colors.orange,
                Icons.remove,
                () => _handleReview(true, quality: 2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildReviewButton(
                'Good',
                Colors.blue,
                Icons.check,
                () => _handleReview(true, quality: 3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildReviewButton(
                'Easy',
                Colors.green,
                Icons.done_all,
                () => _handleReview(true, quality: 4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}