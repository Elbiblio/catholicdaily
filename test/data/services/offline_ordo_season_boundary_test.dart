import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Christmas season spans the year and ends after the Baptism', () {
    final resolver = OfflineOrdoLookupService.instance;
    final cases = <(DateTime, LiturgicalRegion, LiturgicalSeason)>[
      (
        DateTime(2026, 12, 24),
        LiturgicalRegion.nigeria,
        LiturgicalSeason.advent,
      ),
      (
        DateTime(2026, 12, 25),
        LiturgicalRegion.nigeria,
        LiturgicalSeason.christmas,
      ),
      (
        DateTime(2026, 12, 31),
        LiturgicalRegion.nigeria,
        LiturgicalSeason.christmas,
      ),
      (
        DateTime(2027, 1, 1),
        LiturgicalRegion.nigeria,
        LiturgicalSeason.christmas,
      ),
      (
        DateTime(2027, 1, 10),
        LiturgicalRegion.nigeria,
        LiturgicalSeason.christmas,
      ),
      (
        DateTime(2027, 1, 11),
        LiturgicalRegion.nigeria,
        LiturgicalSeason.ordinaryTime,
      ),
      (
        DateTime(2023, 1, 9),
        LiturgicalRegion.unitedStates,
        LiturgicalSeason.christmas,
      ),
      (
        DateTime(2023, 1, 10),
        LiturgicalRegion.unitedStates,
        LiturgicalSeason.ordinaryTime,
      ),
    ];
    for (final (date, region, expected) in cases) {
      final day = resolver.resolve(date, region: region);
      expect(day.season, expected, reason: '$date ${region.code} ${day.title}');
    }
  });
}
