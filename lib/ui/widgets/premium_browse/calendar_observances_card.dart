import 'package:flutter/material.dart';
import '../../../data/services/calendar_observance_service.dart';

class CalendarObservancesCard extends StatelessWidget {
  final DateTime date;

  const CalendarObservancesCard({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final observances = CalendarObservanceService.forDate(date);
    if (observances.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today’s Observances', style: theme.textTheme.titleSmall),
            for (final observance in observances) ...[
              const SizedBox(height: 8),
              Text(observance.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(observance.description, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
