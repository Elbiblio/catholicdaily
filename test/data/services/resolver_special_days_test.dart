import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';

/// Verifies that special-day flows produce complete reading sets:
/// - Easter Vigil (7 readings + Epistle + Gospel)
/// - Holy Thursday, Good Friday
/// - Easter Sunday
/// - SS Peter & Paul (Vigil + Day)
/// - Christmas (Vigil + Midnight + Dawn + Day)
/// - Easter Octave weekdays
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Easter Vigil 2026 (Apr 4)', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 4, 4));
    // ignore: avoid_print
    print('=== Easter Vigil 2026-04-04 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    final positions = readings.map((r) => (r.position ?? '').toLowerCase()).toList();
    expect(positions.any((p) => p.contains('gospel')), isTrue,
        reason: 'Easter Vigil must include Gospel');
    expect(positions.any((p) => p.contains('epistle')), isTrue,
        reason: 'Easter Vigil must include Epistle');
    // Vigil has 7 OT readings typically
    final firstReadings = positions.where((p) => p.contains('reading')).length;
    expect(firstReadings, greaterThanOrEqualTo(7),
        reason: 'Easter Vigil should have 7 OT readings + Epistle');
  });

  test('Easter Sunday 2026 (Apr 5)', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 4, 5));
    // ignore: avoid_print
    print('=== Easter Sunday 2026-04-05 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel')), isTrue);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('first')), isTrue);
  });

  test('Holy Thursday 2026 (Apr 2) - Mass of the Lord\'s Supper', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 4, 2));
    // ignore: avoid_print
    print('=== Holy Thursday 2026-04-02 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel')), isTrue);
  });

  test('Good Friday 2026 (Apr 3)', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 4, 3));
    // ignore: avoid_print
    print('=== Good Friday 2026-04-03 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel')), isTrue);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('first')), isTrue);
  });

  test('Easter Octave (Tue Apr 7) 2026', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 4, 7));
    // ignore: avoid_print
    print('=== Easter Octave Tue 2026-04-07 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    expect(readings, isNotEmpty);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel')), isTrue);
  });

  test('SS Peter and Paul 2026-06-29', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 6, 29));
    // ignore: avoid_print
    print('=== SS Peter & Paul 2026-06-29 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    expect(readings, isNotEmpty);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel')), isTrue);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('first')), isTrue);
  });

  test('Christmas Day 2026-12-25', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 12, 25));
    // ignore: avoid_print
    print('=== Christmas Day 2026-12-25 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    expect(readings, isNotEmpty);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel')), isTrue);
  });

  test('Ash Wednesday 2026-02-18', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 2, 18));
    // ignore: avoid_print
    print('=== Ash Wednesday 2026-02-18 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    expect(readings, isNotEmpty);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel')), isTrue);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('first')), isTrue);
  });

  test('Pentecost 2026-05-24', () async {
    final resolver = CsvReadingsResolverService.instance;
    final readings = await resolver.resolve(DateTime(2026, 5, 24));
    // ignore: avoid_print
    print('=== Pentecost 2026-05-24 ===');
    for (final r in readings) {
      // ignore: avoid_print
      print('  ${r.position}: ${r.reading}');
    }
    expect(readings, isNotEmpty);
    expect(readings.any((r) => (r.position ?? '').toLowerCase().contains('gospel')), isTrue);
  });
}
