import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/demo_launch_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoLaunchConfig', () {
    test('parses a Mass screen demo launch target', () {
      final config = DemoLaunchConfig.parse(
        screen: 'mass',
        date: '2026-10-01',
        regionCode: 'NG',
        bibleVersionId: 'rsvce',
      );

      expect(config.enabled, isTrue);
      expect(config.screen, DemoLaunchScreen.mass);
      expect(config.date, DateTime(2026, 10, 1));
      expect(config.region, LiturgicalRegion.nigeria);
      expect(config.bibleVersion, BibleVersionType.rsvce);
    });

    test('is disabled when no screen or date is supplied', () {
      final config = DemoLaunchConfig.parse(
        screen: '',
        date: '',
        regionCode: '',
        bibleVersionId: '',
      );

      expect(config.enabled, isFalse);
      expect(config.screen, DemoLaunchScreen.home);
      expect(config.date, isNull);
    });
  });
}
