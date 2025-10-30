// Bidirectional Translation Card Widget
// Displays translation results with meaning contexts and synonyms

import 'package:flutter/material.dart';
import '../models/bidirectional_dictionary_entry.dart';

class BidirectionalTranslationCard extends StatelessWidget {
  final BidirectionalLookupResult lookupResult;
  final VoidCallback? onClose;

  const BidirectionalTranslationCard({
    super.key,
    required this.lookupResult,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!lookupResult.hasResults) {
      return _buildNoResultsCard(context);
    }

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          _buildTranslationContent(context),
        ],
      ),
    );
  }

  Widget _buildHeader(context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.translate,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lookupResult.query,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              iconSize: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildTranslationContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary translation (most relevant)
          if (lookupResult.primaryEntry != null)
            _buildDictionaryEntry(context, lookupResult.primaryEntry!, isPrimary: true),
          
          // Secondary translation (other direction) if available
          if (lookupResult.forwardEntry != null && lookupResult.reverseEntry != null)
            ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 8),
              _buildDictionaryEntry(
                context, 
                lookupResult.forwardEntry == lookupResult.primaryEntry 
                    ? lookupResult.reverseEntry! 
                    : lookupResult.forwardEntry!,
                isPrimary: false,
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildDictionaryEntry(BuildContext context, BidirectionalDictionaryEntry entry, {required bool isPrimary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Direction indicator
        if (!isPrimary)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.sourceLanguage.toUpperCase()} → ${entry.targetLanguage.toUpperCase()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Meanings with contexts and synonyms
        ...entry.meanings.map((meaning) => _buildMeaningGroup(context, meaning, isPrimary)),
      ],
    );
  }

  Widget _buildMeaningGroup(BuildContext context, MeaningGroup meaning, bool isPrimary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Context tag
          if (meaning.context != 'general') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPrimary 
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPrimary 
                      ? Theme.of(context).primaryColor.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                meaning.context,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPrimary 
                      ? Theme.of(context).primaryColor
                      : Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Synonyms
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: meaning.synonyms.asMap().entries.map((entry) {
                final index = entry.key;
                final synonym = entry.value;
                final isLast = index == meaning.synonyms.length - 1;
                
                return Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: synonym,
                        style: TextStyle(
                          fontSize: isPrimary ? 16 : 14,
                          fontWeight: isPrimary ? FontWeight.w500 : FontWeight.normal,
                          color: isPrimary 
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      if (!isLast)
                        TextSpan(
                          text: ', ',
                          style: TextStyle(
                            fontSize: isPrimary ? 16 : 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No translation found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching for "${lookupResult.query}" in a different language',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple list item for search results
class BidirectionalDictionaryListItem extends StatelessWidget {
  final BidirectionalDictionaryEntry entry;
  final VoidCallback? onTap;
  final bool showDirection;

  const BidirectionalDictionaryListItem({
    super.key,
    required this.entry,
    this.onTap,
    this.showDirection = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        entry.writtenRep,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDirection) ...[
            Text(
              '${entry.sourceLanguage.toUpperCase()} → ${entry.targetLanguage.toUpperCase()}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            entry.displayText,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}