import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/data/models/prayer.dart';
import '../lib/data/services/prayer_service.dart';

void main() {
  group('Prayer Implementation Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('Prayer model should support HTML content', () {
      final prayer = Prayer(
        id: 1,
        slug: 'test_prayer',
        title: 'Test Prayer',
        firstLine: 'Test first line',
        category: 'test',
        text: ['Line 1', 'Line 2'],
        htmlContent: '<p><strong>HTML Prayer</strong></p>',
      );

      expect(prayer.htmlContent, '<p><strong>HTML Prayer</strong></p>');
      expect(prayer.displayText, 'Line 1\n\nLine 2');
    });

    test('Prayer should copy with HTML content', () {
      final prayer = Prayer(
        id: 1,
        slug: 'test_prayer',
        title: 'Test Prayer',
        firstLine: 'Test first line',
        category: 'test',
        text: ['Line 1', 'Line 2'],
      );

      final prayerWithHtml = prayer.copyWith(htmlContent: '<p>HTML Content</p>');

      expect(prayerWithHtml.htmlContent, '<p>HTML Content</p>');
      expect(prayerWithHtml.title, 'Test Prayer');
    });

    test('Should load prayers with HTML content', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final prayers = prayerService.allPrayers;
      expect(prayers.isNotEmpty, isTrue);

      // Check if some prayers have HTML content
      final prayersWithHtml = prayers.where((p) => p.htmlContent != null && p.htmlContent!.isNotEmpty);
      expect(prayersWithHtml.isNotEmpty, isTrue);

      // Verify specific prayer has HTML content
      final apostlesCreed = prayerService.findPrayerBySlug('apostles_creed');
      expect(apostlesCreed, isNotNull);
      expect(apostlesCreed!.htmlContent, isNotNull);
      expect(apostlesCreed.htmlContent!.contains('<HTML>'), isTrue);
      expect(apostlesCreed.htmlContent!.contains('I believe in God'), isTrue);
    });

    test('Should find prayers by slug', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final hailMary = prayerService.findPrayerBySlug('hail_mary');
      expect(hailMary, isNotNull);
      expect(hailMary!.title, contains('Hail Mary'));
      expect(hailMary.htmlContent, isNotNull);
      expect(hailMary.htmlContent!.contains('Hail, Mary'), isTrue);
    });

    test('Should categorize prayers correctly', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final categorized = prayerService.prayersByCategory;
      expect(categorized.isNotEmpty, isTrue);

      // Check if Rosary category exists
      expect(categorized.containsKey('Rosary'), isTrue);
      final rosaryPrayers = categorized['Rosary']!;
      expect(rosaryPrayers.isNotEmpty, isTrue);

      // Check if Mass & Liturgical category exists
      expect(categorized.containsKey('Mass & Liturgical'), isTrue);
      final massPrayers = categorized['Mass & Liturgical']!;
      expect(massPrayers.isNotEmpty, isTrue);
    });

    test('Should handle bookmarking', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final prayer = prayerService.allPrayers.first;
      expect(await prayerService.isBookmarked(prayer), isFalse);
      
      await prayerService.toggleBookmark(prayer);
      expect(await prayerService.isBookmarked(prayer), isTrue);
      
      await prayerService.toggleBookmark(prayer);
      expect(await prayerService.isBookmarked(prayer), isFalse);
    });

    test('Should track recently used prayers', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final prayer = prayerService.allPrayers.first;
      final initialRecentlyUsed = prayerService.recentlyUsedPrayers.length;
      
      await prayerService.markPrayerAsUsed(prayer);
      
      final updatedRecentlyUsed = prayerService.recentlyUsedPrayers;
      expect(updatedRecentlyUsed.length, greaterThan(initialRecentlyUsed));
      expect(updatedRecentlyUsed.first.slug, prayer.slug);
    });
  });
}
