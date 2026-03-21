import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/data/services/prayer_service.dart';

void main() {
  group('HTML Loading Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('Should load apostles_creed.html', () async {
      try {
        final content = await rootBundle.loadString('assets/prayers/apostles_creed.html');
        expect(content, isNotNull);
        expect(content.contains('<HTML>'), isTrue);
        expect(content.contains('I believe in God'), isTrue);
        print('✓ apostles_creed.html loaded successfully');
      } catch (e) {
        fail('Failed to load apostles_creed.html: $e');
      }
    });

    test('Should load hail_mary.html', () async {
      try {
        final content = await rootBundle.loadString('assets/prayers/hail_mary.html');
        expect(content, isNotNull);
        expect(content.contains('<HTML>'), isTrue);
        expect(content.contains('Hail, Mary'), isTrue);
        print('✓ hail_mary.html loaded successfully');
      } catch (e) {
        fail('Failed to load hail_mary.html: $e');
      }
    });

    test('Should load angelus.html', () async {
      try {
        final content = await rootBundle.loadString('assets/prayers/angelus.html');
        expect(content, isNotNull);
        expect(content.contains('<HTML>'), isTrue);
        expect(content.contains('Angel of the LORD'), isTrue);
        print('✓ angelus.html loaded successfully');
      } catch (e) {
        fail('Failed to load angelus.html: $e');
      }
    });

    test('Should load prayers with HTML content', () async {
      try {
        final prayerService = PrayerService();
        await prayerService.initialize();
        
        final apostlesCreed = prayerService.findPrayerBySlug('apostles_creed');
        expect(apostlesCreed, isNotNull);
        expect(apostlesCreed!.htmlContent, isNotNull);
        expect(apostlesCreed.htmlContent!.contains('<HTML>'), isTrue);
        expect(apostlesCreed.htmlContent!.contains('I believe in God'), isTrue);
        print('✓ Apostles Creed loaded with HTML content');
        
        final hailMary = prayerService.findPrayerBySlug('hail_mary');
        expect(hailMary, isNotNull);
        expect(hailMary!.htmlContent, isNotNull);
        expect(hailMary.htmlContent!.contains('<HTML>'), isTrue);
        expect(hailMary.htmlContent!.contains('Hail, Mary'), isTrue);
        print('✓ Hail Mary loaded with HTML content');
      } catch (e) {
        print('Error in prayer loading test: $e');
        rethrow;
      }
    });
  });
}
