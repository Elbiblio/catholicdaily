import 'package:flutter/material.dart';
import '../../../data/models/daily_reading.dart';
import 'reading_preview.dart';

class MainReading extends StatelessWidget {
  final DailyReading reading;
  final String baseType;
  final List<DailyReading> alternatives;
  final String? previewText;
  final Color color;
  final VoidCallback onTap;

  const MainReading({
    super.key,
    required this.reading,
    required this.baseType,
    this.alternatives = const [],
    this.previewText,
    required this.color,
    required this.onTap,
  });

  bool get hasAlternatives => alternatives.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final badgeBackground = isLight
        ? null
        : Color.alphaBlend(
            theme.colorScheme.surface.withValues(alpha: 0.86),
            color.withValues(alpha: 0.18),
          );
    final badgeForeground = isLight
        ? color
        : (ThemeData.estimateBrightnessForColor(badgeBackground!) == Brightness.dark
              ? Colors.white.withValues(alpha: 0.94)
              : theme.colorScheme.onSurface);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reading type badge with alternative indicator
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    gradient: isLight
                        ? LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.2),
                              color.withValues(alpha: 0.1),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLight
                          ? color.withValues(alpha: 0.3)
                          : color.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Text(
                    baseType,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeForeground,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (hasAlternatives) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '+${alternatives.length} alt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Reference
            Text(
              reading.reading,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 12),

            // Reading preview
            ReadingPreview(
              reading: reading,
              previewText: previewText,
            ),

            const SizedBox(height: 12),

            // Psalm response if applicable
            if (reading.psalmResponse != null && reading.psalmResponse!.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Response: ${reading.psalmResponse}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Arrow indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color.withValues(alpha: 0.6),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
