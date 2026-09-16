import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LiturgicalRegionPreferenceService.resetInstanceForTesting();
  });

  test('persists the supplied locale region when no region exists', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = LiturgicalRegionPreferenceService.forTesting(
      prefs,
      localeRegion: () => LiturgicalRegion.nigeria,
    );

    expect(await service.detectAndSetIfUnset(), LiturgicalRegion.nigeria);
    expect(service.currentRegion, LiturgicalRegion.nigeria);
  });

  test(
    'keeps an existing region instead of replacing it with the locale',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'liturgical_region': 'US',
      });
      LiturgicalRegionPreferenceService.resetInstanceForTesting();
      final prefs = await SharedPreferences.getInstance();
      final service = LiturgicalRegionPreferenceService.forTesting(
        prefs,
        localeRegion: () => LiturgicalRegion.nigeria,
      );

      expect(
        await service.detectAndSetIfUnset(),
        LiturgicalRegion.unitedStates,
      );
    },
  );
}
