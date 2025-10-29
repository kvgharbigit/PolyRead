// Auto Scroll Service
// Manages automatic scrolling functionality for readers

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:polyread/features/reader/engines/reader_interface.dart';

class AutoScrollService {
  Timer? _scrollTimer;
  ReaderEngine? _readerEngine;
  ScrollController? _scrollController;
  bool _isAutoScrolling = false;
  double _scrollSpeed = 1.0;
  
  // Auto-scroll configuration
  static const Duration _scrollInterval = Duration(milliseconds: 100);
  static const double _baseScrollAmount = 2.0; // pixels per interval
  
  /// Start auto-scrolling
  void startAutoScroll({
    required ReaderEngine readerEngine,
    ScrollController? scrollController,
    double speed = 1.0,
  }) {
    if (_isAutoScrolling) return;
    
    _readerEngine = readerEngine;
    _scrollController = scrollController;
    _scrollSpeed = speed;
    _isAutoScrolling = true;
    
    _scrollTimer = Timer.periodic(_scrollInterval, (_) {
      _performAutoScroll();
    });
  }
  
  /// Stop auto-scrolling
  void stopAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _isAutoScrolling = false;
  }
  
  /// Check if auto-scrolling is active
  bool get isAutoScrolling => _isAutoScrolling;
  
  /// Update scroll speed
  void updateSpeed(double speed) {
    _scrollSpeed = speed;
  }
  
  /// Perform one auto-scroll step
  void _performAutoScroll() {
    if (!_isAutoScrolling) return;
    
    final scrollAmount = _baseScrollAmount * _scrollSpeed;
    
    if (_scrollController != null && _scrollController!.hasClients) {
      // Scroll within current page/view
      final currentOffset = _scrollController!.offset;
      final maxScrollExtent = _scrollController!.position.maxScrollExtent;
      
      if (currentOffset < maxScrollExtent) {
        // Scroll down within current view
        _scrollController!.animateTo(
          (currentOffset + scrollAmount).clamp(0, maxScrollExtent),
          duration: _scrollInterval,
          curve: Curves.linear,
        );
      } else if (_readerEngine != null) {
        // Move to next page/section
        _goToNextPage();
      }
    } else if (_readerEngine != null) {
      // No scroll controller, use reader engine navigation
      _goToNextPage();
    }
  }
  
  /// Move to the next page when reaching the end
  Future<void> _goToNextPage() async {
    if (_readerEngine == null) return;
    
    final canGoNext = await _readerEngine!.goToNext();
    if (!canGoNext) {
      // Reached end of document, stop auto-scroll
      stopAutoScroll();
    }
  }
  
  /// Dispose resources
  void dispose() {
    stopAutoScroll();
    _readerEngine = null;
    _scrollController = null;
  }
}

/// Auto-scroll controls widget
class AutoScrollControls extends StatefulWidget {
  final AutoScrollService autoScrollService;
  final ReaderEngine readerEngine;
  final ScrollController? scrollController;
  final double initialSpeed;
  final Function(bool)? onAutoScrollToggle;
  
  const AutoScrollControls({
    super.key,
    required this.autoScrollService,
    required this.readerEngine,
    this.scrollController,
    this.initialSpeed = 1.0,
    this.onAutoScrollToggle,
  });
  
  @override
  State<AutoScrollControls> createState() => _AutoScrollControlsState();
}

class _AutoScrollControlsState extends State<AutoScrollControls> {
  bool _isAutoScrolling = false;
  double _scrollSpeed = 1.0;
  
  @override
  void initState() {
    super.initState();
    _scrollSpeed = widget.initialSpeed;
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Auto Scroll',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Switch(
                  value: _isAutoScrolling,
                  onChanged: _toggleAutoScroll,
                ),
              ],
            ),
            
            if (_isAutoScrolling) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Speed:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Expanded(
                    child: Slider(
                      value: _scrollSpeed,
                      min: 0.1,
                      max: 3.0,
                      divisions: 29,
                      label: '${_scrollSpeed.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        setState(() {
                          _scrollSpeed = value;
                        });
                        widget.autoScrollService.updateSpeed(value);
                      },
                    ),
                  ),
                  Text(
                    '${_scrollSpeed.toStringAsFixed(1)}x',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  void _toggleAutoScroll(bool enable) {
    setState(() {
      _isAutoScrolling = enable;
    });
    
    if (enable) {
      widget.autoScrollService.startAutoScroll(
        readerEngine: widget.readerEngine,
        scrollController: widget.scrollController,
        speed: _scrollSpeed,
      );
    } else {
      widget.autoScrollService.stopAutoScroll();
    }
    
    widget.onAutoScrollToggle?.call(enable);
  }
  
  @override
  void dispose() {
    if (_isAutoScrolling) {
      widget.autoScrollService.stopAutoScroll();
    }
    super.dispose();
  }
}