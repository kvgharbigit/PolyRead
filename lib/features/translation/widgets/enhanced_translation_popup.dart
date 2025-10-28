// Enhanced Translation Popup with Two-Level Synonym Cycling
// Provides comprehensive word exploration with multiple levels of synonyms

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:polyread/features/translation/models/translation_models.dart';
import 'package:polyread/features/translation/services/translation_service.dart';

class EnhancedTranslationPopup extends StatefulWidget {
  final String selectedText;
  final String sourceLanguage;
  final String targetLanguage;
  final Offset position;
  final VoidCallback onClose;
  final Function(String) onAddToVocabulary;
  final TranslationService? translationService;
  final String? context;
  final TextSelection? textSelection;
  final bool enableSynonymCycling;
  final bool enableMorphemeAnalysis;

  const EnhancedTranslationPopup({
    super.key,
    required this.selectedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.position,
    required this.onClose,
    required this.onAddToVocabulary,
    this.translationService,
    this.context,
    this.textSelection,
    this.enableSynonymCycling = true,
    this.enableMorphemeAnalysis = true,
  });

  @override
  State<EnhancedTranslationPopup> createState() => _EnhancedTranslationPopupState();
}

class _EnhancedTranslationPopupState extends State<EnhancedTranslationPopup>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Translation data
  TranslationResponse? _translationResponse;
  List<SynonymGroup> _synonymGroups = [];
  int _currentSynonymLevel = 0;
  int _currentSynonymIndex = 0;
  bool _isLoading = true;
  String? _error;
  
  // UI state
  bool _showFullDefinition = false;
  bool _showMorphemeAnalysis = false;
  PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTranslation();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _loadTranslation() async {
    if (widget.translationService == null) {
      setState(() {
        _isLoading = false;
        _error = 'Translation service not available';
      });
      return;
    }

    try {
      final request = TranslationRequest(
        text: widget.selectedText,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        context: widget.context,
      );

      final response = await widget.translationService!.translate(request);
      
      // Generate synonym groups for enhanced exploration
      final synonymGroups = await _generateSynonymGroups(response);
      
      setState(() {
        _translationResponse = response;
        _synonymGroups = synonymGroups;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<SynonymGroup>> _generateSynonymGroups(TranslationResponse response) async {
    final groups = <SynonymGroup>[];
    
    // Primary level - direct translations and synonyms
    if (response.dictionaryResult?.entries.isNotEmpty == true) {
      final primarySynonyms = <String>[];
      for (final entry in response.dictionaryResult!.entries) {
        primarySynonyms.addAll(entry.translations);
        if (entry.synonyms.isNotEmpty) {
          primarySynonyms.addAll(entry.synonyms);
        }
      }
      
      groups.add(SynonymGroup(
        level: 1,
        title: 'Direct Translations',
        synonyms: primarySynonyms.take(8).toList(),
        confidence: 0.9,
      ));
    }
    
    // Secondary level - related words and concepts
    final secondarySynonyms = await _generateRelatedWords(widget.selectedText);
    if (secondarySynonyms.isNotEmpty) {
      groups.add(SynonymGroup(
        level: 2,
        title: 'Related Concepts',
        synonyms: secondarySynonyms,
        confidence: 0.7,
      ));
    }
    
    // Morpheme analysis level
    if (widget.enableMorphemeAnalysis) {
      final morphemeData = await _analyzeMorphemes(widget.selectedText);
      if (morphemeData.isNotEmpty) {
        groups.add(SynonymGroup(
          level: 3,
          title: 'Word Components',
          synonyms: morphemeData,
          confidence: 0.8,
        ));
      }
    }
    
    return groups;
  }

  Future<List<String>> _generateRelatedWords(String word) async {
    // Mock implementation - in production, use a proper thesaurus API
    final relatedWords = <String>[];
    
    // Simple word association based on common patterns
    final wordLower = word.toLowerCase();
    
    if (wordLower.contains('happy')) {
      relatedWords.addAll(['joyful', 'cheerful', 'glad', 'content', 'pleased']);
    } else if (wordLower.contains('big')) {
      relatedWords.addAll(['large', 'huge', 'enormous', 'massive', 'giant']);
    } else if (wordLower.contains('good')) {
      relatedWords.addAll(['excellent', 'great', 'wonderful', 'fantastic', 'superb']);
    } else {
      // Generate contextual synonyms based on word length and structure
      relatedWords.addAll(['similar', 'related', 'connected', 'associated']);
    }
    
    return relatedWords.take(6).toList();
  }

  Future<List<String>> _analyzeMorphemes(String word) async {
    final morphemes = <String>[];
    
    // Simple morpheme analysis (in production, use a proper morphological analyzer)
    final wordLower = word.toLowerCase();
    
    // Common prefixes
    final prefixes = ['un', 're', 'pre', 'dis', 'mis', 'over', 'under'];
    for (final prefix in prefixes) {
      if (wordLower.startsWith(prefix) && wordLower.length > prefix.length + 2) {
        morphemes.add('$prefix- (prefix)');
        break;
      }
    }
    
    // Root word
    String root = wordLower;
    for (final prefix in prefixes) {
      if (root.startsWith(prefix)) {
        root = root.substring(prefix.length);
        break;
      }
    }
    
    // Common suffixes
    final suffixes = ['ing', 'ed', 'er', 'est', 'ly', 'tion', 'sion', 'ness'];
    for (final suffix in suffixes) {
      if (root.endsWith(suffix) && root.length > suffix.length + 2) {
        morphemes.add('-$suffix (suffix)');
        root = root.substring(0, root.length - suffix.length);
        break;
      }
    }
    
    if (root.isNotEmpty) {
      morphemes.insert(morphemes.isEmpty ? 0 : morphemes.length - 1, '$root (root)');
    }
    
    return morphemes;
  }

  void _cycleSynonym(bool forward) {
    if (_synonymGroups.isEmpty) return;
    
    final currentGroup = _synonymGroups[_currentSynonymLevel];
    
    if (forward) {
      if (_currentSynonymIndex < currentGroup.synonyms.length - 1) {
        _currentSynonymIndex++;
      } else {
        // Move to next level
        if (_currentSynonymLevel < _synonymGroups.length - 1) {
          _currentSynonymLevel++;
          _currentSynonymIndex = 0;
        } else {
          // Wrap to beginning
          _currentSynonymLevel = 0;
          _currentSynonymIndex = 0;
        }
      }
    } else {
      if (_currentSynonymIndex > 0) {
        _currentSynonymIndex--;
      } else {
        // Move to previous level
        if (_currentSynonymLevel > 0) {
          _currentSynonymLevel--;
          _currentSynonymIndex = _synonymGroups[_currentSynonymLevel].synonyms.length - 1;
        } else {
          // Wrap to end
          _currentSynonymLevel = _synonymGroups.length - 1;
          _currentSynonymIndex = _synonymGroups[_currentSynonymLevel].synonyms.length - 1;
        }
      }
    }
    
    setState(() {});
    HapticFeedback.lightImpact();
  }

  String get _currentSynonym {
    if (_synonymGroups.isEmpty || 
        _currentSynonymLevel >= _synonymGroups.length ||
        _currentSynonymIndex >= _synonymGroups[_currentSynonymLevel].synonyms.length) {
      return widget.selectedText;
    }
    
    return _synonymGroups[_currentSynonymLevel].synonyms[_currentSynonymIndex];
  }

  SynonymGroup? get _currentGroup {
    if (_synonymGroups.isEmpty || _currentSynonymLevel >= _synonymGroups.length) {
      return null;
    }
    return _synonymGroups[_currentSynonymLevel];
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 150,
      top: widget.position.dy - 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  if (_isLoading) _buildLoadingIndicator(),
                  if (_error != null) _buildErrorContent(),
                  if (!_isLoading && _error == null) ...[
                    _buildMainContent(),
                    _buildActionButtons(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.selectedText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading translation...'),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            'Translation failed',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Expanded(
      child: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildTranslationPage(),
          if (widget.enableSynonymCycling) _buildSynonymPage(),
          if (widget.enableMorphemeAnalysis) _buildMorphemePage(),
        ],
      ),
    );
  }

  Widget _buildTranslationPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary translation with cycling
          if (widget.enableSynonymCycling && _synonymGroups.isNotEmpty) ...[
            _buildSynonymCycler(),
            const SizedBox(height: 16),
          ],
          
          // Dictionary entries
          if (_translationResponse?.dictionaryResult?.entries.isNotEmpty == true)
            _buildDictionaryEntries(),
          
          // ML Kit translation
          if (_translationResponse?.mlKitResult != null)
            _buildMLKitTranslation(),
          
          // Context
          if (widget.context != null) _buildContextDisplay(),
        ],
      ),
    );
  }

  Widget _buildSynonymCycler() {
    if (_synonymGroups.isEmpty) return const SizedBox.shrink();
    
    final currentGroup = _currentGroup;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Level indicator
          Text(
            currentGroup?.title ?? 'Translations',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Synonym with navigation
          Row(
            children: [
              IconButton(
                onPressed: () => _cycleSynonym(false),
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
              ),
              
              Expanded(
                child: Text(
                  _currentSynonym,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              IconButton(
                onPressed: () => _cycleSynonym(true),
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
              ),
            ],
          ),
          
          // Progress indicator
          if (currentGroup != null)
            LinearProgressIndicator(
              value: (_currentSynonymIndex + 1) / currentGroup.synonyms.length,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDictionaryEntries() {
    final entries = _translationResponse!.dictionaryResult!.entries;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dictionary',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...entries.take(3).map((entry) => _buildDictionaryEntry(entry)),
      ],
    );
  }

  Widget _buildDictionaryEntry(DictionaryEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.partOfSpeech.isNotEmpty)
            Text(
              entry.partOfSpeech,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          
          Text(
            entry.translations.join(', '),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          
          if (entry.examples.isNotEmpty)
            Text(
              'e.g., ${entry.examples.first}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMLKitTranslation() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 4),
              Text(
                'ML Translation',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _translationResponse!.mlKitResult!.translatedText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSynonymPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Synonym Levels',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.builder(
              itemCount: _synonymGroups.length,
              itemBuilder: (context, index) {
                final group = _synonymGroups[index];
                return _buildSynonymGroupCard(group, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynonymGroupCard(SynonymGroup group, int index) {
    final isSelected = index == _currentSynonymLevel;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected 
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Level ${group.level}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${(group.confidence * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          
          Text(
            group.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: group.synonyms.map((synonym) {
              final isCurrent = isSelected && 
                  group.synonyms.indexOf(synonym) == _currentSynonymIndex;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  synonym,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrent ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMorphemePage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Word Analysis',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Morpheme breakdown would go here
          Text(
            'Morphological analysis helps understand word structure and meaning.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildContextDisplay() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.context_menu, color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 4),
              Text(
                'Context',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.context!,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // Page indicators
          if (_pageController.hasClients)
            Row(
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == _currentPage 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          
          const Spacer(),
          
          // Add to vocabulary button
          ElevatedButton.icon(
            onPressed: () => widget.onAddToVocabulary(_currentSynonym),
            icon: const Icon(Icons.bookmark_add, size: 16),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

// Data classes for synonym cycling
class SynonymGroup {
  final int level;
  final String title;
  final List<String> synonyms;
  final double confidence;

  SynonymGroup({
    required this.level,
    required this.title,
    required this.synonyms,
    required this.confidence,
  });
}