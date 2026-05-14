// Regression guard for May 14, 2026.
//
// In calendars that keep Ascension on Thursday, this date is the Solemnity of
// the Ascension of the Lord. It also collides with the fixed-date Feast of
// Saint Matthias, Apostle. The solemnity must win for reminders and readings.

import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
import 'package:catholic_daily/data/services/ordo_resolver_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test('May 14 2026 resolves to Ascension, not Saint Matthias', () async {
    final dt = DateTime(2026, 5, 14);
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.nigeria);

    final offline = OfflineOrdoLookupService.instance.resolve(
      dt,
      region: LiturgicalRegion.nigeria,
    );
    expect(offline.title, 'The Ascension of the Lord');
    expect(offline.rank, 'Solemnity');

    final resolved = await OrdoResolverService.instance.resolveDay(dt);
    expect(resolved.title, 'The Ascension of the Lord');
    expect(resolved.rank, 'Solemnity');
  });

  test('May 14 2026 readings use Ascension propers', () async {
    final dt = DateTime(2026, 5, 14);
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.nigeria);
    final readings = await CsvReadingsResolverService.instance.resolve(dt);

    final first = readings.firstWhere((r) => r.position == 'First Reading');
    final psalm = readings.firstWhere(
      (r) => r.position == 'Responsorial Psalm',
    );
    final second = readings.firstWhere((r) => r.position == 'Second Reading');
    final gospel = readings.firstWhere((r) => r.position == 'Gospel');

    expect(first.reading, 'Acts 1:1-11');
    expect(psalm.reading, 'Ps 47:2-3, 6-7, 8-9');
    expect(second.reading, 'Eph 1:17-23');
    expect(gospel.reading, 'Matt 28:16-20');
    expect(readings.any((r) => (r.feast ?? '').contains('Matthias')), isFalse);
  });

  test('US most dioceses transfer Ascension to Sunday in 2026', () async {
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    await regionPrefs.setRegion(LiturgicalRegion.unitedStates);

    final may14 = OfflineOrdoLookupService.instance.resolve(
      DateTime(2026, 5, 14),
      region: LiturgicalRegion.unitedStates,
    );
    expect(may14.title, 'Saint Matthias, Apostle');

    final may17 = await OrdoResolverService.instance.resolveDay(
      DateTime(2026, 5, 17),
    );
    expect(may17.title, 'The Ascension of the Lord');
    expect(may17.rank, 'Solemnity');
  });
}
