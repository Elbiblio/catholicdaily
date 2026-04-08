import 'package:flutter/material.dart';
import '../../../data/models/daily_reading.dart';
import 'reading_preview.dart';
import '../../utils/contrast_helper.dart';

class AlternativeItem extends StatelessWidget {
  final DailyReading reading;
  final String? previewText;
  final Color color;
  final int number;
  final VoidCallback onTap;

  const AlternativeItem({
    super.key,
    required this.reading,
    this.previewText,
    required this.color,
    required this.number,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Alternative $number',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ContrastHelper.getContrastColor(
                        color.withValues(alpha: 0.15),
                        theme,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: ContrastHelper.getSecondaryContrastColor(theme.colorScheme.surface, theme),
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reading.reading,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ReadingPreview(
              reading: reading,
              previewText: previewText,
            ),
            if (reading.psalmResponse != null && reading.psalmResponse!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Response: ${reading.psalmResponse}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
