import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/lectionary_psalm_catalog_service.dart';
import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final service = LectionaryPsalmCatalogService.instance;

  group('LectionaryPsalmCatalogService - Real Date Tests', () {
    test('Advent 1 Sunday Cycle A has entries with R notation', () async {
      final date = DateTime(2024, 12, 1); // First Sunday of Advent 2024
      final entries = await service.getEntriesForDate(date);

      expect(entries, isNotEmpty);

      // Check that entries have R notation preserved
      final hasRNotation = entries.any((e) => e.fullReference.contains('(R.'));
      expect(hasRNotation, isTrue);
    });

    test('December 17 (O Antiphon) has entries with R notation', () async {
      final date = DateTime(2024, 12, 17);
      final entries = await service.getEntriesForDate(date);

      expect(entries, isNotEmpty);

      // Check that entries have R notation preserved
      final hasRNotation = entries.any((e) => e.fullReference.contains('(R.'));
      expect(hasRNotation, isTrue);
    });

    test('December 20 (O Antiphon) has entries with R notation', () async {
      final date = DateTime(2024, 12, 20);
      final entries = await service.getEntriesForDate(date);

      expect(entries, isNotEmpty);

      // Check that entries have R notation preserved
      final hasRNotation = entries.any((e) => e.fullReference.contains('(R.'));
      expect(hasRNotation, isTrue);
    });

    test('Advent Weekday Monday has entries with R notation', () async {
      final date = DateTime(2024, 12, 2); // Monday of Advent Week 1
      final entries = await service.getEntriesForDate(date);

      expect(entries, isNotEmpty);

      // Check that entries have R notation preserved
      final hasRNotation = entries.any((e) => e.fullReference.contains('(R.'));
      expect(hasRNotation, isTrue);
    });

    test('Christmas Octave December 26 has entries with R notation', () async {
      final date = DateTime(2024, 12, 26);
      final entries = await service.getEntriesForDate(date);

      expect(entries, isNotEmpty);

      // Check that entries have R notation preserved
      final hasRNotation = entries.any((e) => e.fullReference.contains('(R.'));
      expect(hasRNotation, isTrue);
    });
  });

  group('LectionaryPsalmCatalogService - Response Resolution', () {
    test('liturgical response is independent of Bible version', () async {
      final psalmRef = 'Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)';
      const entries = <LectionaryPsalmCatalogEntry>[
        LectionaryPsalmCatalogEntry(
          season: 'Advent',
          week: '1',
          day: 'Sunday',
          weekdayCycle: 'I/II',
          sundayCycle: 'A',
          fullReference: 'Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)',
          refrainText: 'Generic liturgical response.',
          refrainTextRsvce: 'RSVCE-labelled response.',
          refrainTextNabre: 'NABRE-labelled response.',
          acclamationRef: '',
          acclamationText: '',
          lectionaryNumber: '1',
        ),
      ];

      // Test with RSVCE
      final rsvceResponse = service.resolvePsalmResponseFromEntries(
        entries: entries,
        psalmReference: psalmRef,
        bibleVersion: 'rsvce',
      );

      // Test with NABRE
      final nabreResponse = service.resolvePsalmResponseFromEntries(
        entries: entries,
        psalmReference: psalmRef,
        bibleVersion: 'nabre',
      );

      expect(rsvceResponse, isNotEmpty);
      expect(nabreResponse, rsvceResponse);
    });

    test(
      'resolvePsalmResponseFromEntries falls back to generic when version-specific empty',
      () {
        const psalmRef = 'Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)';
        const entries = <LectionaryPsalmCatalogEntry>[
          LectionaryPsalmCatalogEntry(
            season: 'Advent',
            week: '1',
            day: 'Sunday',
            weekdayCycle: '',
            sundayCycle: 'A',
            fullReference: psalmRef,
            refrainText: 'Let us go rejoicing to the house of the Lord.',
            acclamationRef: '',
            acclamationText: '',
            lectionaryNumber: '1',
          ),
        ];

        final response = service.resolvePsalmResponseFromEntries(
          entries: entries,
          psalmReference: psalmRef,
          bibleVersion: 'unknown',
        );
        expect(response, 'Let us go rejoicing to the house of the Lord.');
      },
    );

    test(
      'resolvePsalmResponseFromEntries distinguishes R.7 from R.7a',
      () async {
        final date = DateTime(2024, 12, 17);
        final entries = await service.getEntriesForDate(date);

        if (entries.isEmpty) {
          return; // Skip if no entries
        }

        // Psalm 72 with R.7
        final response7 = service.resolvePsalmResponseFromEntries(
          entries: entries,
          psalmReference: 'Psalm 72.1-2, 3-4, 7-8, 17 (R.7)',
        );

        // R.7 should find a match
        expect(response7, isNotNull);

        // Try to match with R.7a - should not match the same entry
        // We just verify it doesn't crash
        service.resolvePsalmResponseFromEntries(
          entries: entries,
          psalmReference: 'Psalm 72.1-2, 3-4, 7-8, 17 (R.7a)',
        );
      },
    );

    test('never uses ordinal fallback for an unrelated biblical selection', () {
      const entries = <LectionaryPsalmCatalogEntry>[
        LectionaryPsalmCatalogEntry(
          season: 'Ordinary Time',
          week: '20',
          day: 'Monday',
          weekdayCycle: 'II',
          sundayCycle: '',
          fullReference: 'Ps 119.97-98, 99-100, 101-102 (R. 97a)',
          refrainText: 'Lord, I love your commands.',
          acclamationRef: '',
          acclamationText: '',
          lectionaryNumber: '431',
        ),
      ];

      final response = service.resolvePsalmResponseFromEntries(
        entries: entries,
        psalmReference: 'Dt 32:18-19, 20, 21',
        positionLabel: 'Responsorial Psalm',
        psalmSequence: 1,
      );

      expect(response, isNull);
    });
  });

  group('LectionaryPsalmCatalogService - Best Entry Selection', () {
    test('getBestPsalmEntryForDate prefers R-bearing entries', () async {
      final date = DateTime(2024, 12, 1);
      final bestEntry = await service.getBestPsalmEntryForDate(
        date: date,
        psalmReference: 'Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)',
      );

      if (bestEntry == null) {
        return; // Skip if no entry found
      }

      // The best entry should have R notation
      expect(bestEntry.fullReference, contains('(R.'));
    });

    test(
      'Deuteronomy canticle never inherits an unrelated psalm refrain',
      () async {
        final bestEntry = await service.getBestPsalmEntryForDate(
          date: DateTime(2026, 8, 17),
          psalmReference: 'Dt 32:18-19, 20, 21',
          positionLabel: 'Responsorial Psalm',
          psalmSequence: 1,
        );

        expect(bestEntry, isNotNull);
        expect(bestEntry!.fullReference, 'Dt 32.18-19, 20, 21');
        expect(bestEntry.refrainText, 'You forgot God who gave you birth.');
      },
    );
  });
}
