import 'dart:math';

import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/models/responsorial_psalm_text_entry.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/feast_reminder_preferences.dart';
import 'package:catholic_daily/data/services/feast_reminder_service.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
import 'package:catholic_daily/data/services/saint_profile_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_source_pack_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_text_catalog_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  final lookup = OfflineOrdoLookupService.instance;

  setUp(() async {
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.nigeria);
  });

  group('Nigeria contentious feasts and reminders', () {
    test('2026 Nigeria missal dates resolve with the correct rank', () {
      final expectations = <DateTime, (String, String)>{
        DateTime(2026, 4, 30): ('Our Lady Mother of Africa', 'Feast'),
        DateTime(2026, 5, 14): ('The Ascension of the Lord', 'Solemnity'),
        DateTime(2026, 6, 7): (
          'The Most Holy Body and Blood of Christ',
          'Solemnity',
        ),
        DateTime(2026, 10, 1): ('Our Lady, Queen of Nigeria', 'Solemnity'),
        DateTime(2026, 11, 22): (
          'Our Lord Jesus Christ, King of the Universe',
          'Solemnity',
        ),
      };

      for (final entry in expectations.entries) {
        final day = lookup.resolve(entry.key, region: LiturgicalRegion.nigeria);
        expect(day.title, entry.value.$1, reason: entry.key.toIso8601String());
        expect(day.rank, entry.value.$2, reason: entry.key.toIso8601String());
      }

      final matthiasCollision = lookup.resolve(
        DateTime(2026, 5, 14),
        region: LiturgicalRegion.nigeria,
      );
      expect(matthiasCollision.title, isNot('Saint Matthias, Apostle'));

      final corpusThursday = lookup.resolve(
        DateTime(2026, 6, 4),
        region: LiturgicalRegion.nigeria,
      );
      expect(
        corpusThursday.title,
        isNot('The Most Holy Body and Blood of Christ'),
      );
    });

    test('Ordinary Time Sunday titles stay aligned after Easter', () {
      expect(
        ImprovedLiturgicalCalendarService.instance
            .getLiturgicalDay(DateTime(2026, 1, 18))
            .weekNumber,
        2,
      );
      expect(
        lookup
            .resolve(DateTime(2026, 1, 25), region: LiturgicalRegion.nigeria)
            .title,
        '3rd Sunday in Ordinary Time',
      );
      expect(
        lookup
            .resolve(DateTime(2026, 10, 18), region: LiturgicalRegion.nigeria)
            .title,
        '29th Sunday in Ordinary Time',
      );
      expect(
        lookup
            .resolve(DateTime(2026, 1, 18), region: LiturgicalRegion.nigeria)
            .title,
        '2nd Sunday in Ordinary Time',
      );
      expect(
        lookup
            .resolve(DateTime(2026, 7, 26), region: LiturgicalRegion.nigeria)
            .title,
        '17th Sunday in Ordinary Time',
      );
      expect(
        lookup
            .resolve(DateTime(2026, 11, 8), region: LiturgicalRegion.nigeria)
            .title,
        '32nd Sunday in Ordinary Time',
      );
      expect(
        lookup
            .resolve(DateTime(2026, 5, 26), region: LiturgicalRegion.nigeria)
            .weekNumber,
        8,
      );
    });

    test(
      'reminder preview includes Nigeria local and transferred feasts',
      () async {
        final events = await FeastReminderService.instance
            .buildPreviewEventsForTesting(
              2026,
              FeastReminderRank.feastsDays,
              region: LiturgicalRegion.nigeria,
            );

        void expectEvent(DateTime date, String title, String rank) {
          expect(
            events,
            contains(
              isA<FeastReminderPreviewEvent>()
                  .having((event) => event.date, 'date', date)
                  .having((event) => event.title, 'title', title)
                  .having((event) => event.rank, 'rank', rank),
            ),
          );
        }

        expectEvent(
          DateTime(2026, 4, 30),
          'Our Lady Mother of Africa',
          'Feast',
        );
        expectEvent(
          DateTime(2026, 5, 14),
          'The Ascension of the Lord',
          'Solemnity',
        );
        expectEvent(
          DateTime(2026, 6, 7),
          'The Most Holy Body and Blood of Christ',
          'Solemnity',
        );
        expectEvent(
          DateTime(2026, 10, 1),
          'Our Lady, Queen of Nigeria',
          'Solemnity',
        );
        final queenOfNigeria = events.singleWhere(
          (event) => event.title == 'Our Lady, Queen of Nigeria',
        );
        expect(queenOfNigeria.saintProfileId, 'our_lady_queen_of_nigeria');
        expectEvent(
          DateTime(2026, 11, 22),
          'Our Lord Jesus Christ, King of the Universe',
          'Solemnity',
        );
      },
    );

    test(
      'major feast and solemnity reminders get a second notification',
      () async {
        final reminders = await FeastReminderService.instance
            .buildScheduledRemindersForTesting(
              now: DateTime(2026, 4, 20, 9),
              monthsAhead: 1,
              rank: FeastReminderRank.feastsDays,
              hour: 9,
              minute: 0,
              notifyDayBefore: false,
              region: LiturgicalRegion.nigeria,
            );

        List<FeastReminderScheduledPreviewEvent> remindersFor(String title) =>
            reminders.where((event) => event.title == title).toList();

        final regularFeast = remindersFor('Saint Mark, Evangelist');
        expect(regularFeast, hasLength(1));
        expect(regularFeast.single.scheduledTime, DateTime(2026, 4, 25, 9));
        expect(regularFeast.single.isAdditionalReminder, isFalse);

        final majorFeast = remindersFor('Our Lady Mother of Africa');
        expect(majorFeast, hasLength(2));
        expect(
          majorFeast.map((event) => event.scheduledTime),
          containsAll([DateTime(2026, 4, 29, 20), DateTime(2026, 4, 30, 9)]),
        );
        expect(majorFeast.any((event) => event.isAdditionalReminder), isTrue);

        final solemnity = remindersFor('The Ascension of the Lord');
        expect(solemnity, hasLength(2));
        expect(
          solemnity.map((event) => event.scheduledTime),
          containsAll([DateTime(2026, 5, 13, 20), DateTime(2026, 5, 14, 9)]),
        );
        expect(solemnity.any((event) => event.isAdditionalReminder), isTrue);
      },
    );

    test('every saint-like scheduled feast has a detail deep link', () async {
      final events = await FeastReminderService.instance
          .buildPreviewEventsForTesting(
            2026,
            FeastReminderRank.all,
            region: LiturgicalRegion.nigeria,
          );
      final missing = events
          .where(
            (event) =>
                SaintProfileService.isSaintLikeTitle(event.title) &&
                event.saintProfileId == null,
          )
          .map((event) => event.title)
          .toList();

      expect(missing, isEmpty, reason: 'Missing reminder deep links: $missing');
    });

    test(
      'all-reminders mode includes researched optional and obligatory memorials',
      () async {
        final events2025 = await FeastReminderService.instance
            .buildPreviewEventsForTesting(
              2025,
              FeastReminderRank.all,
              region: LiturgicalRegion.nigeria,
            );
        final events2026 = await FeastReminderService.instance
            .buildPreviewEventsForTesting(
              2026,
              FeastReminderRank.all,
              region: LiturgicalRegion.nigeria,
            );

        void expectDeepLink(
          List<FeastReminderPreviewEvent> events,
          DateTime date,
          String profileId,
        ) {
          expect(
            events,
            contains(
              isA<FeastReminderPreviewEvent>()
                  .having((event) => event.date, 'date', date)
                  .having(
                    (event) => event.saintProfileId,
                    'saintProfileId',
                    profileId,
                  ),
            ),
          );
        }

        // Bakhita falls on a Sunday in 2026, so use an unsuppressed year.
        expectDeepLink(events2025, DateTime(2025, 2, 8), 'josephine_bakhita');
        expectDeepLink(events2026, DateTime(2026, 5, 1), 'joseph_the_worker');
        expectDeepLink(events2026, DateTime(2026, 7, 9), 'augustine_zhao_rong');
        expectDeepLink(
          events2026,
          DateTime(2026, 8, 14),
          'maximilian_mary_kolbe',
        );
        expectDeepLink(events2026, DateTime(2026, 9, 5), 'teresa_of_calcutta');
        expectDeepLink(
          events2026,
          DateTime(2026, 9, 17),
          'hildegard_of_bingen',
        );
        expectDeepLink(events2026, DateTime(2026, 11, 3), 'martin_de_porres');

        expect(
          events2026.where(
            (event) =>
                event.date == DateTime(2026, 2, 8) &&
                event.saintProfileId == 'josephine_bakhita',
          ),
          isEmpty,
          reason: 'A Sunday must retain liturgical precedence.',
        );
      },
    );
  });

  group('Nigeria readings audit', () {
    test(
      'official Nigeria psalm pack covers and matches the full liturgical year',
      () async {
        final raw = await rootBundle.loadString(
          'assets/data/psalm_editions/nigeria_365.csv',
        );
        final official = ResponsorialPsalmSourcePackService.parsePackCsv(raw);
        final start = DateTime(2025, 12, 1);
        final expectedDates = <String>{
          for (var offset = 0; offset < 365; offset++)
            _isoDay(start.add(Duration(days: offset))),
        };
        final byDate = <String, List<ResponsorialPsalmTextEntry>>{};
        for (final entry in official) {
          if (entry.dateRule.isEmpty) continue;
          byDate
              .putIfAbsent(entry.dateRule, () => <ResponsorialPsalmTextEntry>[])
              .add(entry);
        }

        expect(byDate.keys.toSet(), expectedDates);

        final mismatches = <String>[];
        for (final dateRule in expectedDates) {
          final date = DateTime.parse(dateRule);
          final readingSets =
              (await AlternateReadingsService.instance.getAvailableReadingSets(
                date,
              )).map((choice) => choice.readings).toList();
          if (dateRule == '2026-04-02') {
            readingSets.addAll(
              (await CsvReadingsResolverService.instance
                      .resolveOtherMassChoices(
                        date: date,
                        celebrationTitle:
                            "Holy Thursday - Evening Mass of the Lord's Supper",
                      ))
                  .map((choice) => choice.readings),
            );
          }
          final vigilTitle = switch (dateRule) {
            '2025-12-24' => 'The Nativity of the Lord',
            '2026-05-23' => 'Pentecost Sunday',
            '2026-06-28' => 'Saints Peter and Paul, Apostles',
            '2026-08-14' => 'The Assumption of the Blessed Virgin Mary',
            _ => '',
          };
          if (vigilTitle.isNotEmpty) {
            readingSets.add(
              await CsvReadingsResolverService.instance.resolveVigilChoice(
                date: date,
                celebrationTitle: vigilTitle,
              ),
            );
          }
          final psalms = readingSets
              .expand((set) => set)
              .where(
                (reading) =>
                    (reading.position ?? '').startsWith('Responsorial Psalm'),
              );
          final expected = byDate[dateRule]!;
          final actualPairs = psalms.map((psalm) {
            final normalizedReference =
                ResponsorialPsalmSourcePackService.normalizePackReference(
                  psalm.reading,
                );
            return (
              normalizedReference,
              ResponsorialPsalmTextCatalogService.normalizeWords(
                psalm.psalmResponse ?? '',
              ),
            );
          }).toList();
          final missing = expected.where(
            (entry) => !actualPairs.contains((
              entry.referenceNormalized,
              ResponsorialPsalmTextCatalogService.normalizeWords(
                entry.responseText,
              ),
            )),
          );
          if (missing.isNotEmpty) {
            mismatches.add(
              '$dateRule actual=${psalms.map((p) => '${p.reading} | ${p.psalmResponse}').join(' || ')} '
              'official=${expected.map((e) => '${e.referenceDisplay} | ${e.responseText}').join(' || ')}',
            );
          }
        }

        expect(mismatches, isEmpty, reason: mismatches.take(40).join('\n'));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'Week 20 Year II preserves the Nigerian canticles and responses',
      () async {
        final expectations = <DateTime, (String, String)>{
          DateTime(2026, 8, 17): (
            'Dt 32:18-19, 20, 21',
            'You forgot God who gave you birth.',
          ),
          DateTime(2026, 8, 18): (
            'Dt 32:26-27ab, 27cd-28, 30, 35cd-36ab',
            'I kill and I make alive.',
          ),
          DateTime(2026, 8, 19): (
            'Ps 23:1-3a, 3b-4, 5, 6',
            'The Lord is my shepherd; there is nothing I shall want.',
          ),
          DateTime(2026, 8, 20): (
            'Ps 51:12-13, 14-15, 18-19',
            'I will sprinkle clean water on you, and you shall be clean from all your uncleannesses.',
          ),
          DateTime(2026, 8, 21): (
            'Ps 107:2-3, 4-5, 6-7, 8-9',
            'O give thanks to the Lord for he is good; for his mercy endures forever!',
          ),
        };

        for (final entry in expectations.entries) {
          final readings = await CsvReadingsResolverService.instance.resolve(
            entry.key,
          );
          final psalm = readings.singleWhere(
            (reading) => reading.position == 'Responsorial Psalm',
          );
          expect(
            psalm.reading,
            entry.value.$1,
            reason: entry.key.toIso8601String(),
          );
          expect(
            psalm.psalmResponse,
            entry.value.$2,
            reason: entry.key.toIso8601String(),
          );
        }
      },
    );

    test('proper and memorial psalm overlays preserve precedence', () async {
      final expectations = <DateTime, (String, String)>{
        DateTime(2025, 12, 28): (
          'Ps 128:1-2, 3, 4-5',
          'Blessed are all who fear the Lord, and walk in his ways.',
        ),
        DateTime(2026, 1, 11): (
          'Ps 29:1a, 2, 3ac-4, 3b, 9c-10',
          'The Lord will bless his people with peace.',
        ),
        DateTime(2026, 6, 13): (
          'Ps 16:1-2a, 5, 7-8, 9-10',
          'It is you, O Lord, who are my portion.',
        ),
        DateTime(2026, 8, 29): (
          'Ps 71:1-6, 15, 17',
          "Since my mother's womb, you have been my strength.",
        ),
        DateTime(2026, 11, 2): (
          'Ps 23:1-3, 4, 5, 6',
          'The Lord is my shepherd, there is nothing I shall want.',
        ),
      };
      for (final entry in expectations.entries) {
        final psalm = (await CsvReadingsResolverService.instance.resolve(
          entry.key,
        )).singleWhere((reading) => reading.position == 'Responsorial Psalm');
        expect(psalm.reading, entry.value.$1);
        expect(psalm.psalmResponse, entry.value.$2);
      }
    });

    test('different Mass forms remain separate and proper-first', () async {
      final holyThursday = await CsvReadingsResolverService.instance.resolve(
        DateTime(2026, 4, 2),
      );
      final holyThursdayPsalms = holyThursday
          .where(
            (reading) =>
                (reading.position ?? '').startsWith('Responsorial Psalm'),
          )
          .toList();
      expect(holyThursdayPsalms, hasLength(1));
      expect(holyThursdayPsalms.first.reading, 'Ps 116:12-13, 15, 16bc, 17-18');
      expect(
        holyThursdayPsalms.first.psalmResponse,
        'The cup of blessing is a participation in the blood of Christ.',
      );
      final holyThursdayAlternates = await CsvReadingsResolverService.instance
          .resolveOtherMassChoices(
            date: DateTime(2026, 4, 2),
            celebrationTitle:
                "Holy Thursday - Evening Mass of the Lord's Supper",
          );
      expect(holyThursdayAlternates, hasLength(1));
      final chrismPsalm = holyThursdayAlternates.single.readings.singleWhere(
        (reading) => reading.position == 'Responsorial Psalm',
      );
      expect(chrismPsalm.reading, 'Ps 89:21-22, 25, 27');
      expect(
        chrismPsalm.psalmResponse,
        'I will sing forever of your mercies, O Lord.',
      );

      final assumptionEve = await CsvReadingsResolverService.instance.resolve(
        DateTime(2026, 8, 14),
      );
      final assumptionEvePsalms = assumptionEve
          .where(
            (reading) =>
                (reading.position ?? '').startsWith('Responsorial Psalm'),
          )
          .toList();
      expect(assumptionEvePsalms.length, greaterThanOrEqualTo(1));
      expect(assumptionEvePsalms.first.reading, 'Ps 116:10-19');
      final assumptionVigil = await CsvReadingsResolverService.instance
          .resolveVigilChoice(
            date: DateTime(2026, 8, 14),
            celebrationTitle: 'The Assumption of the Blessed Virgin Mary',
          );
      final vigilPsalm = assumptionVigil.singleWhere(
        (reading) => reading.position == 'Responsorial Psalm',
      );
      expect(vigilPsalm.reading, 'Ps 132:6-7, 9-10, 13-14');

      final displayedChoices = await AlternateReadingsService.instance
          .getAvailableReadingSets(DateTime(2026, 8, 14));
      final displayedPsalms = displayedChoices
          .map(
            (set) => set.readings.where(
              (reading) => reading.position == 'Responsorial Psalm',
            ),
          )
          .where((psalms) => psalms.isNotEmpty)
          .map((psalms) => psalms.first.reading)
          .toList();
      expect(displayedPsalms.first, 'Ps 116:10-19');
      expect(displayedPsalms, contains('Isa 12:2-3, 4bcde, 5-6'));
      expect(displayedPsalms, contains('Ps 132:6-7, 9-10, 13-14'));
    });

    test('contentious Nigeria days resolve proper readings', () async {
      await _expectReadingRefs(DateTime(2026, 1, 20), {
        'First Reading': 'Phil 2:1-11',
        'Responsorial Psalm': 'Isa 12:2-3, 4bcde, 5-6',
        'Gospel': 'Matt 13:44-46',
      }, feast: 'Blessed Cyprian Michael Iwene Tansi, Priest');

      await _expectReadingRefs(DateTime(2026, 3, 17), {
        'First Reading': '1 Pet 4:7b-11',
        'Responsorial Psalm': 'Ps 96:1-2a, 2b-3, 7-8a, 9-10ac',
        'Gospel': 'Luke 5:1-11',
      }, feast: 'Saint Patrick, Bishop');

      await _expectReadingRefs(DateTime(2026, 4, 30), {
        'First Reading': 'Acts 1:12-14',
        'Responsorial Psalm': 'Luke 1:46-47, 48-49, 50-51, 52-53, 54-55',
        'Gospel': 'John 2:1-11',
      }, feast: 'Our Lady Mother of Africa');

      await _expectReadingRefs(DateTime(2026, 5, 14), {
        'First Reading': 'Acts 1:1-11',
        'Responsorial Psalm': 'Ps 47:2-3, 6-7, 8-9',
        'Second Reading': 'Eph 1:17-23',
        'Gospel': 'Matt 28:16-20',
      }, feast: 'The Ascension of the Lord');

      await _expectReadingRefs(DateTime(2026, 6, 7), {
        'First Reading': 'Deut 8:2-3, 14b-16a',
        'Responsorial Psalm': 'Ps 147:12-13, 14-15, 19-20',
        'Second Reading': '1 Cor 10:16-17',
        'Gospel': 'John 6:51-58',
      }, feast: 'The Most Holy Body and Blood of Christ');

      await _expectReadingRefs(DateTime(2026, 10, 1), {
        'First Reading': 'Isa 11:1-10',
        'Responsorial Psalm': 'Ps 72:1-2, 7-8, 12-13, 17',
        'Second Reading': 'Eph 2:13-22',
        'Gospel': 'Matt 2:13-15, 19-23',
      }, feast: 'Our Lady, Queen of Nigeria');

      await _expectReadingRefs(DateTime(2026, 11, 22), {
        'First Reading': 'Ezek 34:11-12, 15-17',
        'Responsorial Psalm': 'Ps 23:1, 2a, 2b, 3, 5, 6',
        'Second Reading': '1 Cor 15:20-26, 28',
        'Gospel': 'Matt 25:31-46',
      }, feast: 'Our Lord Jesus Christ, King of the Universe');
    });

    test(
      'seeded 20-date Nigeria sample resolves complete reading sets',
      () async {
        final dates = _seededDatesIn2026(count: 20, seed: 14102026);

        for (final date in dates) {
          final readings = await CsvReadingsResolverService.instance.resolve(
            date,
          );
          _expectCompleteReadingSet(readings, reason: date.toIso8601String());
        }
      },
    );

    test(
      'representative 2026 solemnities and feasts resolve complete readings',
      () async {
        final dates = <DateTime>[
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 4),
          DateTime(2026, 2, 2),
          DateTime(2026, 2, 18),
          DateTime(2026, 3, 19),
          DateTime(2026, 4, 5),
          DateTime(2026, 4, 30),
          DateTime(2026, 5, 14),
          DateTime(2026, 5, 24),
          DateTime(2026, 5, 31),
          DateTime(2026, 6, 7),
          DateTime(2026, 6, 12),
          DateTime(2026, 6, 24),
          DateTime(2026, 6, 29),
          DateTime(2026, 8, 6),
          DateTime(2026, 8, 15),
          DateTime(2026, 9, 14),
          DateTime(2026, 10, 1),
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 22),
          DateTime(2026, 12, 8),
          DateTime(2026, 12, 25),
        ];

        for (final date in dates) {
          final readings = await CsvReadingsResolverService.instance.resolve(
            date,
          );
          _expectCompleteReadingSet(readings, reason: date.toIso8601String());
        }
      },
    );
  });
}

String _isoDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Future<void> _expectReadingRefs(
  DateTime date,
  Map<String, String> expected, {
  required String feast,
}) async {
  final readings = await CsvReadingsResolverService.instance.resolve(date);
  _expectCompleteReadingSet(readings, reason: date.toIso8601String());

  for (final entry in expected.entries) {
    final reading = readings.firstWhere((r) => r.position == entry.key);
    expect(reading.reading, entry.value);
    expect(reading.feast, feast);
  }
}

void _expectCompleteReadingSet(
  List<DailyReading> readings, {
  required String reason,
}) {
  expect(readings, isNotEmpty, reason: reason);
  expect(
    readings.any((r) => r.position == 'First Reading'),
    isTrue,
    reason: reason,
  );
  expect(
    readings.any((r) => r.position == 'Responsorial Psalm'),
    isTrue,
    reason: reason,
  );
  expect(readings.any((r) => r.position == 'Gospel'), isTrue, reason: reason);
  expect(
    readings.every((r) => r.reading.trim().isNotEmpty),
    isTrue,
    reason: reason,
  );
}

List<DateTime> _seededDatesIn2026({required int count, required int seed}) {
  final random = Random(seed);
  final selected = <int>{};
  while (selected.length < count) {
    final offset = random.nextInt(365);
    final date = DateTime(2026, 1, 1).add(Duration(days: offset));
    if (date == DateTime(2026, 4, 4)) continue;
    selected.add(offset);
  }
  return selected
      .map((offset) => DateTime(2026, 1, 1).add(Duration(days: offset)))
      .toList()
    ..sort();
}
