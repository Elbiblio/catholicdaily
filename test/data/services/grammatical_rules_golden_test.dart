// Validates that rules emitted by scripts/active/grammatical_rule_master.py
// actually produce the canonical lectionary opening when processed by the
// Dart IncipitProcessingService + IncipitRulesService pipeline.
//
// Ground truth: scripts/active/grammatical_golden_pairs.json (81 Sunday /
// Solemnity readings where both raw_first_verse and canonical_incipit are
// known). Regenerate with:
//   python scripts/active/grammatical_rule_master.py validate
//
// Each pair flows: (reference, raw_first_verse) →
//   IncipitRulesService.match → rule transforms opening →
//   IncipitProcessingService.process merges+dedupes → final output.
//
// The test asserts the final output leads with the canonical incipit (token-
// normalized prefix match). Aggregate pass rate is reported; a hard floor of
// 80% keeps accidental regressions visible.

import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/services/incipit_processing_service.dart';
import 'package:catholic_daily/data/services/incipit_rules_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

String _normalize(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _startsWithNormalized(String haystack, String needle) {
  final h = _normalize(haystack);
  final n = _normalize(needle);
  if (n.isEmpty) return false;
  return h.startsWith(n);
}

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  final goldenFile = File('scripts/active/grammatical_golden_pairs.json');
  final goldenFileExists = goldenFile.existsSync();

  Future<List<Map<String, dynamic>>> _loadPairs(String category) async {
    expect(goldenFileExists, isTrue,
        reason: 'Run: python scripts/active/grammatical_rule_master.py validate');
    final raw = await goldenFile.readAsString();
    final all = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((p) => (p['category'] ?? 'train') == category)
        .toList();
    return all;
  }

  test('TRAIN: rules reproduce canonical incipits (≥95%)',
      skip: !goldenFileExists
          ? 'Golden pairs not found. Run: python scripts/active/grammatical_rule_master.py validate'
          : null,
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final pairs = await _loadPairs('train');
    expect(pairs.length, greaterThanOrEqualTo(30),
        reason: 'Expected at least 30 training pairs');

    final processor = IncipitProcessingService();
    final rules = IncipitRulesService();
    rules.resetCache();

    final failures = <String>[];
    final byClass = <String, List<bool>>{};
    var passed = 0;

    for (final p in pairs) {
      final reference = p['reference'] as String;
      final canonical = p['canonical_incipit'] as String;
      final rawVerse = p['raw_first_verse'] as String;
      final readingType = p['reading_type'] as String;

      final match = await rules.matchForText(
        reference: reference,
        fullText: rawVerse,
      );
      final output = match != null
          ? processor.processWithAuthoritativeIncipit(
              reference, rawVerse, match.transformed)
          : processor.process(reference, rawVerse, csvIncipit: null);

      final ok = _startsWithNormalized(output, canonical);
      final klass = match?.rule.failureClass ?? 'no_rule_match';
      byClass.putIfAbsent(klass, () => []).add(ok);
      if (ok) {
        passed++;
      } else {
        failures.add(
          '[$reference | $readingType]\n'
          '  canonical:  $canonical\n'
          '  rule hit:   ${match == null ? "NONE" : match.rule.ruleId}\n'
          '  output:     ${output.length > 160 ? "${output.substring(0, 160)}…" : output}',
        );
      }
    }

    final rate = passed / pairs.length;
    // ignore: avoid_print
    print('\n─── TRAIN coverage ───');
    // ignore: avoid_print
    print('Total: ${pairs.length}   Pass: $passed   '
        'Rate: ${(rate * 100).toStringAsFixed(1)}%');
    for (final e in byClass.entries) {
      final ok = e.value.where((x) => x).length;
      // ignore: avoid_print
      print('  ${e.key.padRight(22)} $ok / ${e.value.length}');
    }
    for (final f in failures.take(10)) {
      // ignore: avoid_print
      print(f);
    }
    expect(rate, greaterThanOrEqualTo(0.95),
        reason: 'TRAIN coverage dropped below 95%.');
  });

  test('VERIFY: random audit sample does not regress (≥85% stable)',
      skip: !goldenFileExists
          ? 'Golden pairs not found. Run: python scripts/active/grammatical_rule_master.py validate'
          : null,
      timeout: const Timeout(Duration(minutes: 3)), () async {
    final pairs = await _loadPairs('verify');
    if (pairs.isEmpty) {
      // ignore: avoid_print
      print('No verify pairs — skipping');
      return;
    }

    final processor = IncipitProcessingService();
    final rules = IncipitRulesService();
    rules.resetCache();

    var stable = 0;
    var ruleFired = 0;
    var falsePositives = 0;
    final regressions = <String>[];

    for (final p in pairs) {
      final reference = p['reference'] as String;
      final canonical = p['canonical_incipit'] as String;
      final rawVerse = p['raw_first_verse'] as String;

      final match = await rules.matchForText(
        reference: reference,
        fullText: rawVerse,
      );
      final output = match != null
          ? processor.processWithAuthoritativeIncipit(
              reference, rawVerse, match.transformed)
          : processor.process(reference, rawVerse, csvIncipit: null);

      if (match != null) ruleFired++;

      // Stability criterion:
      //   • Output is non-empty and longer than just the incipit.
      //   • If a rule fired, its replacement must appear at the start.
      //   • If no rule fired, output must retain most of the raw verse's
      //     token content (no mangling).
      final nonEmpty = output.trim().isNotEmpty;
      final preservesStart = match != null
          ? _startsWithNormalized(output, match.transformed)
          : _tokenOverlapRatio(output, rawVerse) >= 0.5;

      if (nonEmpty && preservesStart) {
        stable++;
      } else {
        regressions.add(
          '[$reference] rule=${match?.rule.ruleId ?? "none"}\n'
          '  canonical: $canonical\n'
          '  output:    ${output.length > 140 ? "${output.substring(0, 140)}…" : output}',
        );
        if (match != null) falsePositives++;
      }
    }

    final rate = stable / pairs.length;
    // ignore: avoid_print
    print('\n─── VERIFY stability ───');
    // ignore: avoid_print
    print('Total: ${pairs.length}   Stable: $stable   '
        'Rule fired: $ruleFired   False-positive: $falsePositives   '
        'Rate: ${(rate * 100).toStringAsFixed(1)}%');
    for (final r in regressions.take(10)) {
      // ignore: avoid_print
      print(r);
    }
    expect(rate, greaterThanOrEqualTo(0.85),
        reason: 'VERIFY stability dropped below 85%. Rules may be '
            'producing false positives for unseen references.');
  });
}

double _tokenOverlapRatio(String a, String b) {
  final aw = RegExp(r'\w+')
      .allMatches(a.toLowerCase())
      .map((m) => m.group(0)!)
      .toSet();
  final bw = RegExp(r'\w+')
      .allMatches(b.toLowerCase())
      .map((m) => m.group(0)!)
      .toSet();
  if (aw.isEmpty || bw.isEmpty) return 0.0;
  return (aw.intersection(bw).length) / bw.length;
}
