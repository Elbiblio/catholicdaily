import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';

/// Audits every day of 2026 (and 2027) and asserts every reading is well-formed.
/// Prints a summary of days with no readings or suspicious references so we can
/// catch coverage gaps before release.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Full-year audit 2026-2027', () async {
    final resolver = CsvReadingsResolverService.instance;

    final noReadings = <String>[];
    final malformed = <String>[];
    final noFirstReading = <String>[];
    final noGospel = <String>[];

    for (var year = 2026; year <= 2027; year++) {
      for (var month = 1; month <= 12; month++) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        for (var day = 1; day <= daysInMonth; day++) {
          final date = DateTime(year, month, day);
          final readings = await resolver.resolve(date);
          final label = '$year-${month.toString().padLeft(2, "0")}-${day.toString().padLeft(2, "0")}';

          if (readings.isEmpty) {
            noReadings.add(label);
            continue;
          }

          for (final r in readings) {
            if (r.position == 'Sequence') continue;
            final ref = r.reading.trim();
            final valid = RegExp(r'^[A-Za-z]|^\d+\s+[A-Za-z]').hasMatch(ref);
            if (!valid) {
              malformed.add('$label ${r.position}: "$ref"');
            }
          }

          final hasFirst = readings.any((r) => (r.position ?? '').toLowerCase().contains('first reading'));
          final hasGospel = readings.any((r) {
            final pos = (r.position ?? '').toLowerCase();
            return pos.contains('gospel') && !pos.contains('acclamation');
          });
          if (!hasFirst) noFirstReading.add(label);
          if (!hasGospel) noGospel.add(label);
        }
      }
    }

    // Print summary
    // ignore: avoid_print
    print('\n=== FULL YEAR AUDIT (2026-2027) ===');
    // ignore: avoid_print
    print('Days with NO readings: ${noReadings.length}');
    if (noReadings.isNotEmpty) {
      // ignore: avoid_print
      print('  ${noReadings.take(20).join(", ")}');
    }
    // ignore: avoid_print
    print('Days with malformed references: ${malformed.length}');
    for (final m in malformed.take(30)) {
      // ignore: avoid_print
      print('  $m');
    }
    // ignore: avoid_print
    print('Days with NO first reading: ${noFirstReading.length}');
    if (noFirstReading.isNotEmpty) {
      // ignore: avoid_print
      print('  First 20: ${noFirstReading.take(20).join(", ")}');
    }
    // ignore: avoid_print
    print('Days with NO gospel: ${noGospel.length}');
    if (noGospel.isNotEmpty) {
      // ignore: avoid_print
      print('  First 20: ${noGospel.take(20).join(", ")}');
    }

    expect(malformed.isEmpty, isTrue,
        reason: 'Found malformed references: ${malformed.take(5).join("; ")}');
  });
}
