import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catholic_daily/data/services/order_of_mass_service.dart';
import 'package:catholic_daily/data/services/prayer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('OrderOfMassService', () {
    test('loads and resolves configured sections', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();

      final service = OrderOfMassService();
      final sections = await service.getSectionsForDate(DateTime(2026, 1, 11));

      expect(sections, isNotEmpty);
      expect(
        sections.any((section) => section.insertionPoint == 'before_readings'),
        isTrue,
      );
      expect(
        sections.any((section) => section.insertionPoint == 'after_gospel'),
        isTrue,
      );

      final beforeReadings = sections.firstWhere(
        (section) => section.insertionPoint == 'before_readings',
      );
      expect(beforeReadings.items.any((item) => item.id == 'sign_of_the_cross'), isTrue);
    });

    test('filters sunday-only items on weekdays', () async {
      final service = OrderOfMassService();
      final sections = await service.getSectionsForDate(DateTime(2026, 1, 12));

      final afterGospel = sections.where((section) => section.insertionPoint == 'after_gospel');
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
  });
}
