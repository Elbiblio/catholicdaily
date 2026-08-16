# Responsorial Psalm Runtime Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render reviewed lectionary responsorial-psalm text independently of Bible-version preference while preserving proper feast ordering and every legitimate alternative reading set.

**Architecture:** A dedicated asset-backed catalog resolves exact psalm response and stanza blocks by territory, liturgical usage, normalized selection, and response. `ReadingsService` consults the catalog before platform Bible backends; `ReadingFlowService` supplies date and regional context. Existing Bible hydration remains an explicit fallback for uncovered selections, and legacy psalm CSVs remain available during the first migration release.

**Tech Stack:** Dart 3, Flutter asset bundle, existing `ReadingFlowService` and `ReadingsService`, generated CSV from the source-audit plan, Flutter unit/widget tests.

---

## File Map

- Create `lib/data/models/responsorial_psalm_text_entry.dart`: immutable runtime entry and formatted-text contract.
- Create `lib/data/services/responsorial_psalm_text_catalog_service.dart`: asset loading, canonical matching, and deterministic ranking.
- Modify `lib/data/services/readings_service.dart`: catalog-first psalm resolution.
- Modify `lib/data/services/reading_flow_service.dart`: pass date and region context into text resolution.
- Modify `lib/data/services/lectionary_psalm_catalog_service.dart`: stop selecting liturgical responses by Bible version.
- Modify `lib/data/services/psalm_resolver_service.dart`: preserve reviewed responses and remove USCCB as an automatic text authority.
- Modify `lib/ui/screens/reading_screen.dart`: pass the reading's date/position context for direct reloads.
- Modify `pubspec.yaml`: bundle `assets/data/responsorial_psalm_texts.csv`.
- Create `test/data/services/responsorial_psalm_text_catalog_service_test.dart`: parsing and ranking tests.
- Create `test/data/services/responsorial_psalm_runtime_integrity_test.dart`: Bible independence and calendar coverage tests.
- Modify `test/data/services/reading_choices_exhaustive_test.dart`: proper/alternative psalm coverage.
- Modify `test/ui/screens/premium_browse_reading_choices_test.dart`: proper feast psalm first and alternatives accessible.

### Task 1: Define the runtime entry and formatting contract

**Files:**
- Create: `lib/data/models/responsorial_psalm_text_entry.dart`
- Create: `test/data/services/responsorial_psalm_text_catalog_service_test.dart`

- [ ] **Step 1: Write the failing model test**

```dart
import 'package:catholic_daily/data/models/responsorial_psalm_text_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats response before and after each lectionary stanza', () {
    const entry = ResponsorialPsalmTextEntry(
      usageId: 'ng:assumption-day:psalm:1',
      territory: 'NG',
      celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
      dateRule: '08-15',
      sundayCycle: 'A/B/C',
      weekdayCycle: 'I/II',
      lectionaryNumber: '',
      readingSetKind: 'celebration',
      referenceNormalized: 'ps45:10,11,12,16(r.10b)',
      responseText: 'On your right stands the queen in gold of Ophir.',
      stanzas: <String>[
        'The daughters of kings are those whom you favour.\nOn your right stands the queen in gold of Ophir.',
        'Listen, O daughter; pay heed and give ear;\nforget your own people and your father\'s house.',
      ],
      sourceId: 'reviewed_psalm_source',
      sourceEdition: 'reviewed edition',
      sourceUrl: 'https://www.giamusic.com/resources-psalters',
      displayPriority: 1,
    );

    expect(
      entry.formattedText,
      'R/. On your right stands the queen in gold of Ophir.\n\n'
      'The daughters of kings are those whom you favour.\n'
      'On your right stands the queen in gold of Ophir.\n\n'
      'R/. On your right stands the queen in gold of Ophir.\n\n'
      'Listen, O daughter; pay heed and give ear;\n'
      'forget your own people and your father\'s house.\n\n'
      'R/. On your right stands the queen in gold of Ophir.',
    );
  });
}
```

- [ ] **Step 2: Run and verify RED**

```powershell
flutter test --no-pub test/data/services/responsorial_psalm_text_catalog_service_test.dart
```

Expected: compilation FAIL because the model does not exist.

- [ ] **Step 3: Implement the immutable model**

```dart
class ResponsorialPsalmTextEntry {
  final String usageId;
  final String territory;
  final String celebrationId;
  final String dateRule;
  final String sundayCycle;
  final String weekdayCycle;
  final String lectionaryNumber;
  final String readingSetKind;
  final String referenceNormalized;
  final String responseText;
  final List<String> stanzas;
  final String sourceId;
  final String sourceEdition;
  final String sourceUrl;
  final int displayPriority;

  const ResponsorialPsalmTextEntry({
    required this.usageId,
    required this.territory,
    required this.celebrationId,
    required this.dateRule,
    required this.sundayCycle,
    required this.weekdayCycle,
    required this.lectionaryNumber,
    required this.readingSetKind,
    required this.referenceNormalized,
    required this.responseText,
    required this.stanzas,
    required this.sourceId,
    required this.sourceEdition,
    required this.sourceUrl,
    required this.displayPriority,
  });

  String get formattedText {
    final response = 'R/. ${responseText.trim()}';
    final parts = <String>[response];
    for (final stanza in stanzas) {
      parts..add(stanza.trim())..add(response);
    }
    return parts.join('\n\n');
  }
}
```

- [ ] **Step 4: Run the test and verify GREEN**

Expected: one test PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/data/models/responsorial_psalm_text_entry.dart test/data/services/responsorial_psalm_text_catalog_service_test.dart
git commit -m "test: define responsorial psalm text model"
```

### Task 2: Load and rank the generated runtime catalog

**Files:**
- Create: `lib/data/services/responsorial_psalm_text_catalog_service.dart`
- Modify: `test/data/services/responsorial_psalm_text_catalog_service_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the failing Assumption lookup test**

```dart
import 'package:catholic_daily/data/services/responsorial_psalm_text_catalog_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  test('Nigeria Assumption resolves exact reviewed psalm usage', () async {
    final entry = await ResponsorialPsalmTextCatalogService.instance.lookup(
      date: DateTime(2026, 8, 15),
      territory: 'NG',
      celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
      readingSetKind: 'celebration',
      reference: 'Ps 45:10, 11, 12, 16',
      response: 'On your right stands the queen in gold of Ophir.',
    );

    expect(entry, isNotNull);
    expect(entry!.usageId, contains('assumption'));
    expect(entry.referenceNormalized, 'ps45:10,11,12,16');
    expect(entry.stanzas, hasLength(4));
    expect(entry.sourceId, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run and verify RED**

Expected: compilation FAIL because the service does not exist.

- [ ] **Step 3: Implement catalog loading and normalization**

```dart
import 'package:flutter/services.dart' show rootBundle;

import '../models/responsorial_psalm_text_entry.dart';
import 'base_service.dart';
import 'reading_catalog_service.dart';

class ResponsorialPsalmTextCatalogService
    extends BaseService<ResponsorialPsalmTextCatalogService> {
  static ResponsorialPsalmTextCatalogService get instance =>
      BaseService.init(() => ResponsorialPsalmTextCatalogService._());

  ResponsorialPsalmTextCatalogService._();

  List<ResponsorialPsalmTextEntry>? _entries;
  final ReadingCatalogService _csv = ReadingCatalogService.instance;

  Future<ResponsorialPsalmTextEntry?> lookup({
    required DateTime date,
    required String territory,
    required String reference,
    String? response,
    String celebrationId = '',
    String readingSetKind = '',
    String lectionaryNumber = '',
  }) async {
    final entries = await _load();
    final normalizedReference = normalizeReference(reference);
    final normalizedResponse = normalizeWords(response ?? '');
    final candidates = entries.where((entry) {
      if (entry.referenceNormalized != normalizedReference) return false;
      if (entry.territory.isNotEmpty &&
          entry.territory != 'WORLD' &&
          entry.territory != territory) {
        return false;
      }
      if (!_matchesDateRule(entry.dateRule, date)) return false;
      return true;
    }).toList();
    candidates.sort((left, right) {
      int score(ResponsorialPsalmTextEntry entry) {
        var value = 0;
        if (entry.territory == territory) value += 100;
        if (entry.celebrationId == celebrationId && celebrationId.isNotEmpty) value += 80;
        if (entry.readingSetKind == readingSetKind && readingSetKind.isNotEmpty) value += 40;
        if (entry.lectionaryNumber == lectionaryNumber && lectionaryNumber.isNotEmpty) value += 20;
        if (normalizeWords(entry.responseText) == normalizedResponse && normalizedResponse.isNotEmpty) value += 10;
        return value - entry.displayPriority;
      }
      return score(right).compareTo(score(left));
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<List<ResponsorialPsalmTextEntry>> _load() async {
    if (_entries != null) return _entries!;
    final raw = await rootBundle.loadString('assets/data/responsorial_psalm_texts.csv');
    final lines = raw.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toList();
    final rows = <ResponsorialPsalmTextEntry>[];
    for (var index = 1; index < lines.length; index++) {
      final cols = _csv.parseCsvLine(lines[index]);
      if (cols.length != 15) {
        throw FormatException('Invalid responsorial psalm row ${index + 1}: ${cols.length} columns');
      }
      rows.add(ResponsorialPsalmTextEntry(
        usageId: cols[0], territory: cols[1], celebrationId: cols[2], dateRule: cols[3],
        sundayCycle: cols[4], weekdayCycle: cols[5], lectionaryNumber: cols[6],
        readingSetKind: cols[7], referenceNormalized: cols[8], responseText: cols[9],
        stanzas: cols[10].replaceAll(r'\n', '\n').split(r'\n\n'),
        sourceId: cols[11], sourceEdition: cols[12], sourceUrl: cols[13],
        displayPriority: int.parse(cols[14]),
      ));
    }
    _entries = List.unmodifiable(rows);
    return _entries!;
  }

  static String normalizeReference(String value) => value
      .toLowerCase()
      .replaceFirst(RegExp(r'^(?:psalm|ps)\s*'), 'ps')
      .replaceAll(' and ', ',')
      .replaceAll(RegExp(r'\(r\.[^)]*\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'[.;](?=\d)'), ',')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r',+'), ',')
      .trim();

  static String normalizeWords(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _matchesDateRule(String rule, DateTime date) {
    if (rule.isEmpty || rule == '*') return true;
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(rule)) {
      return rule == '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    return rule == '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 4: Bundle the generated CSV**

Add under `flutter/assets` in `pubspec.yaml`:

```yaml
    - assets/data/responsorial_psalm_texts.csv
```

- [ ] **Step 5: Run service tests**

Expected: model and Assumption lookup tests PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/data/services/responsorial_psalm_text_catalog_service.dart pubspec.yaml test/data/services/responsorial_psalm_text_catalog_service_test.dart
git commit -m "feat: load reviewed responsorial psalm texts"
```

### Task 3: Resolve liturgical psalms before Bible hydration

**Files:**
- Modify: `lib/data/services/readings_service.dart`
- Modify: `lib/data/services/reading_flow_service.dart`
- Modify: `lib/ui/screens/reading_screen.dart`
- Create: `test/data/services/responsorial_psalm_runtime_integrity_test.dart`

- [ ] **Step 1: Write a failing Bible-version independence test**

```dart
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  test('reviewed liturgical psalm does not change with Bible preference', () async {
    final reading = DailyReading(
      reading: 'Ps 45:10, 11, 12, 16',
      position: 'Responsorial Psalm',
      date: DateTime(2026, 8, 15),
      feast: 'The Assumption of the Blessed Virgin Mary',
      psalmResponse: 'On your right stands the queen in gold of Ophir.',
      source: 'celebration:assumption_of_blessed_virgin_mary',
    );
    final preference = await BibleVersionPreference.getInstance();
    final original = preference.currentVersion;
    addTearDown(() => preference.setVersion(original));
    await preference.setVersion(BibleVersionType.rsvce);
    final rsvce = await ReadingFlowService.instance.getReadingText(reading);
    await preference.setVersion(BibleVersionType.nabre);
    final nabre = await ReadingFlowService.instance.getReadingText(reading);
    expect(nabre, rsvce);
    expect(rsvce, contains('They are escorted amid gladness and joy'));
  });
}
```

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because the current backend hydrates RSVCE/NABRE stanza text.

- [ ] **Step 3: Add catalog context to `ReadingsService.getReadingText`**

Extend the signature with optional `date`, `territory`, `celebrationId`, `readingSetKind`, and `lectionaryNumber`. Before calling the platform backend, detect responsorial positions and call `ResponsorialPsalmTextCatalogService.lookup`. Return `entry.formattedText` when found; otherwise use the existing backend unchanged.

```dart
final ResponsorialPsalmTextCatalogService _psalmTexts =
    ResponsorialPsalmTextCatalogService.instance;

final isResponsorial =
    (readingType ?? '').toLowerCase().contains('responsorial psalm');
if (isResponsorial && date != null && territory != null) {
  final entry = await _psalmTexts.lookup(
    date: date,
    territory: territory,
    reference: reference,
    response: psalmResponse,
    celebrationId: celebrationId ?? '',
    readingSetKind: readingSetKind ?? '',
    lectionaryNumber: lectionaryNumber ?? '',
  );
  if (entry != null) return entry.formattedText;
}
```

- [ ] **Step 4: Pass context from `ReadingFlowService`**

In `hydrateReadingSet`, pass `date`, `regionPrefs.currentRegion.code`, and parsed source metadata. Add private helpers that interpret existing `DailyReading.source` values without changing legacy serialization:

```dart
String _celebrationId(DailyReading reading) {
  final source = reading.source ?? '';
  final match = RegExp(r'(?:celebration|proper):([^|;]+)').firstMatch(source);
  final explicit = match?.group(1)?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  return (reading.feast ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _readingSetKind(DailyReading reading) {
  final position = (reading.position ?? '').toLowerCase();
  if (position.contains('vigil')) return 'vigil';
  if ((reading.source ?? '').contains('weekday')) return 'weekday';
  return 'celebration';
}
```

Update `getReadingText(DailyReading reading)` to obtain the current region and pass `reading.date`, position, response, celebration, and set kind.

- [ ] **Step 5: Pass context from direct reading-screen reloads**

At the direct `ReadingsService.getReadingText` call in `reading_screen.dart`, pass the active `DailyReading` date and position. Reuse the current region already available to the screen or obtain `LiturgicalRegionPreferenceService`; do not hardcode `NG`.

- [ ] **Step 6: Run the independence test**

Expected: PASS with identical Assumption psalm text under RSVCE and NABRE.

- [ ] **Step 7: Commit**

```powershell
git add lib/data/services/readings_service.dart lib/data/services/reading_flow_service.dart lib/ui/screens/reading_screen.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart
git commit -m "fix: render exact liturgical psalm text"
```

### Task 4: Stop selecting lectionary responses by Bible version

**Files:**
- Modify: `lib/data/services/lectionary_psalm_catalog_service.dart`
- Modify: `lib/data/services/psalm_resolver_service.dart`
- Modify: `test/lectionary_psalm_catalog_service_test.dart`
- Modify: `test/data/services/responsorial_psalm_runtime_integrity_test.dart`

- [ ] **Step 1: Replace the permissive version test with a failing invariant**

```dart
test('liturgical response is independent of Bible version', () async {
  final entries = await service.getEntriesForDate(DateTime(2024, 12, 1));
  final reference = 'Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)';
  final rsvce = service.resolvePsalmResponseFromEntries(
    entries: entries,
    psalmReference: reference,
    bibleVersion: 'rsvce',
  );
  final nabre = service.resolvePsalmResponseFromEntries(
    entries: entries,
    psalmReference: reference,
    bibleVersion: 'nabre',
  );
  expect(rsvce, nabre);
  expect(rsvce, isNotEmpty);
});
```

- [ ] **Step 2: Run and verify RED against a known divergent legacy row**

Select a fixture/date where the legacy version-specific columns differ. Expected: FAIL because current code branches on `bibleVersion`.

- [ ] **Step 3: Make generic reviewed response authoritative**

Change `resolvePsalmResponseFromEntries` to return `match.refrainText.trim()` only. Retain the `bibleVersion` argument temporarily for API compatibility and mark it ignored with a doc comment. Do not fall back to the known-corrupt version-labelled columns.

- [ ] **Step 4: Remove automatic USCCB mutation**

In `PsalmResolverService`, keep explicit/resolved catalog responses. Do not launch `_fetchAndUpdatePsalmResponse` as an asynchronous authority for an already resolved liturgical psalm. Leave a manual diagnostic fetch helper only if tests or tooling use it; runtime display must be deterministic and offline.

- [ ] **Step 5: Run catalog and resolver tests**

```powershell
flutter test --no-pub test/lectionary_psalm_catalog_service_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart
```

Expected: all tests PASS; response equality invariant holds.

- [ ] **Step 6: Commit**

```powershell
git add lib/data/services/lectionary_psalm_catalog_service.dart lib/data/services/psalm_resolver_service.dart test/lectionary_psalm_catalog_service_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart
git commit -m "fix: decouple psalm responses from Bible version"
```

### Task 5: Verify proper feast psalms and all alternatives

**Files:**
- Modify: `test/data/services/reading_choices_exhaustive_test.dart`
- Modify: `test/ui/screens/premium_browse_reading_choices_test.dart`
- Modify: `test/data/services/responsorial_psalm_runtime_integrity_test.dart`

- [ ] **Step 1: Add a failing Assumption choice-order test**

```dart
test('Assumption proper psalm is first and Vigil remains accessible', () async {
  final prefs = await LiturgicalRegionPreferenceService.getInstance();
  await prefs.setRegion(LiturgicalRegion.nigeria);
  final sets = await AlternateReadingsService.instance
      .getAvailableReadingSets(DateTime(2026, 8, 15));
  expect(sets.first.label, 'The Assumption of the Blessed Virgin Mary');
  expect(
    sets.first.readings.where((reading) =>
      (reading.position ?? '').contains('Responsorial Psalm')).single.reading,
    'Ps 45:10, 11, 12, 16',
  );
  expect(sets.any((set) => set.label.contains('Vigil Mass')), isTrue);
  expect(sets.any((set) => set.isFerial), isTrue);
});
```

- [ ] **Step 2: Add an exhaustive psalm hydration assertion**

For every reading set emitted by the existing multi-year/multi-region choice audit:

```dart
for (final set in result.sets) {
  for (final psalm in set.readings.where((reading) =>
      (reading.position ?? '').toLowerCase().contains('responsorial psalm'))) {
    final text = await ReadingFlowService.instance.getReadingText(psalm);
    expect(text, isNot(contains('Psalm text unavailable')),
        reason: '${set.label}: ${psalm.reading}');
    expect(text, startsWith('R/.'), reason: set.label);
  }
}
```

Limit the exhaustive test to the supported catalog date range and regions so it remains deterministic and finishes within the repository's serialized-suite budget.

- [ ] **Step 3: Add UI assertions**

Extend the existing premium browse test to verify:

- the first selected reading set is the Assumption Day set;
- the first responsorial card uses Psalm 45;
- its preview begins with the reviewed response;
- Vigil and weekday choice controls remain visible and selectable;
- selecting each alternative changes to that set's own psalm text.

- [ ] **Step 4: Run focused resolver/UI tests**

```powershell
flutter test --no-pub test/data/services/reading_choices_exhaustive_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/ui/screens/premium_browse_reading_choices_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add test/data/services/reading_choices_exhaustive_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/ui/screens/premium_browse_reading_choices_test.dart
git commit -m "test: cover psalms across reading choices"
```

### Task 6: Full verification and release handoff

**Files:**
- Modify only confirmed defects found by the verification commands.

- [ ] **Step 1: Regenerate and compare the corpus**

```powershell
python test/scripts/responsorial_psalm_corpus_test.py -v
python scripts/build_responsorial_psalm_corpus.py --fixtures-only --output-dir "$env:TEMP\responsorial-psalm-release-check" --retrieved-at 2026-08-16
```

Expected: extractor tests PASS; deterministic rebuild succeeds.

- [ ] **Step 2: Run focused Flutter tests**

```powershell
flutter test --no-pub test/lectionary_psalm_catalog_service_test.dart test/data/services/responsorial_psalm_text_catalog_service_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/data/services/reading_choices_exhaustive_test.dart test/ui/screens/premium_browse_reading_choices_test.dart
```

Expected: all focused tests PASS.

- [ ] **Step 3: Run analyzer**

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Run the serialized full suite**

```powershell
flutter test --no-pub --concurrency=1
```

Expected: zero failed tests; only repository-documented skips.

- [ ] **Step 5: Run data and scope checks**

```powershell
git diff --check
git status --short
rg -n "AIza|firebase_api_key|\.apk$|config\.armeabi" verification/psalm_sources assets/data/responsorial_psalm_texts.csv
```

Expected: clean diff; only intended paths; no secrets/APKs; generated-artifact scope matches the two plans.

- [ ] **Step 6: Inspect representative dates**

Verify at minimum:

- 2026-01-01 Mary, Mother of God;
- 2026-08-15 Assumption Day and Vigil;
- a weekday memorial retaining weekday readings;
- a feast with proper readings;
- a Sunday with a legitimate alternative psalm;
- one RSVCE-to-NABRE preference change proving unchanged psalm text.

- [ ] **Step 7: Commit verification-only corrections when present**

If no correction is needed, do not create an empty commit. If a verified defect changes any planned runtime file, stage the explicit plan-owned paths and inspect the staged diff before committing:

```powershell
git add -- lib/data/models/responsorial_psalm_text_entry.dart lib/data/services/responsorial_psalm_text_catalog_service.dart lib/data/services/readings_service.dart lib/data/services/reading_flow_service.dart lib/data/services/lectionary_psalm_catalog_service.dart lib/data/services/psalm_resolver_service.dart lib/ui/screens/reading_screen.dart pubspec.yaml assets/data/responsorial_psalm_texts.csv test/data/services/responsorial_psalm_text_catalog_service_test.dart test/data/services/responsorial_psalm_runtime_integrity_test.dart test/data/services/reading_choices_exhaustive_test.dart test/ui/screens/premium_browse_reading_choices_test.dart
git diff --cached --check
git commit -m "fix: close responsorial psalm audit gaps"
```
