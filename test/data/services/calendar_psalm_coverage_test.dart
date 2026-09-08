import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/reading_catalog_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_preference.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(cleanup);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ResponsorialPsalmPreference.resetForTest();
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  test(
    'September 8 loads the complete reading set including its psalm',
    () async {
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      await prefs.setRegion(LiturgicalRegion.nigeria);
      final date = DateTime(2026, 9, 8);
      final sets = await AlternateReadingsService.instance
          .getAvailableReadingSets(date);
      final hydrated = await ReadingFlowService.instance.hydrateReadingSet(
        date: date,
        readings: sets.first.readings,
      );
      expect(hydrated.readings.any((r) => r.position == 'Gospel'), isTrue);
      expect(hydrated.psalmSources, isNotEmpty);
      final text = hydrated.psalmSources.values.first.text;
      expect(text, contains('R/.'));
      expect(text.toLowerCase(), contains('salvation'));
      expect(text.toLowerCase(), contains('sing'));
      expect(
        hydrated.readingTexts.values,
        everyElement(isNot(contains('unavailable'))),
      );
    },
  );

  test('a missing psalm cannot discard the other readings', () async {
    final date = DateTime(2026, 9, 8);
    final result = await ReadingFlowService.instance.hydrateReadingSet(
      date: date,
      readings: [
        DailyReading(reading: 'John 1:1-5', position: 'Gospel', date: date),
        DailyReading(
          reading: 'Ps 999:1',
          position: 'Responsorial Psalm',
          date: date,
          psalmResponse: 'Lord, hear us.',
        ),
      ],
    );
    expect(result.readings, hasLength(2));
    expect(result.readingTexts['John 1:1-5'], contains('Word'));
    expect(result.readingTexts['Ps 999:1'], contains('unavailable'));
    expect(result.psalmSources, isEmpty);
  });

  test('dated Advent weekdays preserve Sunday precedence', () async {
    final prefs = await LiturgicalRegionPreferenceService.getInstance();
    await prefs.setRegion(LiturgicalRegion.generalRoman);
    final readings = await CsvReadingsResolverService.instance.resolve(
      DateTime(2026, 12, 20),
    );
    expect(
      readings.where((r) => r.position == 'Gospel').map((r) => r.reading),
      ['Luke 1:26-38'],
    );
    expect(
      readings
          .where((r) => r.position == 'Second Reading')
          .map((r) => r.reading),
      ['Rom 16:25-27'],
    );
  });

  test(
    'incomplete NABRE imports use complete, labelled canticle text',
    () async {
      final preference = await ResponsorialPsalmPreference.getInstance();
      await preference.setEditionId('local_nabre');
      for (final sample in {
        'Tobit 13:2,6a,6b,6c,6d': 'he shows mercy',
        'Tobit 13:2,3-4,6abcd,6ef': 'all your heart',
        '1 Chr 29:10b,11abc,11d-12a,12bcd': 'greatness',
        '1 Sam 2:1,4-5,6-7,8abcd': 'poor from the dust',
        'Exod 15:1-2,3-4,5-6': 'my strength',
        'Exod 15:1-2,3-4,5-6,17-18': 'my strength',
        'Deut 32:3-4a,7,8,9+12': 'days of old',
        'Isa 12:1-6': 'not be afraid',
      }.entries) {
        final result = await ReadingsService.instance.resolveResponsorialPsalm(
          sample.key,
          psalmResponse: 'Thanks be to God.',
          date: DateTime(2026),
          territory: 'general',
        );
        expect(result.actualEditionId, 'local_rsvce', reason: sample.key);
        expect(
          result.text.toLowerCase(),
          contains(sample.value),
          reason: sample.key,
        );
        if (sample.key.startsWith('Tobit')) {
          expect(
            'all your heart'.allMatches(result.text.toLowerCase()),
            hasLength(1),
          );
        }
      }
    },
  );

  test(
    'Nativity split-verse reference contains both stanzas in all regions',
    () async {
      for (final region in LiturgicalRegion.values) {
        final psalm = await ReadingsService.instance.resolveResponsorialPsalm(
          'Ps 13:6ab, 6c',
          psalmResponse: 'With delight I rejoice in the Lord.',
          date: DateTime(2026, 9, 8),
          territory: region.code,
        );
        expect(psalm.text.toLowerCase(), contains('salvation'));
        expect(psalm.text.toLowerCase(), contains('sing'));
      }
    },
  );

  test(
    'every named memorial and feast choice has psalm text',
    () async {
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      await prefs.setRegion(LiturgicalRegion.generalRoman);
      final entries = await ReadingCatalogService.instance
          .loadMemorialEntries();
      final references = <String, String>{};
      final failures = <String>[];
      for (final entry in entries) {
        if (entry.month.isEmpty || entry.day.isEmpty) continue;
        final date = DateTime(
          2026,
          int.parse(entry.month),
          int.parse(entry.day),
        );
        final proper = await CsvReadingsResolverService.instance
            .resolveCelebrationChoice(
              date: date,
              celebrationId: entry.id,
              celebrationTitle: entry.title,
            );
        final sets = await AlternateReadingsService.instance
            .getAvailableReadingSets(date);
        final readings = [...proper, for (final set in sets) ...set.readings];
        for (final psalm in readings.where(
          (r) => (r.position ?? '').contains('Responsorial Psalm'),
        )) {
          references[psalm.reading] = psalm.psalmResponse ?? '';
          try {
            final result = await ReadingsService.instance
                .resolveResponsorialPsalm(
                  psalm.reading,
                  psalmResponse: psalm.psalmResponse ?? '',
                  date: date,
                  territory: 'general',
                );
            expect(result.text, isNot(contains('unavailable')));
          } catch (error) {
            failures.add('${entry.id}: ${psalm.reading}: $error');
          }
        }
      }
      const output = String.fromEnvironment('PSALM_COVERAGE_OUTPUT');
      if (output.isNotEmpty)
        File(output).writeAsStringSync(jsonEncode(references));
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'six calendar years have renderable psalms in every region',
    () async {
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      final failures = <String, List<String>>{};
      final checked = <String>{};
      final references = <String, String>{};
      var days = 0;
      const selectedRegion = String.fromEnvironment('AUDIT_REGION');
      for (final region in LiturgicalRegion.values) {
        if (selectedRegion.isNotEmpty && selectedRegion != region.code)
          continue;
        await prefs.setRegion(region);
        for (
          var date = DateTime(2025);
          date.isBefore(DateTime(2031));
          date = DateTime(date.year, date.month, date.day + 1)
        ) {
          final readings = await CsvReadingsResolverService.instance.resolve(
            date,
          );
          final psalms = readings.where(
            (r) => (r.position ?? '').contains('Responsorial Psalm'),
          );
          if (psalms.isEmpty &&
              !readings.any((r) => (r.position ?? '').contains('Passion'))) {
            failures
                .putIfAbsent('No psalm reference', () => [])
                .add('${region.code} $date');
          }
          for (final psalm in psalms) {
            references[psalm.reading] = psalm.psalmResponse ?? '';
            if (!checked.add(
              '${region.code}|${psalm.reading}|${psalm.psalmResponse}',
            ))
              continue;
            try {
              final result = await ReadingsService.instance
                  .resolveResponsorialPsalm(
                    psalm.reading,
                    psalmResponse: psalm.psalmResponse ?? '',
                    date: date,
                    territory: region.code,
                  );
              expect(result.text.trim(), isNotEmpty);
              expect(result.text, isNot(contains('unavailable')));
            } catch (error) {
              failures
                  .putIfAbsent('${psalm.reading}: $error', () => [])
                  .add(
                    '${region.code} ${date.toIso8601String().substring(0, 10)}',
                  );
            }
          }
          days++;
        }
        // ignore: avoid_print
        print('Psalm coverage: ${region.code} complete ($days days checked)');
      }
      const output = String.fromEnvironment('PSALM_COVERAGE_OUTPUT');
      if (output.isNotEmpty) {
        File(output).writeAsStringSync(jsonEncode(references));
      }
      expect(
        failures,
        isEmpty,
        reason:
            '$days days checked\n${failures.entries.map((e) => '${e.key} (${e.value.length} days; ${e.value.take(3).join(', ')})').join('\n')}',
      );
    },
    timeout: const Timeout(Duration(minutes: 45)),
  );
}
