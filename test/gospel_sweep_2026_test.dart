import 'dart:io';

import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  late Directory tempDocsDir;
  late void Function() cleanupMocks;
  late ReadingsBackendIo backend;

  setUpAll(() async {
    tempDocsDir = await createTempTestDir('catholic_daily_gospel_sweep_2026_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
    backend = ReadingsBackendIo();
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  group('2026 reading sweep', () {
    test('every day resolves readings and at least one gospel', () async {
      final emptyDays = <DateTime>[];
      final missingGospelDays = <DateTime>[];

      for (var day = DateTime(2026, 1, 1);
          !day.isAfter(DateTime(2026, 12, 31));
          day = day.add(const Duration(days: 1))) {
        final readings = await backend.getReadingsForDate(day);
        if (readings.isEmpty) {
          emptyDays.add(day);
          continue;
        }

        final hasGospel = readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel'));
        if (!hasGospel) {
          missingGospelDays.add(day);
        }
      }

      expect(emptyDays, isEmpty,
          reason: 'Days with no readings: ${emptyDays.map(_fmt).join(', ')}');
      expect(missingGospelDays, isEmpty,
          reason: 'Days with no gospel entry: ${missingGospelDays.map(_fmt).join(', ')}');
    });

    test('gospel output has no duplicate immediate opener markers', () async {
      final suspicious = <String>[];
      final sampledDays = <DateTime>{
        for (var month = 1; month <= 12; month++) DateTime(2026, month, 1),
        DateTime(2026, 2, 18),
        DateTime(2026, 3, 18),
        DateTime(2026, 3, 29),
        DateTime(2026, 4, 4),
        DateTime(2026, 4, 5),
        DateTime(2026, 12, 24),
        DateTime(2026, 12, 25),
      };

      for (final day in sampledDays.toList()..sort()) {
        final readings = await backend.getReadingsForDate(day);
        final gospels = readings.where((r) => (r.position ?? '').toLowerCase().contains('gospel'));

        for (final gospel in gospels) {
          final text = await backend.getReadingText(
            gospel.reading,
            psalmResponse: gospel.psalmResponse,
            incipit: gospel.incipit,
          );

          final normalized = text.trimLeft();
          final duplicated = RegExp(
            r'^(?:\d+[a-z]?\.\s+)?(At that time|In those days|Thus says the LORD):\s+\1',
            caseSensitive: false,
          ).hasMatch(normalized);

          if (duplicated) {
            suspicious.add('${_fmt(day)} | ${gospel.reading}');
          }
        }
      }

      expect(suspicious, isEmpty,
          reason: 'Possible duplicated openers: ${suspicious.join(' ; ')}');
    });
  });
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
