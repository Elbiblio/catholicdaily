import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test(
    'Assumption Day is primary and every legitimate set remains available',
    () async {
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(LiturgicalRegion.nigeria);

      final sets = await AlternateReadingsService.instance
          .getAvailableReadingSets(DateTime(2026, 8, 15));

      expect(sets, hasLength(greaterThanOrEqualTo(3)));
      expect(sets.first.label, 'The Assumption of the Blessed Virgin Mary');
      expect(sets.first.isFerial, isFalse);
      expect(regionPrefs.currentRegion, LiturgicalRegion.nigeria);
      expect(
        sets.first.readings
            .firstWhere(
              (reading) =>
                  (reading.position ?? '').startsWith('Responsorial Psalm'),
            )
            .source,
        startsWith('nigeria_usage:'),
      );
      expect(
        sets.first.readings.map((reading) => reading.reading),
        orderedEquals(<String>[
          'Rev 11:19a; 12:1-6a, 10ab',
          'Ps 45:10, 11, 12, 16',
          '1 Cor 15:20-27',
          'Luke 1:39-56',
        ]),
      );

      expect(sets[1].label, contains('Vigil'));
      expect(
        sets[1].readings.map((reading) => reading.reading),
        orderedEquals(<String>[
          '1 Chr 15:3-4, 15-16; 16:1-2',
          'Ps 132:6-7, 9-10, 13-14',
          '1 Cor 15:54b-57',
          'Luke 11:27-28',
        ]),
      );

      expect(sets.skip(1).any((set) => set.isFerial), isTrue);
    },
  );

  test('transferred Assumption keeps its proper set first', () async {
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.englandWales);

    final sets = await AlternateReadingsService.instance
        .getAvailableReadingSets(DateTime(2026, 8, 16));

    expect(sets.first.label, 'The Assumption of the Blessed Virgin Mary');
    expect(sets.first.isFerial, isFalse);
    expect(
      sets.first.readings.map((reading) => reading.reading),
      containsAllInOrder(<String>[
        'Rev 11:19a; 12:1-6a, 10ab',
        'Ps 45:10, 11, 12, 16',
        '1 Cor 15:20-27',
        'Luke 1:39-56',
      ]),
    );
  });

  test('apostle feast stays first and weekday remains available', () async {
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.nigeria);

    final sets = await AlternateReadingsService.instance
        .getAvailableReadingSets(DateTime(2026, 4, 25));

    expect(sets.first.label, 'Saint Mark, Evangelist');
    expect(sets.first.isFerial, isFalse);
    expect(sets.first.readings.first.reading, '1 Pet 5:5b-14');
    expect(sets.first.readings.last.reading, 'Mark 16:15-20');
    expect(sets.skip(1).any((set) => set.isFerial), isTrue);
  });

  test('Pentecost exposes every cycle-specific authorized option', () async {
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.nigeria);
    final fixtures = <DateTime, List<String>>{
      DateTime(2025, 6, 8): <String>[
        'Rom 8:8-17',
        '1 Cor 12:3b-7, 12-13',
        'Gal 5:16-25',
        'John 14:15-16, 23b-26',
        'John 20:19-23',
        'John 15:26-27; 16:12-15',
      ],
      DateTime(2026, 5, 24): <String>[
        '1 Cor 12:3b-7, 12-13',
        'Gal 5:16-25',
        'Rom 8:8-17',
        'John 20:19-23',
        'John 15:26-27; 16:12-15',
        'John 14:15-16, 23b-26',
      ],
      DateTime(2027, 5, 16): <String>[
        'Gal 5:16-25',
        '1 Cor 12:3b-7, 12-13',
        'Rom 8:8-17',
        'John 15:26-27; 16:12-15',
        'John 20:19-23',
        'John 14:15-16, 23b-26',
      ],
    };

    for (final fixture in fixtures.entries) {
      final sets = await AlternateReadingsService.instance
          .getAvailableReadingSets(fixture.key);
      expect(sets.first.label, 'Pentecost Sunday');
      expect(
        sets.first.readings.map((reading) => reading.reading),
        containsAllInOrder(fixture.value),
      );
    }
  });

  test(
    'Ascension keeps the universal second reading first and all options',
    () async {
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(LiturgicalRegion.nigeria);
      final fixtures = <DateTime, String?>{
        DateTime(2025, 5, 29): 'Heb 9:24-28; 10:19-23',
        DateTime(2026, 5, 14): null,
        DateTime(2027, 5, 6): 'Eph 4:1-13',
      };

      for (final fixture in fixtures.entries) {
        final sets = await AlternateReadingsService.instance
            .getAvailableReadingSets(fixture.key);
        expect(sets.first.label, 'The Ascension of the Lord');
        final secondReadings = sets.first.readings
            .where(
              (reading) =>
                  reading.position?.startsWith('Second Reading') == true,
            )
            .map((reading) => reading.reading)
            .toList();
        expect(secondReadings.first, 'Eph 1:17-23');
        if (fixture.value == null) {
          expect(secondReadings, hasLength(1));
        } else {
          final expected = <String>['Eph 1:17-23', fixture.value!];
          if (fixture.key.year == 2027) {
            expected.add('Eph 4:1-7, 11-13');
          }
          expect(secondReadings, orderedEquals(expected));
        }
      }
    },
  );

  test(
    'Nigeria feast stays first while weekday and same-date memorials remain available',
    () async {
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(LiturgicalRegion.nigeria);

      final sets = await AlternateReadingsService.instance
          .getAvailableReadingSets(DateTime(2026, 1, 20));

      expect(sets.first.label, 'Blessed Cyprian Michael Iwene Tansi, Priest');
      expect(sets.first.isFerial, isFalse);
      expect(sets.map((set) => set.label), contains('Tuesday — Weekday'));
      expect(
        sets.map((set) => set.label),
        contains('Saint Fabian, Pope and Martyr (weekday readings)'),
      );
      expect(
        sets.map((set) => set.label),
        contains('Saint Sebastian, Martyr (weekday readings)'),
      );
    },
  );

  test('Christmas exposes Day, Vigil, Night, and Dawn in that order', () async {
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.nigeria);

    final sets = await AlternateReadingsService.instance
        .getAvailableReadingSets(DateTime(2026, 12, 25));

    expect(sets[0].label, 'The Nativity of the Lord');
    expect(sets[0].readings.first.reading, 'Isa 52:7-10');
    expect(sets[1].label, contains('Vigil Mass'));
    expect(sets[1].readings.first.reading, 'Isa 62:1-5');
    expect(sets[2].label, contains('Mass during the Night'));
    expect(sets[2].readings.first.reading, 'Isa 9:1-6');
    expect(
      sets[2].readings
          .firstWhere(
            (reading) =>
                (reading.position ?? '').startsWith('Responsorial Psalm'),
          )
          .source,
      startsWith('nigeria_usage:'),
    );
    expect(sets[3].label, contains('Mass at Dawn'));
    expect(sets[3].readings.first.reading, 'Isa 62:11-12');
    expect(
      sets[3].readings
          .firstWhere(
            (reading) =>
                (reading.position ?? '').startsWith('Responsorial Psalm'),
          )
          .source,
      startsWith('nigeria_usage:'),
    );
  });

  test('proper vigils remain available after their feast-day set', () async {
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.nigeria);
    final fixtures = <DateTime, String>{
      DateTime(2026, 5, 24): 'Gen 11:1-9',
      DateTime(2026, 6, 24): 'Jer 1:4-10',
      DateTime(2026, 6, 29): 'Acts 3:1-10',
    };

    for (final fixture in fixtures.entries) {
      final sets = await AlternateReadingsService.instance
          .getAvailableReadingSets(fixture.key);
      expect(sets.first.label, isNot(contains('Vigil')));
      final vigil = sets.firstWhere((set) => set.label.contains('Vigil'));
      expect(vigil.readings.first.reading, fixture.value);
    }
  });
}
