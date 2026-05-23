import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/test_helpers.dart';

const _sampleDates = [
  '2026-05-24',
  '2026-05-25',
  '2026-05-26',
  '2026-05-31',
  '2026-06-01',
  '2026-06-03',
  '2026-06-05',
  '2026-06-07',
  '2026-06-11',
  '2026-06-12',
  '2026-06-13',
  '2026-06-24',
  '2026-06-29',
  '2026-07-03',
  '2026-07-11',
  '2026-07-22',
  '2026-05-27',
  '2026-05-30',
  '2026-06-02',
  '2026-06-09',
  '2026-06-16',
  '2026-06-20',
  '2026-06-23',
  '2026-06-27',
  '2026-07-01',
  '2026-07-07',
  '2026-07-15',
];

List<String> _auditDates() {
  final override = Platform.environment['AUDIT_DATES'];
  if (override == null || override.trim().isEmpty) {
    return _sampleDates;
  }
  return override
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

String _auditOutputPath() {
  return Platform.environment['AUDIT_OUTPUT'] ??
      'verification/ours_missal_window_audit.json';
}

String _firstLine(String text) {
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final clean = line.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isNotEmpty) return clean;
  }
  return '';
}

String _slotKey(DailyReading reading) {
  final position = (reading.position ?? '').toLowerCase();
  final isAlternative = position.contains('alternative');
  if (position.contains('first')) return 'first_reading';
  if (position.contains('second')) return 'second_reading';
  if (position.contains('psalm')) return 'psalm';
  if (position.contains('acclamation') || position.contains('alleluia')) {
    return 'acclamation';
  }
  if (position.contains('gospel')) {
    return isAlternative ? 'alternative_gospel' : 'gospel';
  }
  return position.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

Future<Map<String, dynamic>> _summarizeReading(
  ReadingsService service,
  DailyReading reading,
) async {
  final text = await service.getReadingText(
    reading.reading,
    incipit: reading.incipit,
    readingType: reading.position,
  );
  return {
    'position': reading.position,
    'reference': reading.reading,
    'incipit': reading.incipit,
    'psalm_response': reading.psalmResponse,
    'gospel_acclamation': reading.gospelAcclamation,
    'body_start': _firstLine(text),
  };
}

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test(
    'dump app readings for Nigeria official-window comparison',
    timeout: const Timeout(Duration(minutes: 4)),
    () async {
      final service = ReadingsService.instance;
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(LiturgicalRegion.nigeria);
      final rows = <Map<String, dynamic>>[];
      final sampleDates = _auditDates();
      for (final isoDate in sampleDates) {
        final date = DateTime.parse(isoDate);
        final readings = await service.getReadingsForDate(date);
        final row = <String, dynamic>{
          'date': isoDate,
          'feast': readings.isEmpty ? '' : readings.first.feast,
          'readings': readings.map((r) => r.toMap()).toList(),
        };
        for (final reading in readings) {
          final key = _slotKey(reading);
          row[key] = await _summarizeReading(service, reading);
        }
        rows.add(row);
      }

      final outFile = File(_auditOutputPath());
      outFile.parent.createSync(recursive: true);
      outFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(rows),
      );
      expect(rows, hasLength(sampleDates.length));
    },
  );
}
