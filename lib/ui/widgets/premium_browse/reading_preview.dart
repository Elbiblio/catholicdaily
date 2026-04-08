import 'package:flutter/material.dart';
import '../../../data/models/daily_reading.dart';

class ReadingPreview extends StatelessWidget {
  final DailyReading reading;
  final String? previewText;
  final int maxLines;

  const ReadingPreview({
    super.key,
    required this.reading,
    this.previewText,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = previewText ?? '';

    if (preview.isEmpty) {
      return Text(
        'No preview available',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Text(
      preview,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
        height: 1.5,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
