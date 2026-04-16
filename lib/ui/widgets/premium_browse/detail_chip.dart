import 'package:flutter/material.dart';

class DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color foregroundColor;
  final Color? liturgicalColor;
  final VoidCallback? onTap;

  const DetailChip({
    super.key,
    required this.label,
    required this.value,
    required this.foregroundColor,
    this.liturgicalColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final effectiveLiturgicalColor = liturgicalColor ?? theme.colorScheme.primary;
    
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLight
            ? Color.alphaBlend(
                Colors.white.withValues(alpha: 0.94),
                effectiveLiturgicalColor.withValues(alpha: 0.15),
              )
            : theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight
              ? effectiveLiturgicalColor.withValues(alpha: 0.35)
              : foregroundColor.withValues(alpha: 0.12),
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor.withValues(alpha: isLight ? 0.85 : 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: foregroundColor.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: chip,
      ),
    );
  }
}
