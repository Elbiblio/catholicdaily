import 'package:flutter/material.dart';
import '../../../data/models/daily_reading.dart';
import 'alternative_item.dart';

class AlternativesSection extends StatelessWidget {
  final List<DailyReading> alternatives;
  final Map<String, String> readingPreviews;
  final Color color;
  final bool isExpanded;
  final Animation<double> expandAnimation;
  final VoidCallback onToggleExpanded;
  final Function(DailyReading) onAlternativeSelected;

  const AlternativesSection({
    super.key,
    required this.alternatives,
    required this.readingPreviews,
    required this.color,
    required this.isExpanded,
    required this.expandAnimation,
    required this.onToggleExpanded,
    required this.onAlternativeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Expand/collapse button
        InkWell(
          onTap: onToggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: color.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isExpanded ? 'Hide Alternatives' : 'Show Alternatives',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${alternatives.length} available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Alternatives list
        SizeTransition(
          sizeFactor: expandAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: alternatives.asMap().entries.map((entry) {
                final index = entry.key;
                final alternative = entry.value;
                return AlternativeItem(
                  reading: alternative,
                  previewText: readingPreviews[alternative.reading],
                  color: color,
                  number: index + 1,
                  onTap: () => onAlternativeSelected(alternative),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
