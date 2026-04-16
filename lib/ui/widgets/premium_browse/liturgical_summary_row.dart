import 'package:flutter/material.dart';
import 'detail_chip.dart';

class LiturgicalSummaryRow extends StatelessWidget {
  final String seasonName;
  final int weekNumber;
  final String? sundayCycle;
  final String? weekdayCycle;
  final Color foregroundColor;
  final Color? liturgicalColor;
  final String? countdownLabel;
  final String? countdownValue;
  final VoidCallback? onCountdownTap;
  final VoidCallback? onInfoTap;

  const LiturgicalSummaryRow({
    super.key,
    required this.seasonName,
    required this.weekNumber,
    this.sundayCycle,
    this.weekdayCycle,
    required this.foregroundColor,
    this.liturgicalColor,
    this.countdownLabel,
    this.countdownValue,
    this.onCountdownTap,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final chipForeground = isLight ? theme.colorScheme.onSurface : foregroundColor;
    final isSunday = DateTime.now().weekday == DateTime.sunday;
    
    final chips = <Widget>[
      DetailChip(
        label: 'Season',
        value: seasonName,
        foregroundColor: chipForeground,
        liturgicalColor: liturgicalColor,
      ),
      if (weekNumber > 0)
        DetailChip(
          label: 'Week',
          value: '$weekNumber',
          foregroundColor: chipForeground,
          liturgicalColor: liturgicalColor,
        ),
      if (sundayCycle != null && isSunday)
        DetailChip(
          label: 'Sunday',
          value: sundayCycle!,
          foregroundColor: chipForeground,
          liturgicalColor: liturgicalColor,
        ),
      if (weekdayCycle != null && !isSunday)
        DetailChip(
          label: 'Year',
          value: weekdayCycle!,
          foregroundColor: chipForeground,
          liturgicalColor: liturgicalColor,
        ),
      if (countdownLabel != null && countdownValue != null)
        DetailChip(
          label: countdownLabel!,
          value: countdownValue!,
          foregroundColor: chipForeground,
          liturgicalColor: liturgicalColor,
          onTap: onCountdownTap,
        ),
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int index = 0; index < chips.length; index++) ...[
                  chips[index],
                  if (index < chips.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        if (onInfoTap != null) ...[  
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onInfoTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: foregroundColor.withValues(alpha: isLight ? 0.08 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: foregroundColor.withValues(alpha: isLight ? 0.55 : 0.65),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
