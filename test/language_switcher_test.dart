import 'package:flutter_test/flutter_test.dart';
import '../lib/data/models/prayer.dart';
import '../lib/data/services/prayer_content_parser.dart';
import '../lib/data/services/language_preference_service.dart';

void main() {
  group('Prayer Language Switcher Tests', () {
    test('Prayer content parser separates English and Latin correctly', () {
      final prayer = Prayer(
        id: 1,
        slug: 'test_prayer',
        title: 'Test Prayer',
        firstLine: 'This is a test',
        category: 'prayer',
        text: [
          'English line 1',
          'English line 2',
          '',
          'In Latin',
          '',
          'Latin line 1',
          'Latin line 2',
        ],
      );

      final parsedPrayer = PrayerContentParser.parsePrayerContent(prayer);

      expect(parsedPrayer.contentByLanguage, isNotNull);
      expect(parsedPrayer.availableLanguages, contains('en'));
      expect(parsedPrayer.availableLanguages, contains('la'));
      expect(parsedPrayer.getContentForLanguage('en'), contains('English line 1'));
      expect(parsedPrayer.getContentForLanguage('la'), contains('Latin line 1'));
    });

    test('Language preference service handles language switching', () async {
      final service = LanguagePreferenceService();
      
      // Test language constants
      expect(LanguagePreferenceService.english, equals('en'));
      expect(LanguagePreferenceService.latin, equals('la'));
      
      // Test language display names
      expect(service.getLanguageDisplayName('en'), equals('English'));
      expect(service.getLanguageDisplayName('la'), equals('Latin'));
      
      // Test available languages
      expect(service.availableLanguages, contains('en'));
      expect(service.availableLanguages, contains('la'));
      expect(service.availableLanguages.length, greaterThanOrEqualTo(2));
      
      // Test language validation
      expect(service.isValidLanguage('en'), isTrue);
      expect(service.isValidLanguage('la'), isTrue);
      expect(service.isValidLanguage('es'), isTrue);
    });

    test('Prayer model language helper methods work correctly', () {
      final prayer = Prayer(
        id: 1,
        slug: 'test_prayer',
        title: 'Test Prayer',
        firstLine: 'This is a test',
        category: 'prayer',
        text: ['English content'],
        contentByLanguage: {
          'en': ['English line 1', 'English line 2'],
          'la': ['Latin line 1', 'Latin line 2'],
        },
        availableLanguages: ['en', 'la'],
      );

      expect(prayer.hasLanguage('en'), isTrue);
      expect(prayer.hasLanguage('la'), isTrue);
      expect(prayer.hasLanguage('es'), isFalse);

      final englishText = prayer.getDisplayTextForLanguage('en');
      expect(englishText, contains('English line 1'));

      final latinText = prayer.getDisplayTextForLanguage('la');
      expect(latinText, contains('Latin line 1'));

      // Test fallback to original text
      final fallbackText = prayer.getDisplayTextForLanguage('es');
      expect(fallbackText, equals(prayer.displayText));
    });
  });
}
