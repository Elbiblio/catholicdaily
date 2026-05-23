// Regression guards for the liturgical opening preference.
//
// The backend now returns scripture body text only. The preference controls
// whether the UI renders the reading's incipit as a separate block; it must not
// merge the incipit into the reading body.

import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/incipit_preference_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  tearDown(() {
    IncipitPreferenceService().resetCache();
  });

  final sampleDays = [
    DateTime(2026, 2, 22), // 1st Sunday of Lent
    DateTime(2026, 4, 5), // Easter Sunday
    DateTime(2026, 4, 12), // Divine Mercy
    DateTime(2026, 5, 23), // Nigeria missal regression
    DateTime(2026, 8, 16), // 20th OT
    DateTime(2026, 11, 22), // Christ the King
  ];

  test(
    'Preference does not merge incipits into reading body text',
    timeout: const Timeout(Duration(minutes: 4)),
    () async {
      final service = ReadingsService.instance;
      final pref = IncipitPreferenceService();

      await pref.setShowIncipit(true);
      pref.resetCache();
      final onOutputs = <String, String>{};
      for (final dt in sampleDays) {
        final readings = await service.getReadingsForDate(dt);
        for (final r in readings) {
          final pos = (r.position ?? '').toLowerCase();
          if (!pos.contains('reading') && !pos.contains('gospel')) continue;
          onOutputs['${dt.toIso8601String()}|${r.reading}'] = await service
              .getReadingText(
                r.reading,
                incipit: r.incipit,
                readingType: r.position,
              );
        }
      }

      await pref.setShowIncipit(false);
      pref.resetCache();
      final offOutputs = <String, String>{};
      for (final dt in sampleDays) {
        final readings = await service.getReadingsForDate(dt);
        for (final r in readings) {
          final pos = (r.position ?? '').toLowerCase();
          if (!pos.contains('reading') && !pos.contains('gospel')) continue;
          offOutputs['${dt.toIso8601String()}|${r.reading}'] = await service
              .getReadingText(
                r.reading,
                incipit: r.incipit,
                readingType: r.position,
              );
        }
      }

      await pref.setShowIncipit(true);
      pref.resetCache();

      expect(onOutputs.length, greaterThan(10));
      expect(offOutputs.length, equals(onOutputs.length));
      expect(onOutputs, equals(offOutputs));
    },
  );

  test(
    '2026-05-23 keeps official Nigeria intro separate from the body',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      final readings = await CsvReadingsResolverService.instance.resolve(
        DateTime(2026, 5, 23),
      );
      final service = ReadingsService.instance;

      final first = readings.firstWhere((r) => r.position == 'First Reading');
      final gospel = readings.firstWhere((r) => r.position == 'Gospel');

      expect(first.incipit, 'He lived in Rome, preaching the kingdom of God.');
      final firstText = await service.getReadingText(
        first.reading,
        incipit: first.incipit,
        readingType: first.position,
      );
      expect(
        _normalize(firstText),
        startsWith('16 when we came into rome paul was allowed'),
      );
      expect(
        _normalize(firstText),
        isNot(startsWith(_normalize(first.incipit ?? ''))),
      );

      expect(
        gospel.incipit,
        'This is the disciple who has written these things, and his testimony is true.',
      );
      final gospelText = await service.getReadingText(
        gospel.reading,
        incipit: gospel.incipit,
        readingType: gospel.position,
      );
      expect(
        _normalize(gospelText),
        startsWith('20 at that time peter turned and saw following'),
      );
      expect(
        _normalize(gospelText),
        isNot(startsWith(_normalize(gospel.incipit ?? ''))),
      );
    },
  );

  test(
    'Toggle round-trip: state persists through service restarts',
    timeout: const Timeout(Duration(seconds: 30)),
    () async {
      final svc = IncipitPreferenceService();
      await svc.setShowIncipit(false);
      svc.resetCache();
      expect(await svc.getShowIncipit(), isFalse);

      await svc.setShowIncipit(true);
      await svc.setUseReadingIntroReplacements(false);
      svc.resetCache();
      expect(await svc.getShowIncipit(), isTrue);
      expect(await svc.getUseReadingIntroReplacements(), isFalse);

      await svc.setUseReadingIntroReplacements(true);
      svc.resetCache();
      expect(await svc.getUseReadingIntroReplacements(), isTrue);
    },
  );

  test(
    'First-line replacement toggle can show raw Bible range text',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      final readings = await CsvReadingsResolverService.instance.resolve(
        DateTime(2026, 5, 23),
      );
      final first = readings.firstWhere((r) => r.position == 'First Reading');
      final service = ReadingsService.instance;
      final prefs = IncipitPreferenceService();

      await prefs.setUseReadingIntroReplacements(true);
      prefs.resetCache();
      final missalText = await service.getReadingText(
        first.reading,
        incipit: first.incipit,
        readingType: first.position,
      );

      await prefs.setUseReadingIntroReplacements(false);
      prefs.resetCache();
      final rawText = await service.getReadingText(
        first.reading,
        incipit: first.incipit,
        readingType: first.position,
      );

      await prefs.setUseReadingIntroReplacements(true);
      prefs.resetCache();

      expect(missalText, isNot(equals(rawText)));
      expect(_normalize(missalText), startsWith('16 when we came into rome'));
      expect(_normalize(rawText), startsWith('16 and when we came into rome'));
    },
  );

  test(
    'Locale pref: persists round-trip',
    timeout: const Timeout(Duration(seconds: 30)),
    () async {
      final svc = IncipitPreferenceService();
      expect(await svc.getLocale(), 'en');
      await svc.setLocale('en-GB');
      svc.resetCache();
      expect(await svc.getLocale(), 'en-GB');
      await svc.setLocale('en');
      svc.resetCache();
      expect(await svc.getLocale(), 'en');
    },
  );
}
