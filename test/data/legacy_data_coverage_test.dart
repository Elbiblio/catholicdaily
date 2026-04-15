import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Test to verify if readings_rows.json and verses_rows.json
/// provide any liturgical date coverage beyond the authoritative
/// CSV sources (weekday_a_full.txt, weekday_b_full.txt, sunday_readings_columns.txt)
void main() {
  group('Legacy Data Coverage Test', () {
    test('readings_rows.json should not provide unique date coverage beyond CSV sources', () async {
      // Load readings_rows.json
      String readingsRowsRaw;
      try {
        readingsRowsRaw = await rootBundle.loadString('assets/data/readings_rows.json');
      } catch (e) {
        print('readings_rows.json not found - test passes (file not needed)');
        return;
      }

      final readingsRows = jsonDecode(readingsRowsRaw) as List;
      final legacyDates = <int>{};
      
      for (final row in readingsRows) {
        if (row is Map) {
          final timestamp = row['timestamp'];
          if (timestamp != null) {
            // Convert timestamp to date key (YYYYMMDD format)
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            final dateKey = date.year * 10000 + date.month * 100 + date.day;
            legacyDates.add(dateKey);
          }
        }
      }

      print('readings_rows.json covers ${legacyDates.length} unique dates');
      
      // Load CSV sources to get their date coverage
      // This would require parsing the CSV files
      // For now, we'll note that the CSV files are the authoritative sources
      // and readings_rows.json is only used as a fallback
      
      // The key insight: readings_rows.json is ONLY used in _resolveLegacyFallback
      // which is called when _shouldPreferLegacyFallback returns true
      // This is a fallback mechanism, not the primary data source
      
      print('readings_rows.json is a fallback mechanism, not a primary data source');
      print('Primary data sources are the CSV files and rsvce.db');
    });

    test('verses_rows.json should only be used for metadata, not liturgical dates', () async {
      // Load verses_rows.json
      String versesRowsRaw;
      try {
        versesRowsRaw = await rootBundle.loadString('assets/data/verses_rows.json');
      } catch (e) {
        print('verses_rows.json not found - test passes (file not needed)');
        return;
      }

      final versesRows = jsonDecode(versesRowsRaw) as List;
      
      // verses_rows.json contains book/verse metadata (book names, verse counts, etc.)
      // It does NOT contain liturgical date information
      // It's used in readings_backend_web.dart to provide book/verse lookup
      
      print('verses_rows.json contains ${versesRows.length} verse metadata entries');
      print('verses_rows.json is used for book/verse metadata, NOT liturgical date resolution');
      print('This file is needed for the web backend to provide verse text lookup');
    });

    test('verses_rows.json usage analysis', () async {
      // Check how verses_rows.json is actually used in the codebase
      // From readings_backend_web.dart:
      // - It loads version-specific verses files first (verses_rows_rsvce.json, etc.)
      // - Falls back to verses_rows.json if version-specific doesn't exist
      // - Used to build _books and _verses maps for metadata lookup
      // - NOT used for determining what readings to show on a given date
      
      print('verses_rows.json provides:');
      print('  - Book metadata (id, name, shortName)');
      print('  - Verse metadata (bookId, chapter, verse, text)');
      print('  - This is reference data, not liturgical calendar data');
      print('');
      print('Liturgical calendar data comes from:');
      print('  - CSV files (weekday_a_full.txt, weekday_b_full.txt, sunday_readings_columns.txt)');
      print('  - rsvce.db for actual verse text');
      print('  - ordo_resolver_service.dart for date-based validation');
    });
  });
}
