// Cross-validates the app's incipit output against real external lectionary
// sources (USCCB). For each 2026 Sunday in scripts/active/external_sundays.json
// we query the app's ReadingsService for that date, match readings by scripture
// reference, and compare the opening of our rendered output against what
// USCCB actually shows.
//
// Regenerate the external data:
//   python scripts/active/scrape_external_sundays.py
//
// The test is deliberately tolerant: external sources use different Bible
// translations (USCCB = NABRE, Universalis = Jerusalem Bible) so wording will
// not be identical. We assert that the lectionary-style OPENING PHRASE agrees
// — e.g. both start with "Brothers and sisters", "At that time", "Jesus said
// to his disciples", "Thus says the Lord", etc. — or that substantive token
// overlap is ≥50%.

import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Reduces a reference to "book chapter" for approximate matching across
/// formatting drift (e.g. "Matt 4:1-11" vs "Matthew 4:1-11").
String _refKey(String ref) {
  final m = RegExp(r'^\s*(\d?\s*[A-Za-z]+)\s+(\d+)').firstMatch(ref);
  if (m == null) return _normalize(ref);
  final book = _normalize(m.group(1)!);
  final aliases = {
    'matt': 'matthew', 'mt': 'matthew',
    'mk': 'mark',
    'lk': 'luke',
    'jn': 'john',
    'gen': 'genesis', 'exod': 'exodus', 'lev': 'leviticus',
    'num': 'numbers', 'deut': 'deuteronomy',
    'isa': 'isaiah', 'jer': 'jeremiah', 'ezek': 'ezekiel',
    'zeph': 'zephaniah', 'mal': 'malachi',
    'rom': 'romans', 'cor': 'corinthians',
    'eph': 'ephesians', 'phil': 'philippians', 'col': 'colossians',
    'thess': 'thessalonians', 'tim': 'timothy',
    'heb': 'hebrews', 'pet': 'peter',
    'rev': 'revelation',
  };
  final long = aliases[book] ?? book;
  return '$long ${m.group(2)}';
}

double _tokenOverlap(String a, String b) {
  final aw = RegExp(r'\w+')
      .allMatches(_normalize(a))
      .map((m) => m.group(0)!)
      .toSet();
  final bw = RegExp(r'\w+')
      .allMatches(_normalize(b))
      .map((m) => m.group(0)!)
      .toSet();
  if (aw.isEmpty || bw.isEmpty) return 0.0;
  return aw.intersection(bw).length / bw.length;
}

/// A "lectionary opener" is a short introductory phrase the missal prepends
/// before the raw scripture text. If both outputs start with the same opener,
/// that alone is strong evidence of agreement.
bool _sharesLectionaryOpener(String a, String b) {
  final na = _normalize(a);
  final nb = _normalize(b);
  const openers = [
    'brothers and sisters',
    'brethren',
    'beloved',
    'at that time',
    'in those days',
    'jesus said to his disciples',
    'jesus said to the crowds',
    'jesus said to the pharisees',
    'jesus told his disciples',
    'jesus said',
    'thus says the lord',
    'the word of the lord',
  ];
  for (final o in openers) {
    if (na.startsWith(o) && nb.startsWith(o)) return true;
  }
  return false;
}

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test('App output agrees with USCCB on 2026 Sunday openings',
      timeout: const Timeout(Duration(minutes: 8)), () async {
    final externalFile = File('scripts/active/external_sundays.json');
    expect(externalFile.existsSync(), isTrue,
        reason: 'Run: python scripts/active/scrape_external_sundays.py');

    final raw = await externalFile.readAsString();
    final List<dynamic> days = jsonDecode(raw) as List<dynamic>;
    expect(days.length, greaterThanOrEqualTo(10));

    final service = ReadingsService.instance;

    var total = 0;
    var opener = 0;
    var overlap = 0;
    var divergent = 0;
    final divergences = <String>[];

    for (final dayRaw in days) {
      final day = dayRaw as Map<String, dynamic>;
      final date = day['date'] as String;
      final usccb = (day['usccb'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (usccb.isEmpty) continue;

      final parts = date.split('-');
      final dt = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      final appReadings = await service.getReadingsForDate(dt);

      for (final ext in usccb) {
        final extRef = ext['reference'] as String;
        final extOpening = ext['opening'] as String;
        if (extRef.isEmpty) continue;

        final extKey = _refKey(extRef);

        // Match by book + chapter (most robust across format drift).
        String? matchedReading;
        String? matchedIncipit;
        for (final r in appReadings) {
          if (_refKey(r.reading) == extKey) {
            matchedReading = r.reading;
            matchedIncipit = r.incipit;
            break;
          }
        }
        if (matchedReading == null) continue;

        total++;
        final ourText = await service.getReadingText(
          matchedReading,
          incipit: (matchedIncipit == null || matchedIncipit.isEmpty)
              ? null
              : matchedIncipit,
        );
        // Compare the first ~100 chars of our text with ext opening (~100 chars).
        final ourHead = ourText.length > 160
            ? ourText.substring(0, 160)
            : ourText;
        final extHead = extOpening.length > 160
            ? extOpening.substring(0, 160)
            : extOpening;

        final sharedOpener = _sharesLectionaryOpener(ourHead, extHead);
        final ratio = _tokenOverlap(ourHead, extHead);

        if (sharedOpener) opener++;
        if (ratio >= 0.5) overlap++;
        if (!sharedOpener && ratio < 0.5) {
          divergent++;
          divergences.add(
            '[$date $extKey]\n'
            '  external: ${extHead.length > 120 ? "${extHead.substring(0, 120)}…" : extHead}\n'
            '  ours:     ${ourHead.length > 120 ? "${ourHead.substring(0, 120)}…" : ourHead}\n'
            '  overlap:  ${ratio.toStringAsFixed(2)}',
          );
        }
      }
    }

    final openerRate = total == 0 ? 0.0 : opener / total;
    final overlapRate = total == 0 ? 0.0 : overlap / total;
    final agreement = total == 0 ? 0.0 : (total - divergent) / total;

    // ignore: avoid_print
    print('\n─── External cross-validation (USCCB, ${days.length} Sundays) ───');
    // ignore: avoid_print
    print('Matched readings: $total');
    // ignore: avoid_print
    print('  Shared lectionary opener: $opener '
        '(${(openerRate * 100).toStringAsFixed(1)}%)');
    // ignore: avoid_print
    print('  Token overlap ≥ 50%:      $overlap '
        '(${(overlapRate * 100).toStringAsFixed(1)}%)');
    // ignore: avoid_print
    print('  Agreement (either):       ${total - divergent} '
        '(${(agreement * 100).toStringAsFixed(1)}%)');
    // ignore: avoid_print
    print('  Divergent:                $divergent');
    if (divergences.isNotEmpty) {
      // ignore: avoid_print
      print('\nFirst 10 divergences:');
      for (final d in divergences.take(10)) {
        // ignore: avoid_print
        print(d);
      }
    }

    expect(total, greaterThan(15),
        reason: 'Expected at least 15 cross-matched readings');
    expect(agreement, greaterThanOrEqualTo(0.70),
        reason: 'App output diverges from USCCB on >30% of matched readings');
  });
}
