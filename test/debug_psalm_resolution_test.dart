import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/lectionary_psalm_catalog_service.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/services/psalm_resolver_service.dart';
import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  group('Debug Psalm Resolution for 4th Sunday of Lent 2026', () {
    test('Should match Lent,4,Sunday,A entry from catalog', () async {
      final date = DateTime(2026, 3, 15); // 4th Sunday of Lent 2026
      final catalogService = LectionaryPsalmCatalogService.instance;
      final calendarService = ImprovedLiturgicalCalendarService.instance;
      final psalmResolver = PsalmResolverService.instance;

      // Get liturgical info
      final liturgicalDay = calendarService.getLiturgicalDay(date);
      print('Liturgical day: ${liturgicalDay.seasonName} Week ${liturgicalDay.weekNumber}');
      print('Date: $date (${date.weekday})');

      // Get catalog entries for this date
      final entries = await catalogService.getEntriesForDate(date);
      print('Found ${entries.length} catalog entries for $date');
      
      for (final entry in entries) {
        print('Entry: ${entry.season}, ${entry.week}, ${entry.day}, ${entry.sundayCycle}');
        print('  Reference: ${entry.fullReference}');
        print('  Response: ${entry.refrainText}');
      }

      // Try to resolve Psalm 23 response (what's in database)
      const dbPsalmReference = 'Ps 23:1-6';
      print('Looking for DB psalm reference: "$dbPsalmReference"');
      
      final dbResponse = await psalmResolver.resolvePsalmResponse(
        date: date,
        psalmReference: dbPsalmReference,
      );
      
      print('Catalog response for DB reference "$dbPsalmReference": $dbResponse');
      
      // Try to resolve Psalm 34 response (what's in catalog)
      const catalogPsalmReference = 'Psalm 34:2-3.4-5.6-7';
      print('Looking for catalog psalm reference: "$catalogPsalmReference"');
      
      final catalogResponse = await psalmResolver.resolvePsalmResponse(
        date: date,
        psalmReference: catalogPsalmReference,
      );
      
      print('Catalog response for catalog reference "$catalogPsalmReference": $catalogResponse');
      
      // Check what should be the expected response
      if (entries.isNotEmpty) {
        print('Expected response: ${entries.first.refrainText}');
        expect(catalogResponse, equals(entries.first.refrainText));
      }
    }, skip: true);
  }, skip: true);
}
