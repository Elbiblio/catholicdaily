import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catholic_daily/data/services/gospel_acclamation_service.dart';
import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  SharedPreferences.setMockInitialValues({});

  final service = GospelAcclamationService();

  group('GospelAcclamationService', () {
    test('does not resolve plain text acclamation as a reference', () {
      const acclamation =
          'Restore to me the joy of thy salvation Deliver me from bloodguiltiness, O God, thou God of my salvation.';

      expect(service.shouldResolveReference(acclamation), isFalse);
    });

    test('does not resolve plain text acclamation with reference-like words', () {
      const acclamation =
          'My sheep hear my voice, says the Lord; I know them, and they follow me.';

      expect(service.shouldResolveReference(acclamation), isFalse);
    });

    test('recognizes a true scripture reference', () {
      expect(service.shouldResolveReference('John 3:16'), isTrue);
      expect(service.shouldResolveReference('Cf. John 6:63c, 68c'), isTrue);
      expect(service.shouldResolveReference('See Phil 2:8-9'), isTrue);
    });

    test('returns plain text acclamation unchanged', () async {
      const acclamation =
          'Restore to me the joy of thy salvation Deliver me from bloodguiltiness, O God, thou God of my salvation.';

      final result = await service.getAcclamationText(acclamation);

      expect(result, acclamation);
      expect(result.startsWith('Reading text unavailable'), isFalse);
    });

    test('returns prefixed plain text acclamation unchanged', () async {
      const acclamation =
          'Alleluia. Blessed are they who have kept the word with a generous heart and yield a harvest through perseverance.';

      final result = await service.getAcclamationText(acclamation);

      expect(result, acclamation);
      expect(result.startsWith('Reading text unavailable'), isFalse);
    });

    test('formats plain text acclamation without introducing unavailable fallback', () async {
      const acclamation = 'My sheep hear my voice, says the Lord; I know them, and they follow me.';

      final result = await service.getFormattedAcclamation(acclamation);

      expect(result, startsWith('Alleluia, alleluia.'));
      expect(result.contains('Reading text unavailable'), isFalse);
    });
  });
}
