import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/ordo_resolver_service.dart';
import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  group('Debug Sunday Cycle for 2026', () {
    test('Should determine correct Sunday cycle for 2026', () async {
      final ordoResolver = OrdoResolverService.instance;
      
      // Check Sunday cycles for several years to verify pattern
      for (int year = 2020; year <= 2030; year++) {
        final date = DateTime(year, 3, 15); // Use a date in Lent
        final yearVars = await ordoResolver.resolveYearVariables(date);
        print('Year $year: Sunday Cycle ${yearVars.sundayCycle}');
      }
      
      // Specifically check 2026
      final year2026 = await ordoResolver.resolveYearVariables(DateTime(2026, 3, 15));
      print('2026 Sunday Cycle: ${year2026.sundayCycle}');
      
      // Liturgical year starting Advent 2025 = Year A, so March 2026 = A
      // Pattern: 2020=A, 2021=B, 2022=C, 2023=A, 2024=B, 2025=C, 2026=A
      expect(year2026.sundayCycle, equals('A'));
    }, skip: false);
  }, skip: false);
}
