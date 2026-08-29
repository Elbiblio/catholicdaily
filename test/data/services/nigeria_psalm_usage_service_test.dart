import 'package:catholic_daily/data/models/liturgical_psalm_usage_context.dart';
import 'package:catholic_daily/data/services/nigeria_psalm_usage_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final service = NigeriaPsalmUsageService.fromEntries(const <
    NigeriaPsalmUsageEntry
  >[
    NigeriaPsalmUsageEntry(
      usageId: 'ng:ordinary:20:tuesday:II:1',
      territory: 'NG',
      kind: LiturgicalPsalmUsageKind.temporal,
      season: 'ordinary_time',
      week: 20,
      weekday: DateTime.tuesday,
      weekdayCycle: 'II',
      referenceNormalized: 'deut32:26-27ab,27cd-28,30,35cd-36ab',
      referenceDisplay: 'Dt 32:26-27ab, 27cd-28, 30, 35cd-36ab',
      responseText: 'I kill and I make alive.',
      sourceDate: '2026-08-18',
      sourceSelectionId: 'ng:2026-08-18:responsorial-psalm:1',
      choicePriority: 1,
    ),
    NigeriaPsalmUsageEntry(
      usageId: 'ng:assumption:day:1',
      territory: 'NG',
      kind: LiturgicalPsalmUsageKind.celebration,
      celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
      massForm: 'day',
      referenceNormalized: 'ps45:10,11,12,16',
      referenceDisplay: 'Ps 45:10, 11, 12, 16',
      responseText: 'On your right stands the queen in gold of Ophir.',
      sourceDate: '2026-08-15',
      sourceSelectionId: 'ng:2026-08-15:responsorial-psalm:1',
      choicePriority: 1,
    ),
    NigeriaPsalmUsageEntry(
      usageId: 'ng:assumption:vigil:1',
      territory: 'NG',
      kind: LiturgicalPsalmUsageKind.celebration,
      celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
      massForm: 'vigil',
      referenceNormalized: 'ps132:6-7,9-10,13-14',
      referenceDisplay: 'Ps 132:6-7, 9-10, 13-14',
      responseText:
          'Lord, go up to the place of your rest, you and the ark of your holiness.',
      sourceDate: '2026-08-14',
      sourceSelectionId: 'ng:2026-08-14:responsorial-psalm:2',
      choicePriority: 1,
    ),
    NigeriaPsalmUsageEntry(
      usageId: 'ng:pentecost:day:A:1',
      territory: 'NG',
      kind: LiturgicalPsalmUsageKind.celebration,
      celebrationId: 'pentecost_sunday',
      massForm: 'day',
      sundayCycle: 'A',
      referenceNormalized: 'ps104:1ab,24ac,29bc-30,31,34',
      referenceDisplay: 'Ps 104:1ab, 24ac, 29bc-30, 31, 34',
      responseText:
          'Lord, send forth your Spirit, and renew the face of the earth.',
      sourceDate: '2026-05-24',
      sourceSelectionId: 'ng:2026-05-24:responsorial-psalm:1',
      choicePriority: 1,
    ),
  ]);

  test('temporal usage is independent from its Gregorian source date', () {
    const context = LiturgicalPsalmUsageContext.temporal(
      territory: 'NG',
      season: 'ordinary_time',
      week: 20,
      weekday: DateTime.tuesday,
      weekdayCycle: 'II',
    );

    final choices = service.resolve(context.onDate(DateTime(2028, 8, 15)));

    expect(choices, hasLength(1));
    expect(
      choices.single.referenceNormalized,
      'deut32:26-27ab,27cd-28,30,35cd-36ab',
    );
    expect(choices.single.sourceDate, '2026-08-18');
  });

  test('temporal usage cannot leak into another weekday cycle', () {
    const context = LiturgicalPsalmUsageContext.temporal(
      territory: 'NG',
      season: 'ordinary_time',
      week: 20,
      weekday: DateTime.tuesday,
      weekdayCycle: 'I',
    );

    expect(service.resolve(context), isEmpty);
  });

  test('celebration day and vigil remain separate stable usages', () {
    const day = LiturgicalPsalmUsageContext.celebration(
      territory: 'NG',
      celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
      massForm: 'day',
    );
    const vigil = LiturgicalPsalmUsageContext.celebration(
      territory: 'NG',
      celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
      massForm: 'vigil',
    );

    expect(service.resolve(day).single.referenceNormalized, 'ps45:10,11,12,16');
    expect(
      service.resolve(vigil).single.referenceNormalized,
      'ps132:6-7,9-10,13-14',
    );
  });

  test('cycle-specific celebration usage cannot leak into another cycle', () {
    const yearA = LiturgicalPsalmUsageContext.celebration(
      territory: 'NG',
      celebrationId: 'pentecost_sunday',
      sundayCycle: 'A',
    );
    const yearB = LiturgicalPsalmUsageContext.celebration(
      territory: 'NG',
      celebrationId: 'pentecost_sunday',
      sundayCycle: 'B',
    );

    expect(service.resolve(yearA), hasLength(1));
    expect(service.resolve(yearB), isEmpty);
  });

  test(
    'bundled stable catalog contains every reviewed source choice',
    () async {
      final bundled = await NigeriaPsalmUsageService.load();
      const context = LiturgicalPsalmUsageContext.temporal(
        territory: 'NG',
        season: 'ordinary-time',
        week: 20,
        weekday: DateTime.tuesday,
        weekdayCycle: 'II',
      );

      expect(
        bundled.resolve(context).map((choice) => choice.responseText),
        contains('I kill and I make alive.'),
      );
    },
  );

  test(
    'every bundled source choice resolves through its stable usage key',
    () async {
      final raw = await rootBundle.loadString(
        'assets/data/nigeria_psalm_usages.csv',
      );
      final entries = NigeriaPsalmUsageService.parseCsv(raw);
      final bundled = NigeriaPsalmUsageService.fromEntries(entries);

      expect(entries, hasLength(2536));
      expect(entries.map((entry) => entry.stableKey).toSet(), hasLength(1052));
      expect(
        entries.map((entry) => entry.sourceEdition),
        everyElement(isNotEmpty),
      );
      expect(
        entries.map((entry) => entry.reviewStatus),
        everyElement(anyOf('verified', 'verified-fallback', 'missing-text')),
      );
      for (final entry in entries) {
        final context = switch (entry.kind) {
          LiturgicalPsalmUsageKind.temporal =>
            LiturgicalPsalmUsageContext.temporal(
              territory: entry.territory,
              season: entry.season,
              week: entry.week!,
              weekday: entry.weekday!,
              sundayCycle: entry.sundayCycle,
              weekdayCycle: entry.weekdayCycle,
            ),
          LiturgicalPsalmUsageKind.celebration =>
            LiturgicalPsalmUsageContext.celebration(
              territory: entry.territory,
              celebrationId: entry.celebrationId,
              massForm: entry.massForm,
              sundayCycle: entry.sundayCycle,
              weekdayCycle: entry.weekdayCycle,
            ),
          LiturgicalPsalmUsageKind.specialPeriod =>
            LiturgicalPsalmUsageContext.specialPeriod(
              territory: entry.territory,
              specialDay: entry.specialDay,
              massForm: entry.massForm,
              sundayCycle: entry.sundayCycle,
              weekdayCycle: entry.weekdayCycle,
            ),
        };

        expect(
          bundled.resolve(context).map((choice) => choice.usageId),
          contains(entry.usageId),
          reason: entry.usageId,
        );
      }
    },
  );

  test(
    'bundled catalog resolves historical Sunday cycles and weekday cycle I',
    () async {
      final bundled = await NigeriaPsalmUsageService.load();
      final yearB = bundled.resolve(
        const LiturgicalPsalmUsageContext.temporal(
          territory: 'NG',
          season: 'lent',
          week: 1,
          weekday: DateTime.sunday,
          sundayCycle: 'B',
        ),
      );
      final yearC = bundled.resolve(
        const LiturgicalPsalmUsageContext.temporal(
          territory: 'NG',
          season: 'advent',
          week: 1,
          weekday: DateTime.sunday,
          sundayCycle: 'C',
        ),
      );
      final weekdayI = bundled.resolve(
        const LiturgicalPsalmUsageContext.temporal(
          territory: 'NG',
          season: 'advent',
          week: 1,
          weekday: DateTime.monday,
          weekdayCycle: 'I',
        ),
      );

      expect(
        yearB.map((choice) => choice.referenceNormalized),
        contains('ps25:4-5,6-7,8-9'),
      );
      expect(
        yearC.map((choice) => choice.referenceNormalized),
        contains('ps25:4-5,8-9,10,14'),
      );
      expect(
        weekdayI.map((choice) => choice.referenceNormalized),
        contains('ps122:1-2,3-4b,4cd-5,6-7,8-9'),
      );
    },
  );

  test(
    'cycle-specific choices outrank and deduplicate generic choices',
    () async {
      final bundled = await NigeriaPsalmUsageService.load();
      final choices = bundled.resolve(
        const LiturgicalPsalmUsageContext.celebration(
          territory: 'NG',
          celebrationId: 'baptism_of_the_lord',
          massForm: 'day',
          sundayCycle: 'B',
        ),
      );

      expect(choices, hasLength(3));
      expect(choices.first.referenceNormalized, 'isa12:2-3,4bcd,5-6');
      expect(
        choices.where(
          (choice) =>
              choice.responseText ==
              'You will draw water joyfully from the springs of salvation.',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'Easter Vigil catalog never pairs Psalm 118 with Psalm 16 response',
    () async {
      final bundled = await NigeriaPsalmUsageService.load();
      final choices = bundled.resolve(
        const LiturgicalPsalmUsageContext.specialPeriod(
          territory: 'NG',
          specialDay: 'easter-vigil',
        ),
      );

      expect(choices, isNotEmpty);
      expect(
        choices,
        isNot(
          contains(
            predicate<NigeriaPsalmUsageEntry>(
              (choice) =>
                  choice.referenceNormalized.startsWith('ps118:') &&
                  choice.responseText == 'You are my inheritance, O Lord.',
            ),
          ),
        ),
      );
    },
  );

  test(
    'direct Nigerian evidence outranks reconstructed celebration text',
    () async {
      final bundled = await NigeriaPsalmUsageService.load();
      final choices = bundled.resolve(
        const LiturgicalPsalmUsageContext.celebration(
          territory: 'NG',
          celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
          massForm: 'day',
          sundayCycle: 'B',
        ),
      );

      expect(choices.first.sourceDate, '2026-08-15');
      expect(
        choices.first.responseText,
        'On your right stands the queen in gold of Ophir.',
      );
    },
  );
}
