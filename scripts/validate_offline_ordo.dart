import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';

class _ReadingRow {
  final int position;
  final String? psalmResponse;

  const _ReadingRow({required this.position, required this.psalmResponse});
}

void main() {
  test('Offline Ordo Validator', () async {
    final summary = await runValidation();
    expect(summary['resolver_errors'], 0);
  }, timeout: Timeout.none);
}

Future<Map<String, dynamic>> runValidation() async {
  final cwd = Directory.current.path;
  final dbPath = p.join(cwd, 'assets', 'readings.db');
  final reportDir = Directory(p.join(cwd, 'scripts', 'reports'));
  final reportPath = p.join(
    reportDir.path,
    'offline_ordo_validation_report.json',
  );

  if (!File(dbPath).existsSync()) {
    throw StateError('readings.db not found at: $dbPath');
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabase(dbPath, readOnly: true);

  final hasPsalmResponseColumn = await _hasColumn(
    db,
    'readings',
    'psalm_response',
  );
  final readingSql = hasPsalmResponseColumn
      ? 'SELECT timestamp, position, psalm_response FROM readings ORDER BY timestamp, position'
      : 'SELECT timestamp, position, NULL AS psalm_response FROM readings ORDER BY timestamp, position';
  final rows = await db.rawQuery(readingSql);

  final byTimestamp = <int, List<_ReadingRow>>{};
  var minTimestamp = 1 << 62;
  var maxTimestamp = 0;
  for (final row in rows) {
    final ts = (row['timestamp'] as num).toInt();
    final pos = (row['position'] as num?)?.toInt() ?? 0;
    final psalmResponse = row['psalm_response'] as String?;
    byTimestamp
        .putIfAbsent(ts, () => <_ReadingRow>[])
        .add(_ReadingRow(position: pos, psalmResponse: psalmResponse));
    if (ts > 1000000) {
      if (ts < minTimestamp) minTimestamp = ts;
      if (ts > maxTimestamp) maxTimestamp = ts;
    }
  }

  final service = OfflineOrdoLookupService.instance;
  final startDate = DateTime.utc(2000, 1, 1);
  final endDate = DateTime.utc(2038, 12, 31);
  final maxDbDate = DateTime.fromMillisecondsSinceEpoch(
    maxTimestamp * 1000,
    isUtc: true,
  );

  final mismatches = <Map<String, dynamic>>[];
  var resolvedDays = 0;
  var resolverErrors = 0;
  var missingReadingDates = 0;
  var incompleteReadingSets = 0;
  var missingPsalmResponses = 0;

  for (
    var day = startDate;
    !day.isAfter(endDate);
    day = day.add(const Duration(days: 1))
  ) {
    final keyDate = DateTime.utc(day.year, day.month, day.day);
    try {
      service.resolve(keyDate);
      resolvedDays++;
    } catch (e) {
      resolverErrors++;
      mismatches.add({
        'type': 'resolver_error',
        'date': keyDate.toIso8601String().split('T').first,
        'error': '$e',
      });
      continue;
    }

    final ts = _timestampForDate(keyDate);
    final dayRows = byTimestamp[ts] ?? const <_ReadingRow>[];
    final expectReadings = !keyDate.isAfter(maxDbDate);
    if (expectReadings && dayRows.isEmpty) {
      missingReadingDates++;
      mismatches.add({
        'type': 'missing_readings',
        'date': keyDate.toIso8601String().split('T').first,
      });
      continue;
    }
    if (dayRows.isEmpty) continue;

    final positions = dayRows.map((r) => r.position).toSet();
    final hasRequired =
        positions.contains(1) && positions.contains(2) && positions.contains(4);
    if (!hasRequired) {
      incompleteReadingSets++;
      mismatches.add({
        'type': 'incomplete_reading_set',
        'date': keyDate.toIso8601String().split('T').first,
        'positions': positions.toList()..sort(),
      });
    }

    for (final row in dayRows.where((r) => r.position == 2)) {
      final response = row.psalmResponse?.trim() ?? '';
      if (response.isEmpty) {
        missingPsalmResponses++;
        mismatches.add({
          'type': 'missing_psalm_response',
          'date': keyDate.toIso8601String().split('T').first,
        });
        break;
      }
    }
  }

  await db.close();

  reportDir.createSync(recursive: true);
  final report = {
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'range_start': '2000-01-01',
    'range_end': '2038-12-31',
    'db_min_date': minTimestamp > 1000000
        ? DateTime.fromMillisecondsSinceEpoch(
            minTimestamp * 1000,
            isUtc: true,
          ).toIso8601String().split('T').first
        : null,
    'db_max_date': maxDbDate.toIso8601String().split('T').first,
    'summary': {
      'resolved_days': resolvedDays,
      'resolver_errors': resolverErrors,
      'missing_reading_dates': missingReadingDates,
      'incomplete_reading_sets': incompleteReadingSets,
      'missing_psalm_responses': missingPsalmResponses,
      'total_mismatches': mismatches.length,
    },
    'mismatches': mismatches,
  };

  File(
    reportPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));

  stdout.writeln('Offline ordo validation complete.');
  stdout.writeln('Report: $reportPath');
  stdout.writeln(jsonEncode(report['summary']));
  return report['summary'] as Map<String, dynamic>;
}

int _timestampForDate(DateTime dateUtc) =>
    DateTime.utc(
      dateUtc.year,
      dateUtc.month,
      dateUtc.day,
      8,
    ).millisecondsSinceEpoch ~/
    1000;

Future<bool> _hasColumn(Database db, String table, String column) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.any((row) => row['name'] == column);
}
