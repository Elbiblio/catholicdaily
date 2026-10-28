import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/ui/screens/hymn_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(cleanup);

  test(
    'hymn context uses the resolved Nigerian celebration and primary set',
    () async {
      final region = await LiturgicalRegionPreferenceService.getInstance();
      await region.setRegion(LiturgicalRegion.nigeria);
      final date = DateTime(2026, 10, 1);
      final context = await resolveDailyHymnContext(date);
      final sets = await AlternateReadingsService.instance
          .getAvailableReadingSets(date);
      expect(context.liturgicalDay.title, contains('Nigeria'));
      expect(
        context.readings.map((r) => r.reading),
        sets.first.readings.map((r) => r.reading),
      );
      expect(
        context.readings.map((r) => r.reading),
        contains('Matt 2:13-15, 19-23'),
      );
    },
  );
}
