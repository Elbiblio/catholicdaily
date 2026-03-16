import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/gospel_acclamation_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/data/services/ultimate_gospel_acclamation_mapper.dart';
import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  final acclamationService = GospelAcclamationService();
  final optionalMemorials = OptionalMemorialService.instance;
  final mapper = UltimateGospelAcclamationMapper.instance;

  group('Gospel acclamation regression coverage', () {
    test('abbreviated reference Mk 1:17 resolves to verse text', () async {
      final resolved = await acclamationService.getAcclamationText('Mk 1:17');

      expect(resolved.startsWith('Reading text unavailable'), isFalse);
      expect(resolved, isNot('Mk 1:17'));
      expect(resolved.toLowerCase(), contains('fishers of men'));
    });

    test('March 17, 2026 proper memorial acclamation reference is safe and resolvable', () async {
      final date = DateTime(2026, 3, 17);
      final allCelebrations = optionalMemorials.getAllCelebrationsForDate(date);
      final patrickReadings = optionalMemorials.getProperReadings('patrick_of_ireland');
      final mapped = mapper.getAcclamation(
        date: date,
        gospelReference: 'John 5:1-16',
      );

      expect(allCelebrations, isNotEmpty,
          reason: 'Expected commemorated celebrations to exist on March 17, 2026.');
      expect(patrickReadings, isNotNull);
      expect(patrickReadings!.gospelAcclamation, equals('Mk 1:17'));

      final resolvedProper = await acclamationService.getAcclamationText(
        patrickReadings.gospelAcclamation!,
      );

      expect(resolvedProper.startsWith('Reading text unavailable'), isFalse);
      expect(resolvedProper.toLowerCase(), contains('fishers of men'));
      expect(mapped.text, isNotEmpty);
      expect(mapped.text.startsWith('Reading text unavailable'), isFalse);
      expect(mapped.reference, isNot(equals(patrickReadings.gospelAcclamation)));
    });

    test('March 12, 2026 Lent weekday uses official Joel acclamation text', () {
      final result = mapper.getAcclamation(
        date: DateTime(2026, 3, 12),
        gospelReference: 'Luke 11:14-23',
      );

      expect(result.reference, 'Joel 2:12-13');
      expect(
        result.text,
        'Even now, says the LORD, return to me with your whole heart; for I am gracious and merciful.',
      );
    });

    test('regression matrix across key liturgical dates yields safe mapped acclamations', () {
      final cases = <({DateTime date, String gospelReference})>[
        (date: DateTime(2026, 1, 13), gospelReference: 'Mark 1:21-28'),
        (date: DateTime(2026, 3, 17), gospelReference: 'John 5:1-16'),
        (date: DateTime(2026, 3, 19), gospelReference: 'Matthew 1:16, 18-21, 24a'),
        (date: DateTime(2026, 4, 7), gospelReference: 'Luke 24:13-35'),
        (date: DateTime(2026, 6, 24), gospelReference: 'Luke 1:57-66, 80'),
        (date: DateTime(2026, 12, 21), gospelReference: 'Luke 1:39-45'),
      ];

      for (final testCase in cases) {
        final result = mapper.getAcclamation(
          date: testCase.date,
          gospelReference: testCase.gospelReference,
        );

        expect(result.reference, isNotEmpty,
            reason:
                'Expected non-empty reference for ${testCase.date.toIso8601String().split('T').first}.');
        expect(result.text, isNotEmpty,
            reason:
                'Expected non-empty text for ${testCase.date.toIso8601String().split('T').first}.');
        expect(result.text.startsWith('Reading text unavailable'), isFalse,
            reason:
                'Mapped fallback leaked on ${testCase.date.toIso8601String().split('T').first}.');
      }
    });
  });
}
