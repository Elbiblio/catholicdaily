import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/order_of_mass_service.dart';
import 'package:catholic_daily/data/services/prayer_service.dart';

import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  mockMethodChannels();
  SharedPreferences.setMockInitialValues({});

  group('OrderOfMassService', () {
    test('loads and resolves configured sections', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();

      final service = OrderOfMassService();
      final sections = await service.getSectionsForDate(DateTime(2026, 1, 11));

      expect(sections, isNotEmpty);
      expect(
        sections.any((section) => section.insertionPoint == 'introductory_rites'),
        isTrue,
      );
      expect(
        sections.any((section) => section.insertionPoint == 'after_gospel'),
        isTrue,
      );

      final introductory = sections.firstWhere(
        (section) => section.insertionPoint == 'introductory_rites',
      );
      expect(
        introductory.items.any((item) => item.id == 'sign_of_the_cross'),
        isTrue,
      );
    });

    test('filters Sunday-only items on weekdays', () async {
      final service = OrderOfMassService();
      final sections = await service.getSectionsForDate(DateTime(2026, 1, 12));

      final afterGospel =
          sections.where((section) => section.insertionPoint == 'after_gospel');
      if (afterGospel.isEmpty) {
        expect(afterGospel, isEmpty);
        return;
      }

      expect(
        afterGospel.every(
          (section) => section.items.every((item) => item.id != 'creed'),
        ),
        isTrue,
      );
    });

    test('substitutes Gospel dialogue [N] when lectionary readings are provided',
        () async {
      final service = OrderOfMassService();
      final readings = [
        DailyReading(
          reading: 'Matt 4:1-11',
          position: 'Gospel',
          date: DateTime(2026, 1, 12),
        ),
      ];
      final sections = await service.getSectionsForDate(
        DateTime(2026, 1, 12),
        lectionaryReadings: readings,
      );
      final beforeGospel = sections.where((s) => s.insertionPoint == 'before_gospel');
      expect(beforeGospel, isNotEmpty);
      final gospelIntro = beforeGospel.first.items.where((i) => i.id == 'gospel');
      expect(gospelIntro, isNotEmpty);
      final en = gospelIntro.first.getContentForLanguage('en');
      expect(en, isNotNull);
      expect(
        en!.any((line) => line.contains('Matthew') && !line.contains('[N]')),
        isTrue,
      );
    });
  });
}
