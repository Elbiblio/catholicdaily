import 'package:flutter/material.dart';
import '../../../data/models/daily_reading.dart';
import '../../../data/services/improved_liturgical_calendar_service.dart';
import '../../utils/reading_type_colors.dart';

/// A compact "Mass at a Glance" summary card showing all reading references
/// for the day with a "Begin Mass" CTA.
class DailyMassAtAGlanceCard extends StatelessWidget {
  final LiturgicalDay? liturgicalDay;
  final List<({String baseType, DailyReading mainReading})> readingGroups;
  final VoidCallback onBeginMass;
  final void Function(String baseType, DailyReading reading) onReadingRowTap;

  const DailyMassAtAGlanceCard({
    super.key,
    required this.liturgicalDay,
    required this.readingGroups,
    required this.onBeginMass,
    required this.onReadingRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final liturgicalColor =
        liturgicalDay?.colorValue ?? theme.colorScheme.primary;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          liturgicalColor.withValues(alpha: isDark ? 0.18 : 0.10),
          theme.colorScheme.surface,
        ),
        Color.alphaBlend(
          liturgicalColor.withValues(alpha: isDark ? 0.28 : 0.18),
          theme.colorScheme.surface,
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: liturgicalColor.withValues(alpha: 0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: liturgicalColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, theme, liturgicalColor),
            if (readingGroups.isNotEmpty) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: liturgicalColor.withValues(alpha: 0.18),
              ),
              ...readingGroups.map(
                (g) => _buildReadingRow(context, theme, liturgicalColor, g),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    Color liturgicalColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final subtitle = liturgicalDay?.title.isNotEmpty == true
        ? liturgicalDay!.title
        : liturgicalDay?.seasonName ?? '';

    // Header sits on the top-left of the gradient (lower alpha end)
    final headerBg = Color.alphaBlend(
      liturgicalColor.withValues(alpha: isDark ? 0.18 : 0.10),
      theme.colorScheme.surface,
    );
    final iconColor = ReadingTypeColors.ensureContrast(
      liturgicalColor,
      headerBg,
      minRatio: 3.0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.church_rounded,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mass at a Glance',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Builder(builder: (context) {
            // Resolve the actual opaque button background so foreground
            // contrast can be calculated accurately.
            final btnBg = Color.alphaBlend(
              liturgicalColor.withValues(alpha: 0.18),
              theme.colorScheme.surface,
            );
            // Use the liturgical color as foreground only if it passes 4.5:1;
            // otherwise fall back to black/white.
            final btnFg = ReadingTypeColors.ensureContrast(
              liturgicalColor,
              btnBg,
              minRatio: 4.5,
            );
            return FilledButton.tonal(
              onPressed: onBeginMass,
              style: FilledButton.styleFrom(
                backgroundColor: btnBg,
                foregroundColor: btnFg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Begin Mass'),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReadingRow(
    BuildContext context,
    ThemeData theme,
    Color liturgicalColor,
    ({String baseType, DailyReading mainReading}) group,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    // Compute the effective row background (bottom-end of the card gradient)
    final rowBackground = Color.alphaBlend(
      liturgicalColor.withValues(alpha: isDark ? 0.28 : 0.18),
      theme.colorScheme.surface,
    );
    final accentColor = ReadingTypeColors.forType(
      group.baseType,
      context,
      liturgicalColor: liturgicalColor,
      background: rowBackground,
    );
    final psalmResponse = group.mainReading.psalmResponse;

    return InkWell(
      onTap: () => onReadingRowTap(group.baseType, group.mainReading),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.baseType.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    group.mainReading.reading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (psalmResponse != null && psalmResponse.isNotEmpty) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.music_note_rounded,
                size: 14,
                color: accentColor.withValues(alpha: 0.7),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}
