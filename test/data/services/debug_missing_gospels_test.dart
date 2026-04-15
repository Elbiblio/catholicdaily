import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Investigate missing gospels and readings', () async {
    final resolver = CsvReadingsResolverService.instance;
    final dates = [
      DateTime(2026, 1, 25),  // Conversion of St Paul
      DateTime(2026, 2, 2),   // Presentation of the Lord
      DateTime(2026, 4, 2),   // Holy Thursday 2026
      DateTime(2026, 4, 3),   // Good Friday 2026
      DateTime(2026, 6, 13),  // St Anthony of Padua
      DateTime(2026, 7, 22),  // Mary Magdalene
      DateTime(2026, 8, 6),   // Transfiguration
      DateTime(2026, 9, 8),   // Nativity of Mary
      DateTime(2026, 9, 29),  // Archangels
      DateTime(2026, 10, 18), // St Luke
      DateTime(2026, 12, 26), // St Stephen
      DateTime(2027, 2, 22),  // Chair of Peter
      DateTime(2027, 2, 28),  // 1st Sunday of Lent 2027
    ];

    for (final d in dates) {
      final readings = await resolver.resolve(d);
      // ignore: avoid_print
      print('\n=== ${d.toIso8601String().substring(0, 10)} ===');
      if (readings.isEmpty) {
        // ignore: avoid_print
        print('  NO READINGS');
      }
      for (final r in readings) {
        // ignore: avoid_print
        print('  ${r.position}: "${r.reading}"');
      }
    }
  });
}
