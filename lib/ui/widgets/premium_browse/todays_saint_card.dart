import 'package:flutter/material.dart';
import '../../../data/services/optional_memorial_service.dart';
import '../../../data/services/improved_liturgical_calendar_service.dart';

/// A compact card showing today's saint(s) / optional celebrations
/// on the daily readings dashboard.
class TodaysSaintCard extends StatelessWidget {
  final List<OptionalCelebration> celebrations;
  final LiturgicalDay? liturgicalDay;
  final bool isSuppressed;

  const TodaysSaintCard({
    super.key,
    required this.celebrations,
    required this.liturgicalDay,
    this.isSuppressed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (celebrations.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = _cardAccentColor(theme);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          accentColor.withValues(alpha: isDark ? 0.14 : 0.07),
          theme.colorScheme.surface,
        ),
        Color.alphaBlend(
          accentColor.withValues(alpha: isDark ? 0.22 : 0.13),
          theme.colorScheme.surface,
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: accentColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isSuppressed ? 'Commemoration' : 'Today\'s Saints',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Celebration entries
            ...celebrations.asMap().entries.map((entry) {
              final idx = entry.key;
              final c = entry.value;
              return Column(
                children: [
                  if (idx > 0)
                    Divider(
                      height: 12,
                      thickness: 0.5,
                      color: accentColor.withValues(alpha: 0.15),
                    ),
                  _buildCelebrationRow(theme, c, accentColor, isDark),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationRow(
    ThemeData theme,
    OptionalCelebration celebration,
    Color accentColor,
    bool isDark,
  ) {
    final celebColor = _colorForLiturgicalColor(celebration.color);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Liturgical color dot
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: celebColor,
            shape: BoxShape.circle,
            border: celebration.color == LiturgicalColor.white
                ? Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    width: 0.5,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        // Title and rank
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                celebration.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  _buildRankBadge(theme, celebration.rank, accentColor, isDark),
                  if (celebration.hasProperReadings) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.menu_book_rounded,
                      size: 12,
                      color: accentColor.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankBadge(
    ThemeData theme,
    CelebrationRank rank,
    Color accentColor,
    bool isDark,
  ) {
    final label = _rankLabel(rank);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: accentColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Color _cardAccentColor(ThemeData theme) {
    // Use the first celebration's liturgical color as the card accent
    if (celebrations.isNotEmpty) {
      final c = _colorForLiturgicalColor(celebrations.first.color);
      // For white saints, use a warm gold instead
      if (celebrations.first.color == LiturgicalColor.white) {
        return const Color(0xFFD4AF37);
      }
      return c;
    }
    return theme.colorScheme.tertiary;
  }

  static Color _colorForLiturgicalColor(LiturgicalColor color) {
    switch (color) {
      case LiturgicalColor.green:
        return const Color(0xFF228B22);
      case LiturgicalColor.purple:
        return const Color(0xFF6B3FA0);
      case LiturgicalColor.red:
        return const Color(0xFFB22222);
      case LiturgicalColor.pink:
        return const Color(0xFFFF69B4);
      case LiturgicalColor.white:
        return const Color(0xFFF5F5F5);
      case LiturgicalColor.gold:
        return const Color(0xFFD4AF37);
    }
  }

  static String _rankLabel(CelebrationRank rank) {
    switch (rank) {
      case CelebrationRank.solemnity:
        return 'Solemnity';
      case CelebrationRank.feast:
        return 'Feast';
      case CelebrationRank.obligatoryMemorial:
        return 'Memorial';
      case CelebrationRank.optionalMemorial:
        return 'Optional Memorial';
    }
  }
}
