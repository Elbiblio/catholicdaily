import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  final lookup = OfflineOrdoLookupService.instance;

  test('country codes map to the supported liturgical regions', () {
    expect(LiturgicalRegion.fromCountryCode('NG'), LiturgicalRegion.nigeria);
    expect(LiturgicalRegion.fromCountryCode('BR'), LiturgicalRegion.brazil);
    expect(LiturgicalRegion.fromCountryCode('MX'), LiturgicalRegion.mexico);
    expect(
      LiturgicalRegion.fromCountryCode('US'),
      LiturgicalRegion.unitedStates,
    );
    expect(
      LiturgicalRegion.fromCountryCode('GB'),
      LiturgicalRegion.englandWales,
    );
    expect(
      LiturgicalRegion.fromCountryCode('FR'),
      LiturgicalRegion.generalRoman,
    );
  });

  test(
    'Epiphany is fixed in the General Calendar and transferred in the US',
    () {
      final generalJan6 = lookup.resolve(
        DateTime(2026, 1, 6),
        region: LiturgicalRegion.generalRoman,
      );
      expect(generalJan6.title, 'The Epiphany of the Lord');
      expect(generalJan6.rank, 'Solemnity');

      final usJan4 = lookup.resolve(
        DateTime(2026, 1, 4),
        region: LiturgicalRegion.unitedStates,
      );
      expect(usJan4.title, 'The Epiphany of the Lord');
      expect(usJan4.rank, 'Solemnity');

      final usJan6 = lookup.resolve(
        DateTime(2026, 1, 6),
        region: LiturgicalRegion.unitedStates,
      );
      expect(usJan6.title, isNot('The Epiphany of the Lord'));
    },
  );

  test('Ascension follows Thursday or Sunday according to region', () {
    final usMay14 = lookup.resolve(
      DateTime(2026, 5, 14),
      region: LiturgicalRegion.unitedStates,
    );
    expect(usMay14.title, 'Saint Matthias, Apostle');

    final usMay17 = lookup.resolve(
      DateTime(2026, 5, 17),
      region: LiturgicalRegion.unitedStates,
    );
    expect(usMay17.title, 'The Ascension of the Lord');

    final usThursdayProvinceMay14 = lookup.resolve(
      DateTime(2026, 5, 14),
      region: LiturgicalRegion.unitedStatesAscensionThursday,
    );
    expect(usThursdayProvinceMay14.title, 'The Ascension of the Lord');

    final englandWalesMay14 = lookup.resolve(
      DateTime(2026, 5, 14),
      region: LiturgicalRegion.englandWales,
    );
    expect(englandWalesMay14.title, 'The Ascension of the Lord');
  });

  test('Body and Blood of Christ follows Thursday or Sunday by region', () {
    final generalJun4 = lookup.resolve(
      DateTime(2026, 6, 4),
      region: LiturgicalRegion.generalRoman,
    );
    expect(generalJun4.title, 'The Most Holy Body and Blood of Christ');

    final usJun7 = lookup.resolve(
      DateTime(2026, 6, 7),
      region: LiturgicalRegion.unitedStates,
    );
    expect(usJun7.title, 'The Most Holy Body and Blood of Christ');

    final englandWalesJun7 = lookup.resolve(
      DateTime(2026, 6, 7),
      region: LiturgicalRegion.englandWales,
    );
    expect(englandWalesJun7.title, 'The Most Holy Body and Blood of Christ');
  });

  test('England and Wales transfer Saturday Assumption in 2026', () {
    final englandWalesAug15 = lookup.resolve(
      DateTime(2026, 8, 15),
      region: LiturgicalRegion.englandWales,
    );
    expect(
      englandWalesAug15.title,
      isNot('The Assumption of the Blessed Virgin Mary'),
    );

    final englandWalesAug16 = lookup.resolve(
      DateTime(2026, 8, 16),
      region: LiturgicalRegion.englandWales,
    );
    expect(
      englandWalesAug16.title,
      'The Assumption of the Blessed Virgin Mary',
    );

    final nigeriaAug15 = lookup.resolve(
      DateTime(2026, 8, 15),
      region: LiturgicalRegion.nigeria,
    );
    expect(nigeriaAug15.title, 'The Assumption of the Blessed Virgin Mary');
  });

  test('Brazil follows its 2026 national liturgical calendar', () {
    final jan4 = lookup.resolve(
      DateTime(2026, 1, 4),
      region: LiturgicalRegion.brazil,
    );
    expect(jan4.title, 'The Epiphany of the Lord');

    final jan6 = lookup.resolve(
      DateTime(2026, 1, 6),
      region: LiturgicalRegion.brazil,
    );
    expect(jan6.title, isNot('The Epiphany of the Lord'));

    final may14 = lookup.resolve(
      DateTime(2026, 5, 14),
      region: LiturgicalRegion.brazil,
    );
    expect(may14.title, 'Saint Matthias, Apostle');

    final may17 = lookup.resolve(
      DateTime(2026, 5, 17),
      region: LiturgicalRegion.brazil,
    );
    expect(may17.title, 'The Ascension of the Lord');

    final jun4 = lookup.resolve(
      DateTime(2026, 6, 4),
      region: LiturgicalRegion.brazil,
    );
    expect(jun4.title, 'The Most Holy Body and Blood of Christ');

    final jun29 = lookup.resolve(
      DateTime(2026, 6, 29),
      region: LiturgicalRegion.brazil,
    );
    expect(jun29.title, isNot('Saints Peter and Paul, Apostles'));

    final jul5 = lookup.resolve(
      DateTime(2026, 7, 5),
      region: LiturgicalRegion.brazil,
    );
    expect(jul5.title, 'Saints Peter and Paul, Apostles');

    final aug15 = lookup.resolve(
      DateTime(2026, 8, 15),
      region: LiturgicalRegion.brazil,
    );
    expect(aug15.title, isNot('The Assumption of the Blessed Virgin Mary'));

    final aug16 = lookup.resolve(
      DateTime(2026, 8, 16),
      region: LiturgicalRegion.brazil,
    );
    expect(aug16.title, 'The Assumption of the Blessed Virgin Mary');

    final oct12 = lookup.resolve(
      DateTime(2026, 10, 12),
      region: LiturgicalRegion.brazil,
    );
    expect(oct12.title, 'Our Lady of Aparecida');
    expect(oct12.rank, 'Solemnity');
  });

  test('Mexico follows its 2026 national liturgical calendar', () {
    final jan4 = lookup.resolve(
      DateTime(2026, 1, 4),
      region: LiturgicalRegion.mexico,
    );
    expect(jan4.title, 'The Epiphany of the Lord');

    final may17 = lookup.resolve(
      DateTime(2026, 5, 17),
      region: LiturgicalRegion.mexico,
    );
    expect(may17.title, 'The Ascension of the Lord');

    final jun4 = lookup.resolve(
      DateTime(2026, 6, 4),
      region: LiturgicalRegion.mexico,
    );
    expect(jun4.title, 'The Most Holy Body and Blood of Christ');

    final jun29 = lookup.resolve(
      DateTime(2026, 6, 29),
      region: LiturgicalRegion.mexico,
    );
    expect(jun29.title, 'Saints Peter and Paul, Apostles');

    final aug15 = lookup.resolve(
      DateTime(2026, 8, 15),
      region: LiturgicalRegion.mexico,
    );
    expect(aug15.title, 'The Assumption of the Blessed Virgin Mary');

    final dec12 = lookup.resolve(
      DateTime(2026, 12, 12),
      region: LiturgicalRegion.mexico,
    );
    expect(dec12.title, 'Our Lady of Guadalupe');
    expect(dec12.rank, 'Solemnity');
  });

  test(
    'Brazil local solemnity resolves proper readings for incipits',
    () async {
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(LiturgicalRegion.brazil);

      final readings = await CsvReadingsResolverService.instance.resolve(
        DateTime(2026, 10, 12),
      );

      expect(readings.first.reading, 'Esth 5:1b-2; 7:2b-3');
      expect(
        readings.any((r) => r.reading == 'Rev 12:1, 5, 13a, 15-16a'),
        isTrue,
      );
      expect(readings.any((r) => r.reading == 'John 2:1-11'), isTrue);
      expect(readings.every((r) => r.feast == 'Our Lady of Aparecida'), isTrue);
    },
  );

  test(
    'Mexico local solemnity resolves proper readings for incipits',
    () async {
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(LiturgicalRegion.mexico);

      final readings = await CsvReadingsResolverService.instance.resolve(
        DateTime(2026, 12, 12),
      );

      expect(readings.first.reading, 'Rev 11:19a; 12:1-6a, 10ab');
      expect(readings.any((r) => r.reading == 'Jdt 13:18bcde, 19'), isTrue);
      expect(readings.any((r) => r.reading == 'Luke 1:39-47'), isTrue);
      expect(readings.any((r) => r.reading == 'Luke 1:26-38'), isTrue);
      expect(readings.every((r) => r.feast == 'Our Lady of Guadalupe'), isTrue);
    },
  );
}
