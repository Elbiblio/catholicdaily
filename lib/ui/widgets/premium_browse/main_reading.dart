import 'package:flutter/material.dart';
import '../../../data/models/daily_reading.dart';
import 'reading_preview.dart';
import '../../utils/contrast_helper.dart';

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
        ? ContrastHelper.getContrastColor(
            Color.alphaBlend(
              Colors.white.withValues(alpha: 0.94),
              color.withValues(alpha: 0.15),
            ),
            theme,
          )
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
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '+${alternatives.length} alt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ContrastHelper.getContrastColor(
                          theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          theme,
                        ),
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 16,
                      color: ContrastHelper.getContrastColor(
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Response: ${reading.psalmResponse}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ContrastHelper.getContrastColor(
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                            theme,
                          ),
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
