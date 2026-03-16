import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/lectionary_psalm_catalog_service.dart';
import 'package:catholic_daily/data/services/ordo_resolver_service.dart';
import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  late Directory tempDocsDir;
  late void Function() cleanupMocks;

  setUpAll(() async {
    tempDocsDir = await createTempTestDir('catholic_daily_backfill_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  test('export standard lectionary backfill refs', () async {
    OrdoResolverService.instance.setPreferOffline(true);
    final csvFile = File(r'c:\dev\catholicdaily-flutter\standard_lectionary_complete.csv');
    final outFile = File(r'c:\dev\catholicdaily-flutter\scripts\standard_backfill_refs.json');
    final lines = await csvFile.readAsLines();
    final rows = lines.skip(1).where((line) => line.trim().isNotEmpty).map(_parseCsvLine).toList();

    final missing = rows.where((row) {
      final day = row['day'] ?? '';
      final lectionaryNumber = row['lectionary_number'] ?? '';
      final firstReading = row['first_reading'] ?? '';
      return day != 'Sunday' && lectionaryNumber.isNotEmpty && firstReading.isEmpty;
    }).toList();

    final targets = <String, Map<String, String>>{};
    for (final row in missing) {
      final key = _targetKey(row);
      targets[key] = row;
    }

    final catalog = LectionaryPsalmCatalogService.instance;
    final backend = ReadingsBackendIo();
    final resolved = <String, Map<String, String>>{};

    for (var date = DateTime(2024, 1, 1);
        !date.isAfter(DateTime(2027, 12, 31));
        date = date.add(const Duration(days: 1))) {
      final entries = await catalog.getEntriesForDate(date);
      if (entries.isEmpty) {
        continue;
      }

      final readings = await backend.getReadingsForDate(date);
      final firstReading = _findFirstReading(readings);
      final gospel = _findGospel(readings);
      if (firstReading == null && gospel == null) {
        continue;
      }

      for (final entry in entries) {
        final rowKey = _targetKeyFromEntry(entry);
        final target = targets[rowKey];
        if (target == null || resolved.containsKey(rowKey)) {
          continue;
        }
        resolved[rowKey] = {
          'season': entry.season,
          'week': entry.week,
          'day': entry.day,
          'weekday_cycle': entry.weekdayCycle,
          'sunday_cycle': entry.sundayCycle,
          'reading_cycle': target['reading_cycle'] ?? '',
          'lectionary_number': entry.lectionaryNumber,
          'first_reading': firstReading?.reading ?? '',
          'gospel': gospel?.reading ?? '',
          'matched_date': date.toIso8601String(),
        };
      }
    }

    final sorted = resolved.values.toList()
      ..sort((a, b) => _targetKey(a).compareTo(_targetKey(b)));
    await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(sorted));

    print('Targets: ${targets.length}');
    print('Resolved: ${resolved.length}');
    print('Wrote: ${outFile.path}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

DailyReading? _findFirstReading(List<DailyReading> readings) {
  for (final reading in readings) {
    final position = (reading.position ?? '').toLowerCase();
    if (position.contains('first reading')) {
      return reading;
    }
  }
  for (final reading in readings) {
    final position = (reading.position ?? '').toLowerCase();
    if (!position.contains('psalm') && !position.contains('gospel') && !position.contains('second reading')) {
      return reading;
    }
  }
  return null;
}

DailyReading? _findGospel(List<DailyReading> readings) {
  for (final reading in readings) {
    final position = (reading.position ?? '').toLowerCase();
    if (position.contains('gospel')) {
      return reading;
    }
  }
  return null;
}

String _targetKey(Map<String, String> row) {
  return [
    row['season'] ?? '',
    row['week'] ?? '',
    row['day'] ?? '',
    row['weekday_cycle'] ?? '',
    row['lectionary_number'] ?? '',
    row['reading_cycle'] ?? '',
  ].join('|');
}

String _targetKeyFromEntry(LectionaryPsalmCatalogEntry entry) {
  return [
    entry.season,
    entry.week,
    entry.day,
    entry.weekdayCycle,
    entry.lectionaryNumber,
    '',
  ].join('|');
}

Map<String, String> _parseCsvLine(String line) {
  final values = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char == ',' && !inQuotes) {
      values.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  values.add(buffer.toString());

  const headers = [
    'season', 'week', 'day', 'weekday_cycle', 'sunday_cycle', 'reading_cycle',
    'first_reading', 'second_reading', 'psalm_reference', 'psalm_response',
    'gospel', 'acclamation_ref', 'acclamation_text', 'lectionary_number'
  ];

  final map = <String, String>{};
  for (var i = 0; i < headers.length && i < values.length; i++) {
    map[headers[i]] = values[i].trim();
  }
  return map;
}
