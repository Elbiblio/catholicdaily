import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../utils/reading_title_formatter.dart';
import '../widgets/psalm_response_widget.dart';
import '../widgets/gospel_acclamation_widget.dart';

/// Detailed view of a single reading with psalm response support
class ReadingDetailScreen extends StatelessWidget {
  final DailyReading reading;
  final String readingText;
  final DateTime date;
  final LiturgicalDay? liturgicalDay;

  const ReadingDetailScreen({
    super.key,
    required this.reading,
    required this.readingText,
    required this.date,
    this.liturgicalDay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPsalm = (reading.position?.toLowerCase() ?? '').contains('psalm');
    final isGospel = (reading.position?.toLowerCase() ?? '').contains('gospel');
    final dateStr = DateFormat('EEEE, MMMM d, y').format(date);
    final heading = ReadingTitleFormatter.build(
      reference: reading.reading,
      position: reading.position,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heading,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (liturgicalDay?.rank != null || liturgicalDay?.title != null)
              Text(
                _formatLiturgicalInfo(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        backgroundColor: liturgicalDay?.colorValue ?? theme.primaryColor,
        foregroundColor: liturgicalDay?.textColor ?? Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copyToClipboard(context),
            tooltip: 'Copy text',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    dateStr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reference
            Text(
              reading.reading,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: liturgicalDay?.colorValue ?? theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            if (reading.position != null && reading.position != heading)
              Text(
                reading.position!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 24),

            // Psalm Response Widget (only for psalms)
            if (isPsalm) ...[
              PsalmResponseWidget(
                reading: reading,
                date: date,
              ),
              const SizedBox(height: 24),
            ],

            // Gospel Acclamation Widget (only for gospels)
            if (isGospel) ...[
              GospelAcclamationWidget(
                reading: reading,
                date: date,
              ),
              const SizedBox(height: 24),
            ],

            // Reading Text
            SelectableText(
              readingText,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.8,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  
  void _copyToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    final dateStr = DateFormat('EEEE, MMMM d, y').format(date);
    buffer.writeln(dateStr);
    buffer.writeln();
    
    final heading = ReadingTitleFormatter.build(
      reference: reading.reading,
      position: reading.position,
    );
    buffer.writeln(heading);
    buffer.writeln(reading.reading);
    if (reading.position != null && reading.position != heading) {
      buffer.writeln(reading.position!);
    }
    buffer.writeln();
    
    if (reading.psalmResponse != null && reading.psalmResponse!.trim().isNotEmpty) {
      buffer.writeln('Response: ${reading.psalmResponse}');
      buffer.writeln();
    }
    
    if (reading.gospelAcclamation != null && reading.gospelAcclamation!.trim().isNotEmpty) {
      buffer.writeln('Acclamation: ${reading.gospelAcclamation}');
      buffer.writeln();
    }
    
    buffer.write(readingText);

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reading copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatLiturgicalInfo() {
    final parts = <String>[];
    if (liturgicalDay?.rank != null) parts.add(liturgicalDay!.rank!);
    if (liturgicalDay?.title.isNotEmpty == true) parts.add(liturgicalDay!.title);
    return parts.join(' – ');
  }
}
