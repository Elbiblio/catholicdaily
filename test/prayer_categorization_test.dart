import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/data/services/prayer_service.dart';

void main() {
  group('Prayer Categorization Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('Should categorize all 93 prayers correctly', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final allPrayers = prayerService.allPrayers;
      expect(allPrayers.length, 93, reason: 'Should have exactly 93 prayers');
      
      final categories = prayerService.prayersByCategory;
      
      // Check that we have the expected categories
      expect(categories.containsKey('Mass & Liturgical'), isTrue);
      expect(categories.containsKey('Marian'), isTrue);
      expect(categories.containsKey('Lenten'), isTrue);
      expect(categories.containsKey('Commons & Devotional'), isTrue);
      expect(categories.containsKey('Saints & Novenas'), isTrue);
      expect(categories.containsKey('Life Events'), isTrue);
      expect(categories.containsKey('Rosary'), isTrue);
      expect(categories.containsKey('Acts of Faith'), isTrue);
      
      // Verify specific prayers are in correct categories
      final apostlesCreed = prayerService.findPrayerBySlug('apostles_creed');
      expect(apostlesCreed, isNotNull);
      expect(categories['Mass & Liturgical']!.contains(apostlesCreed), isTrue, 
             reason: 'Apostles Creed should be in Mass & Liturgical');
      
      final hailMary = prayerService.findPrayerBySlug('hail_mary');
      expect(hailMary, isNotNull);
      expect(categories['Marian']!.contains(hailMary), isTrue,
             reason: 'Hail Mary should be in Marian');
      
      final stations = prayerService.findPrayerBySlug('stations');
      expect(stations, isNotNull);
      expect(categories['Lenten']!.contains(stations), isTrue,
             reason: 'Stations should be in Lenten');
      
      final actOfCharity = prayerService.findPrayerBySlug('act_of_charity');
      expect(actOfCharity, isNotNull);
      expect(categories['Acts of Faith']!.contains(actOfCharity), isTrue,
             reason: 'Act of Charity should be in Acts of Faith');
      
      // Check Rosary mysteries are grouped correctly
      final joyfulMysteries = categories['Rosary']!.where((p) => p.slug.startsWith('joyful')).toList();
      expect(joyfulMysteries.length, 5, reason: 'Should have 5 Joyful mysteries');
      
      final sorrowfulMysteries = categories['Rosary']!.where((p) => p.slug.startsWith('sorrowful')).toList();
      expect(sorrowfulMysteries.length, 5, reason: 'Should have 5 Sorrowful mysteries');
      
      final gloriousMysteries = categories['Rosary']!.where((p) => p.slug.startsWith('glorious')).toList();
      expect(gloriousMysteries.length, 5, reason: 'Should have 5 Glorious mysteries');
      
      final luminousMysteries = categories['Rosary']!.where((p) => p.slug.startsWith('light')).toList();
      expect(luminousMysteries.length, 5, reason: 'Should have 5 Luminous mysteries');
      
      print('✓ All 93 prayers categorized correctly');
      print('✓ Categories: ${categories.keys.toList()}');
      print('✓ Rosary mysteries: ${joyfulMysteries.length + sorrowfulMysteries.length + gloriousMysteries.length + luminousMysteries.length} total');
    });

    test('Should find prayers by slug correctly', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final testCases = [
        ('apostles_creed', 'Apostles Creed'),
        ('hail_mary', 'Hail Mary'),
        ('angelus', 'Angelus'),
        ('act_of_contrition', 'Act Of Contrition'),
        ('sign_of_the_cross', 'Sign Of The Cross'),
        ('joyful1', 'Joyful1'),
        ('sorrowful1', 'Sorrowful1'),
        ('glorious1', 'Glorious1'),
        ('light1', 'Light1'),
      ];
      
      for (final (slug, expectedTitle) in testCases) {
        final prayer = prayerService.findPrayerBySlug(slug);
        expect(prayer, isNotNull, reason: 'Should find prayer: $slug');
        if (prayer != null) {
          expect(prayer.slug, slug, reason: 'Slug should match');
          expect(prayer.title.contains(expectedTitle) || prayer.title == expectedTitle, isTrue,
                 reason: 'Title should contain expected text for $slug');
        }
      }
      
      print('✓ All test prayers found by slug correctly');
    });

    test('Should have HTML content for copied prayers', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final testPrayers = [
        'apostles_creed',
        'hail_mary',
        'angelus',
        'act_of_charity',
        'act_of_contrition',
        'memorare',
        'glory_be',
      ];
      
      for (final slug in testPrayers) {
        final prayer = prayerService.findPrayerBySlug(slug);
        expect(prayer, isNotNull, reason: 'Should find prayer: $slug');
        if (prayer != null) {
          expect(prayer.htmlContent, isNotNull, reason: 'Should have HTML content for $slug');
          expect(prayer.htmlContent!.isNotEmpty, isTrue, reason: 'HTML content should not be empty for $slug');
          expect(prayer.htmlContent!.contains('<HTML>'), isTrue, reason: 'Should contain HTML tags for $slug');
        }
      }
      
      print('✓ All test prayers have HTML content');
    });

    test('Should handle search correctly', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();
      
      final searchResults = prayerService.searchPrayers('mary');
      expect(searchResults.isNotEmpty, isTrue, reason: 'Should find prayers with "mary"');
      
      for (final prayer in searchResults) {
        expect(
          prayer.title.toLowerCase().contains('mary') ||
          prayer.firstLine.toLowerCase().contains('mary') ||
          prayer.slug.toLowerCase().contains('mary'),
          isTrue,
          reason: 'Search result should contain search term: ${prayer.title}'
        );
      }
      
      print('✓ Search functionality working correctly');
    });
  });
}
