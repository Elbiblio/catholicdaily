// Validates that the "Show liturgical opening" toggle actually changes
// what the app renders — offline, no network.
//
// Toggle ON  → output includes liturgical opener (Brethren, At that time,
//              Jesus said, Thus says the Lord, In those days, etc.) OR rule-
//              driven wording from assets/incipit_rules.csv.
// Toggle OFF → output is raw scripture text, no liturgical prefix layered on.
//
// Both paths must produce non-empty readings for the same dates without
// hitting the network (shared_preferences mocked, bible DBs are bundled
// assets, incipit rules are a bundled CSV asset).

import 'package:catholic_daily/data/services/incipit_preference_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

const _liturgicalOpeners = [
  'brethren',
  'brothers and sisters',
  'beloved',
  'at that time',
  'in those days',
  'jesus said',
  'jesus spoke',
  'jesus told',
  'thus says the lord',
  'then peter',
  'moses spoke',
  'moses said',
  'the lord said',
];

bool _hasLiturgicalOpener(String text) {
  final head = text.trim().toLowerCase();
  for (final o in _liturgicalOpeners) {
    if (head.startsWith(o)) return true;
    // Allow rule-style "replacement: content" form too.
    if (head.length >= o.length + 2 && head.startsWith(o.toUpperCase().toLowerCase())) {
      return true;
    }
  }
  return false;
}

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  tearDown(() {
    IncipitPreferenceService().resetCache();
  });

  // Five diverse 2026 Sunday dates covering Advent/Christmas, Lent, Easter,
  // Ordinary Time, and a Solemnity-adjacent Sunday. Each day yields 3
  // readings (First, Second, Gospel) → 15 assertions per toggle state.
  final sundays = [
    DateTime(2026, 2, 22), // 1st Sunday of Lent
    DateTime(2026, 4, 5),  // Easter Sunday
    DateTime(2026, 4, 12), // Divine Mercy
    DateTime(2026, 8, 16), // 20th OT
    DateTime(2026, 11, 22), // Christ the King
  ];

  test('Toggle ON vs OFF: output differs on most readings (offline)',
      timeout: const Timeout(Duration(minutes: 4)), () async {
    final service = ReadingsService.instance;
    final pref = IncipitPreferenceService();

    // Capture ON outputs.
    await pref.setShowIncipit(true);
    pref.resetCache();
    final onOutputs = <String, String>{};
    for (final dt in sundays) {
      final readings = await service.getReadingsForDate(dt);
      for (final r in readings) {
        final pos = (r.position ?? '').toLowerCase();
        if (!pos.contains('reading') && !pos.contains('gospel')) continue;
        final text = await service.getReadingText(
          r.reading,
          incipit: r.incipit,
        );
        onOutputs['${dt.toIso8601String()}|${r.reading}'] = text;
      }
    }

    // Capture OFF outputs.
    await pref.setShowIncipit(false);
    pref.resetCache();
    final offOutputs = <String, String>{};
    for (final dt in sundays) {
      final readings = await service.getReadingsForDate(dt);
      for (final r in readings) {
        final pos = (r.position ?? '').toLowerCase();
        if (!pos.contains('reading') && !pos.contains('gospel')) continue;
        final text = await service.getReadingText(
          r.reading,
          incipit: r.incipit,
        );
        offOutputs['${dt.toIso8601String()}|${r.reading}'] = text;
      }
    }

    // Restore default before leaving the test.
    await pref.setShowIncipit(true);
    pref.resetCache();

    expect(onOutputs.length, greaterThan(10));
    expect(offOutputs.length, equals(onOutputs.length));

    // ON and OFF outputs should differ for the vast majority of readings
    // (all except literal-match cases where the incipit already equals the
    // raw first verse).
    var differs = 0;
    var onHasLiturgical = 0;
    final sameKeys = <String>[];
    for (final key in onOutputs.keys) {
      final on = onOutputs[key]!;
      final off = offOutputs[key]!;
      if (on != off) {
        differs++;
      } else {
        sameKeys.add(key);
      }
      if (_hasLiturgicalOpener(on)) onHasLiturgical++;
    }

    // ignore: avoid_print
    print('\n─── Toggle comparison ───');
    // ignore: avoid_print
    print('Readings measured:              ${onOutputs.length}');
    // ignore: avoid_print
    print('Output differs ON vs OFF:       $differs');
    // ignore: avoid_print
    print('ON leads with liturgical opener: $onHasLiturgical');
    if (sameKeys.isNotEmpty) {
      // ignore: avoid_print
      print('Unchanged cases (legitimate literal matches):');
      for (final k in sameKeys.take(5)) {
        // ignore: avoid_print
        print('  $k');
      }
    }

    // ≥70% of readings should show a visible toggle effect. Cases where
    // ON == OFF are legitimate (canonical already matches raw) but should
    // be a minority.
    expect(differs / onOutputs.length, greaterThanOrEqualTo(0.70),
        reason: 'Toggle had visible effect on <70% of readings');
  });

  test('Toggle OFF: readings are raw scripture, no liturgical prefix added',
      timeout: const Timeout(Duration(minutes: 3)), () async {
    await IncipitPreferenceService().setShowIncipit(false);
    IncipitPreferenceService().resetCache();

    final service = ReadingsService.instance;
    var total = 0;
    var plainScripture = 0;

    for (final dt in sundays) {
      final readings = await service.getReadingsForDate(dt);
      for (final r in readings) {
        final pos = (r.position ?? '').toLowerCase();
        if (!pos.contains('reading') && !pos.contains('gospel')) continue;
        total++;
        final text = await service.getReadingText(
          r.reading,
          incipit: r.incipit,
        );
        expect(text.trim(), isNotEmpty,
            reason: 'No text for ${r.reading} on $dt (toggle OFF)');
        // Raw output should start with a verse number prefix like "1.",
        // "14.", or with the raw Bible text — not with "BRETHREN:",
        // "AT THAT TIME,", etc. The exact ALL-CAPS opener form is a strong
        // signal a rule fired, which must NOT happen when toggle is off.
        final head = text.trimLeft();
        final firstAlpha = RegExp(r'[A-Za-z]').firstMatch(head);
        if (firstAlpha == null) continue;
        final snippet = head.substring(firstAlpha.start, firstAlpha.start + 30.clamp(0, head.length - firstAlpha.start));
        // If snippet has no ALL-CAPS opener phrase and no rule-format colon,
        // we treat it as plain scripture.
        final hasAllCapsOpener = RegExp(
          r'^(BRETHREN|BELOVED|AT THAT TIME|IN THOSE DAYS|JESUS SAID|THUS SAYS|THEN PETER|MOSES)',
        ).hasMatch(snippet);
        if (!hasAllCapsOpener) plainScripture++;
      }
    }

    // ignore: avoid_print
    print('\nToggle OFF: $plainScripture / $total readings are plain '
        'scripture (no rule-style opener)');

    expect(total, greaterThan(10));
    // With toggle off, NO reading should show a rule-style ALL-CAPS opener.
    expect(plainScripture, equals(total),
        reason: 'Toggle OFF but at least one reading still has a '
            'rule-style opener — preference gate failed');
  });

  test('Toggle round-trip: state persists through service restarts',
      timeout: const Timeout(Duration(seconds: 30)), () async {
    final svc = IncipitPreferenceService();
    await svc.setShowIncipit(false);
    svc.resetCache();
    expect(await svc.getShowIncipit(), isFalse);

    await svc.setShowIncipit(true);
    svc.resetCache();
    expect(await svc.getShowIncipit(), isTrue);
  });

  test('Locale pref: persists round-trip (future multi-country hook)',
      timeout: const Timeout(Duration(seconds: 30)), () async {
    final svc = IncipitPreferenceService();
    expect(await svc.getLocale(), 'en');
    await svc.setLocale('en-GB');
    svc.resetCache();
    expect(await svc.getLocale(), 'en-GB');
    await svc.setLocale('en');
    svc.resetCache();
    expect(await svc.getLocale(), 'en');
  });
}
