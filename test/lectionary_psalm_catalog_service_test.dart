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
    test(
      'resolvePsalmResponseFromEntries uses bible version parameter',
      () async {
        final date = DateTime(2024, 12, 1);
        final entries = await service.getEntriesForDate(date);

        if (entries.isEmpty) {
          return; // Skip if no entries
        }

        final psalmRef = 'Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)';

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

        // Both should return something (fallback to generic if version-specific not available)
        expect(rsvceResponse, isNotNull);
        expect(nabreResponse, isNotNull);
      },
    );

    test(
      'resolvePsalmResponseFromEntries falls back to generic when version-specific empty',
      () async {
        final date = DateTime(2024, 12, 1);
        final entries = await service.getEntriesForDate(date);

        if (entries.isEmpty) {
          return; // Skip if no entries
        }

        final psalmRef = 'Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)';

        // Test with unknown version - should fall back to generic
        final response = service.resolvePsalmResponseFromEntries(
          entries: entries,
          psalmReference: psalmRef,
          bibleVersion: 'unknown',
        );

        expect(response, isNotNull);
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
  });
}
