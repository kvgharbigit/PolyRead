// Translation Performance Harness
// Comprehensive testing interface for translation services

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polyread/features/translation/services/translation_service.dart';
import 'package:polyread/features/translation/services/translation_cache_service.dart';
import 'package:polyread/features/translation/models/translation_request.dart';

class TranslationPerformanceHarness extends ConsumerStatefulWidget {
  const TranslationPerformanceHarness({super.key});

  @override
  ConsumerState<TranslationPerformanceHarness> createState() => _TranslationPerformanceHarnessState();
}

class _TranslationPerformanceHarnessState extends ConsumerState<TranslationPerformanceHarness> {
  TranslationService? _translationService;
  final List<PerformanceTestResult> _testResults = [];
  bool _isRunning = false;
  int _currentTestIndex = 0;
  int _totalTests = 0;
  
  // Test configuration
  String _sourceLanguage = 'en';
  String _targetLanguage = 'es';
  int _iterations = 10;
  bool _includeCache = true;
  bool _includeDictionary = true;
  bool _includeMLKit = true;
  bool _includeGoogleTranslate = false;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeTranslationService();
  }

  Future<void> _initializeTranslationService() async {
    // TODO: Initialize translation service properly
    // For now, create a mock service for testing
    // _translationService = TranslationService(...);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Performance Harness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _clearResults,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConfiguration(),
          _buildProgressIndicator(),
          Expanded(child: _buildResults()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRunning ? null : _runPerformanceTests,
        icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
        label: Text(_isRunning ? 'Running...' : 'Run Tests'),
      ),
    );
  }

  Widget _buildConfiguration() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Language pair selection
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sourceLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Source Language',
                      border: OutlineInputBorder(),
                    ),
                    items: _getLanguageItems(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sourceLanguage = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _targetLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Target Language',
                      border: OutlineInputBorder(),
                    ),
                    items: _getLanguageItems(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _targetLanguage = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Iterations
            TextFormField(
              initialValue: _iterations.toString(),
              decoration: const InputDecoration(
                labelText: 'Iterations per test',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final iterations = int.tryParse(value) ?? 10;
                setState(() => _iterations = iterations.clamp(1, 100));
              },
            ),
            
            const SizedBox(height: 16),
            
            // Provider selection
            Text(
              'Translation Providers:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            CheckboxListTile(
              title: const Text('Dictionary Lookup'),
              value: _includeDictionary,
              onChanged: (value) {
                setState(() => _includeDictionary = value ?? false);
              },
            ),
            CheckboxListTile(
              title: const Text('ML Kit Translation'),
              value: _includeMLKit,
              onChanged: (value) {
                setState(() => _includeMLKit = value ?? false);
              },
            ),
            CheckboxListTile(
              title: const Text('Google Translate API'),
              value: _includeGoogleTranslate,
              onChanged: (value) {
                setState(() => _includeGoogleTranslate = value ?? false);
              },
            ),
            CheckboxListTile(
              title: const Text('Cache Performance'),
              value: _includeCache,
              onChanged: (value) {
                setState(() => _includeCache = value ?? false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (!_isRunning) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Running Performance Tests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _totalTests > 0 ? _currentTestIndex / _totalTests : 0,
            ),
            const SizedBox(height: 8),
            Text(
              'Test $_currentTestIndex of $_totalTests',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_testResults.isEmpty) {
      return const Center(
        child: Text(
          'No test results yet.\nConfigure your test parameters and run the performance tests.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance Results',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${_testResults.length} tests completed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                return _buildResultCard(result);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(PerformanceTestResult result) {
    final successRate = result.successfulTranslations / result.totalAttempts;
    final avgLatency = result.averageLatencyMs;
    
    Color performanceColor;
    if (avgLatency < 100) {
      performanceColor = Colors.green;
    } else if (avgLatency < 500) {
      performanceColor = Colors.orange;
    } else {
      performanceColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        title: Text('${result.testName} - ${result.provider}'),
        subtitle: Text(
          'Avg: ${avgLatency.toStringAsFixed(1)}ms | Success: ${(successRate * 100).toStringAsFixed(1)}%',
        ),
        leading: CircleAvatar(
          backgroundColor: performanceColor,
          child: Text(
            avgLatency < 1000 ? '${avgLatency.round()}' : '1s+',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricRow('Total Attempts', '${result.totalAttempts}'),
                _buildMetricRow('Successful', '${result.successfulTranslations}'),
                _buildMetricRow('Failed', '${result.failedTranslations}'),
                _buildMetricRow('Average Latency', '${avgLatency.toStringAsFixed(2)}ms'),
                _buildMetricRow('Min Latency', '${result.minLatencyMs.toStringAsFixed(2)}ms'),
                _buildMetricRow('Max Latency', '${result.maxLatencyMs.toStringAsFixed(2)}ms'),
                _buildMetricRow('Standard Deviation', '${result.latencyStdDev.toStringAsFixed(2)}ms'),
                _buildMetricRow('Success Rate', '${(successRate * 100).toStringAsFixed(2)}%'),
                
                if (result.sampleText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Sample Text:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(result.sampleText, style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
                
                if (result.sampleTranslation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text('Sample Translation:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(result.sampleTranslation, style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _getLanguageItems() {
    return [
      const DropdownMenuItem(value: 'en', child: Text('English')),
      const DropdownMenuItem(value: 'es', child: Text('Spanish')),
      const DropdownMenuItem(value: 'fr', child: Text('French')),
      const DropdownMenuItem(value: 'de', child: Text('German')),
      const DropdownMenuItem(value: 'it', child: Text('Italian')),
      const DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
      const DropdownMenuItem(value: 'ru', child: Text('Russian')),
    ];
  }

  Future<void> _runPerformanceTests() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
      _currentTestIndex = 0;
    });

    try {
      final testSuites = _generateTestSuites();
      _totalTests = testSuites.length;

      for (final testSuite in testSuites) {
        if (!_isRunning) break; // Allow cancellation
        
        setState(() => _currentTestIndex++);
        
        final result = await _runTestSuite(testSuite);
        _testResults.add(result);
        
        setState(() {});
        
        // Scroll to bottom to show latest results
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        
        // Small delay between tests to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      setState(() => _isRunning = false);
    }
  }

  List<PerformanceTestSuite> _generateTestSuites() {
    final suites = <PerformanceTestSuite>[];
    
    // Test data sets
    final testData = [
      TestDataSet(
        name: 'Single Words',
        texts: ['hello', 'world', 'book', 'translate', 'language', 'reading', 'study', 'learn'],
      ),
      TestDataSet(
        name: 'Short Phrases',
        texts: [
          'good morning',
          'how are you',
          'thank you',
          'excuse me',
          'nice to meet you',
          'see you later',
        ],
      ),
      TestDataSet(
        name: 'Sentences',
        texts: [
          'I am reading a book.',
          'The weather is beautiful today.',
          'Can you help me with this translation?',
          'Learning languages is fun and rewarding.',
          'Technology makes translation more accessible.',
        ],
      ),
      TestDataSet(
        name: 'Complex Sentences',
        texts: [
          'The quick brown fox jumps over the lazy dog.',
          'In the midst of winter, I found there was, within me, an invincible summer.',
          'The only way to do great work is to love what you do.',
          'Machine translation has revolutionized how we communicate across language barriers.',
        ],
      ),
    ];

    // Generate test suites for each enabled provider and data set
    for (final dataSet in testData) {
      if (_includeDictionary) {
        suites.add(PerformanceTestSuite(
          name: dataSet.name,
          provider: 'Dictionary',
          texts: dataSet.texts,
          iterations: _iterations,
          sourceLanguage: _sourceLanguage,
          targetLanguage: _targetLanguage,
        ));
      }
      
      if (_includeMLKit) {
        suites.add(PerformanceTestSuite(
          name: dataSet.name,
          provider: 'ML Kit',
          texts: dataSet.texts,
          iterations: _iterations,
          sourceLanguage: _sourceLanguage,
          targetLanguage: _targetLanguage,
        ));
      }
      
      if (_includeGoogleTranslate) {
        suites.add(PerformanceTestSuite(
          name: dataSet.name,
          provider: 'Google Translate',
          texts: dataSet.texts,
          iterations: _iterations,
          sourceLanguage: _sourceLanguage,
          targetLanguage: _targetLanguage,
        ));
      }
    }

    // Cache performance tests
    if (_includeCache) {
      suites.add(PerformanceTestSuite(
        name: 'Cache Performance',
        provider: 'Cache Hit',
        texts: ['cached', 'translation', 'performance'],
        iterations: _iterations * 2, // Test with warm cache
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      ));
    }

    return suites;
  }

  Future<PerformanceTestResult> _runTestSuite(PerformanceTestSuite testSuite) async {
    final latencies = <double>[];
    int successful = 0;
    int failed = 0;
    String sampleText = '';
    String sampleTranslation = '';

    for (int i = 0; i < testSuite.iterations; i++) {
      for (final text in testSuite.texts) {
        final stopwatch = Stopwatch()..start();
        
        try {
          // Mock translation for testing
          final translation = await _performMockTranslation(
            text,
            testSuite.provider,
            testSuite.sourceLanguage,
            testSuite.targetLanguage,
          );
          
          stopwatch.stop();
          final latency = stopwatch.elapsedMicroseconds / 1000.0; // Convert to milliseconds
          
          latencies.add(latency);
          successful++;
          
          // Store first sample for display
          if (sampleText.isEmpty) {
            sampleText = text;
            sampleTranslation = translation;
          }
          
        } catch (e) {
          stopwatch.stop();
          failed++;
          print('Translation failed for "$text": $e');
        }
      }
    }

    // Calculate statistics
    final avgLatency = latencies.isNotEmpty ? latencies.reduce((a, b) => a + b) / latencies.length : 0.0;
    final minLatency = latencies.isNotEmpty ? latencies.reduce(min) : 0.0;
    final maxLatency = latencies.isNotEmpty ? latencies.reduce(max) : 0.0;
    
    // Calculate standard deviation
    final variance = latencies.isNotEmpty 
        ? latencies.map((x) => pow(x - avgLatency, 2)).reduce((a, b) => a + b) / latencies.length
        : 0.0;
    final stdDev = sqrt(variance);

    return PerformanceTestResult(
      testName: testSuite.name,
      provider: testSuite.provider,
      totalAttempts: successful + failed,
      successfulTranslations: successful,
      failedTranslations: failed,
      averageLatencyMs: avgLatency,
      minLatencyMs: minLatency,
      maxLatencyMs: maxLatency,
      latencyStdDev: stdDev,
      sampleText: sampleText,
      sampleTranslation: sampleTranslation,
    );
  }

  Future<String> _performMockTranslation(
    String text,
    String provider,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    // Mock translation with realistic delays
    switch (provider) {
      case 'Dictionary':
        await Future.delayed(Duration(milliseconds: Random().nextInt(20) + 5)); // 5-25ms
        return 'Dict: $text';
        
      case 'ML Kit':
        await Future.delayed(Duration(milliseconds: Random().nextInt(500) + 100)); // 100-600ms
        return 'MLKit: $text';
        
      case 'Google Translate':
        await Future.delayed(Duration(milliseconds: Random().nextInt(2000) + 500)); // 500-2500ms
        return 'Google: $text';
        
      case 'Cache Hit':
        await Future.delayed(Duration(milliseconds: Random().nextInt(5) + 1)); // 1-6ms
        return 'Cached: $text';
        
      default:
        await Future.delayed(Duration(milliseconds: Random().nextInt(100) + 50));
        return 'Unknown: $text';
    }
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
      _currentTestIndex = 0;
      _totalTests = 0;
    });
  }
}

// Data classes
class PerformanceTestSuite {
  final String name;
  final String provider;
  final List<String> texts;
  final int iterations;
  final String sourceLanguage;
  final String targetLanguage;

  PerformanceTestSuite({
    required this.name,
    required this.provider,
    required this.texts,
    required this.iterations,
    required this.sourceLanguage,
    required this.targetLanguage,
  });
}

class PerformanceTestResult {
  final String testName;
  final String provider;
  final int totalAttempts;
  final int successfulTranslations;
  final int failedTranslations;
  final double averageLatencyMs;
  final double minLatencyMs;
  final double maxLatencyMs;
  final double latencyStdDev;
  final String sampleText;
  final String sampleTranslation;

  PerformanceTestResult({
    required this.testName,
    required this.provider,
    required this.totalAttempts,
    required this.successfulTranslations,
    required this.failedTranslations,
    required this.averageLatencyMs,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.latencyStdDev,
    required this.sampleText,
    required this.sampleTranslation,
  });
}

class TestDataSet {
  final String name;
  final List<String> texts;

  TestDataSet({
    required this.name,
    required this.texts,
  });
}