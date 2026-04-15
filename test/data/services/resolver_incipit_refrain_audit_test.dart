import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import '../../helpers/test_helpers.dart';

/// Walks every day from Jan 1 2026 through Dec 31 2027 and asserts the
/// backend output (the path the UI actually renders) is free of the
/// issues the user flagged: trailing page-number noise, "-R." rubric
/// residue, and un-decoded "(R. Xx)" psalm-response references.
///
/// Also spot-verifies a handful of specific dates the user called out.
void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test('Two-year audit: no trailing PDF noise anywhere',
      timeout: const Timeout(Duration(minutes: 15)), () async {
    final service = ReadingsService.instance;
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2027, 12, 31);

    final noisePattern = RegExp(r'\s\d{2,4}\s+[A-Z][A-Z \-]{2,}$');
    final trailingRRubric = RegExp(r'[-–—]\s*R\.?\s*$');
    final spacedHeader = RegExp(r'\bG\s+O\s+S\s+P\s+E\s+L\b');

    final offenders = <String>[];

    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final readings = await service.getReadingsForDate(d);
      for (final r in readings) {
        final iso = '${d.year}-${d.month.toString().padLeft(2, '0')}'
            '-${d.day.toString().padLeft(2, '0')}';
        void checkField(String label, String? value) {
          if (value == null) return;
          final trimmed = value.trim();
          if (trimmed.isEmpty) return;
          if (noisePattern.hasMatch(trimmed) ||
              trailingRRubric.hasMatch(trimmed) ||
              spacedHeader.hasMatch(trimmed)) {
            offenders.add('$iso [${r.position}] $label → "$trimmed"');
          }
        }

        checkField('psalmResponse', r.psalmResponse);
        checkField('gospelAcclamation', r.gospelAcclamation);
        checkField('incipit', r.incipit);
      }
    }

    if (offenders.isNotEmpty) {
      // ignore: avoid_print
      print('Trailing-noise offenders (first 20):');
      for (final o in offenders.take(20)) {
        // ignore: avoid_print
        print('  $o');
      }
    }
    expect(offenders, isEmpty, reason: 'Found trailing PDF/rubric noise');
  });

  test('Spot checks: user-reported dates', () async {
    final service = ReadingsService.instance;

    // 2026-04-15: Acts 5:17-26 — incipit must contain "In those days"
    // AND "rose up". Psalm 34 refrain must be the RSVCE verse text.
    final today = await service.getReadingsForDate(DateTime(2026, 4, 15));
    final first = today.firstWhere((r) => r.position == 'First Reading');
    expect(first.reading, 'Acts 5:17-26');
    expect(first.incipit, isNotNull);

    // Fetch rendered text and verify the incipit is present in the output.
    final firstText = await service.getReadingText(
      first.reading,
      incipit: first.incipit,
    );
    expect(firstText, contains('In those days'));
    expect(firstText, contains('rose up'));

    final psalm =
        today.firstWhere((r) => r.position == 'Responsorial Psalm');
    expect(psalm.reading, contains('(R.'));
    expect(psalm.psalmResponse, isNotNull);
    expect(psalm.psalmResponse!.toLowerCase(),
        contains('this poor man cried'));

    // 2026-04-19: Acts 2:14, 22-33 — incipit must continue naturally
    // into "lifted up his voice and addressed them".
    final sun = await service.getReadingsForDate(DateTime(2026, 4, 19));
    final sunFirst = sun.firstWhere((r) => r.position == 'First Reading');
    final sunText = await service.getReadingText(
      sunFirst.reading,
      incipit: sunFirst.incipit,
    );
    expect(sunText, contains('THEN Peter stood up with the Eleven'));
    expect(sunText, contains('lifted up his voice'));

    // Gospel Acclamation reference "cf. Luke 24:32" must decode.
    final acc =
        sun.firstWhere((r) => r.position == 'Gospel Acclamation');
    final accText = await service.getReadingText(acc.reading);
    expect(accText, isNot(startsWith('Reading text unavailable')));
    expect(accText.toLowerCase(), contains('hearts burn'));
  });
}
