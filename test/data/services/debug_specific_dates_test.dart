import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Debug 2026-11-26', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 11, 26));
    // ignore: avoid_print
    print('=== 2026-11-26 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('${r.position}: "${r.reading}" incipit=${r.incipit}');
    }
  });

  test('Debug 2026-06-29', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 6, 29));
    // ignore: avoid_print
    print('=== 2026-06-29 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('${r.position}: "${r.reading}" incipit=${r.incipit}');
    }
  });

  test('Debug 2026-09-14', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 9, 14));
    // ignore: avoid_print
    print('=== 2026-09-14 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('${r.position}: "${r.reading}" incipit=${r.incipit}');
    }
  });
}
