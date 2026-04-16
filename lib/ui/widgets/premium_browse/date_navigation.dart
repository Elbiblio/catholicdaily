import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../ui/utils/contrast_helper.dart';

class DateNavigation extends StatelessWidget {
  final DateTime selectedDate;
  final Color? liturgicalColor;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback? onDateTap;

  const DateNavigation({
    super.key,
    required this.selectedDate,
    this.liturgicalColor,
    required this.onPreviousDay,
    required this.onNextDay,
    this.onDateTap,
  });

  Color _resolveNavigationAccent(ThemeData theme, Color ordoColor) {
    if (theme.brightness == Brightness.dark) {
      return Color.lerp(ordoColor, Colors.white, 0.12) ?? ordoColor;
    }

    return Color.lerp(ordoColor, theme.colorScheme.primary, 0.18) ?? ordoColor;
  }

  Color _resolveHeaderForeground(ThemeData theme, Color backgroundColor) {
    return ContrastHelper.getContrastColor(backgroundColor, theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordoColor = liturgicalColor ?? theme.colorScheme.primary;
    final isLight = theme.brightness == Brightness.light;
    final navAccent = _resolveNavigationAccent(theme, ordoColor);
    final containerColor = isLight
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.72), navAccent.withValues(alpha: 0.42))
        : Color.alphaBlend(theme.colorScheme.surfaceContainer.withValues(alpha: 0.8), navAccent.withValues(alpha: 0.36));
    final buttonColor = isLight
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.84), navAccent.withValues(alpha: 0.34))
        : Color.alphaBlend(theme.colorScheme.surface.withValues(alpha: 0.88), navAccent.withValues(alpha: 0.28));
    final foregroundColor = _resolveHeaderForeground(theme, buttonColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? navAccent.withValues(alpha: 0.28)
              : navAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          // Previous button
          Expanded(
            child: IconButton(
              onPressed: onPreviousDay,
              icon: const Icon(Icons.chevron_left_rounded),
              style: IconButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: foregroundColor,
              ),
            ),
          ),

          // Date display (tappable to open calendar)
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: onDateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(selectedDate),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foregroundColor,
                      ),
                    ),
                    if (onDateTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: foregroundColor.withValues(alpha: 0.6),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Next button
          Expanded(
            child: IconButton(
              onPressed: onNextDay,
              icon: const Icon(Icons.chevron_right_rounded),
              style: IconButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
