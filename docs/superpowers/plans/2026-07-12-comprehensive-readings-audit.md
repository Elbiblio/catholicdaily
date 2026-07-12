# Comprehensive Readings Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reproducible audit and fix workflow for future Catholic Daily readings across General Roman, US, US Ascension Thursday, England/Wales, and Nigeria, while making Bible text backends extensible beyond the current RSVCE/NABRE pair.

**Architecture:** Add small audit data types and a deterministic date matrix under `test/data/services/`, then use those tests to drive resolver fixes. Add a `BibleSourceRegistry` that describes bundled and future/user-provided Bible databases without bundling questionable copyrighted full texts. Keep source comparison, resolver correctness, text rendering, and emulator QA separate so each failure is classifiable.

**Tech Stack:** Flutter/Dart, `flutter_test`, existing CSV/SQLite assets, existing `CsvReadingsResolverService`, `OrdoResolverService`, `ReadingsBackendIo`, `SharedPreferences`, `sqflite_common_ffi`, Android emulator `emulator-5554`.

---

## File Structure

- Create `lib/data/models/bible_source.dart`: immutable metadata model for bundled, user-provided, and external-only Bible sources.
- Create `lib/data/services/bible_source_registry.dart`: registry for RSVCE, NABRE, and prepared ESV-CE/JB/Nigeria metadata.
- Modify `lib/data/services/bible_version_preference.dart`: keep existing enum compatibility but route labels and ids through the registry where possible.
- Modify `lib/data/services/readings_backend_io.dart`: replace hardcoded database selection fields with a map keyed by Bible source id for bundled sources.
- Modify `lib/data/services/readings_backend_web.dart`: use registry metadata for version labels where web code references supported versions.
- Create `test/data/services/comprehensive_audit_matrix.dart`: deterministic future date matrix, regions, expected minimum structures, and failure classification helpers.
- Create `test/data/services/comprehensive_resolver_audit_test.dart`: service-level audit for dates/regions/references.
- Create `test/data/services/bible_source_registry_test.dart`: registry and permission-status tests.
- Create `test/data/services/bible_text_backend_version_test.dart`: version switching and missing-text classification tests.
- Create `scripts/active/run_comprehensive_readings_audit.ps1`: command wrapper that runs focused audit tests and writes logs under `verification/`.
- Create `verification/comprehensive-readings-audit/README.md`: explains generated audit artifacts and emulator capture naming.
- Append to `test/QA_REGRESSION_CHECKLIST.md`: manual emulator checklist for the audited date/version/region subset.

## Task 1: Bible Source Metadata Registry

**Files:**
- Create: `lib/data/models/bible_source.dart`
- Create: `lib/data/services/bible_source_registry.dart`
- Test: `test/data/services/bible_source_registry_test.dart`

- [ ] **Step 1: Write the failing registry tests**

Create `test/data/services/bible_source_registry_test.dart`:

```dart
import 'package:catholic_daily/data/services/bible_source_registry.dart';
import 'package:catholic_daily/data/models/bible_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BibleSourceRegistry', () {
    test('exposes RSVCE and NABRE as bundled local SQLite sources', () {
      final registry = BibleSourceRegistry.instance;

      final rsvce = registry.requireById('rsvce');
      final nabre = registry.requireById('nabre');

      expect(rsvce.displayName, 'Revised Standard Version Catholic Edition');
      expect(rsvce.abbreviation, 'RSVCE');
      expect(rsvce.storage, BibleSourceStorage.bundledAsset);
      expect(rsvce.assetDbName, 'rsvce.db');
      expect(rsvce.redistribution, BibleSourceRedistribution.bundledAllowed);

      expect(nabre.displayName, 'New American Bible Revised Edition');
      expect(nabre.abbreviation, 'NABRE');
      expect(nabre.storage, BibleSourceStorage.bundledAsset);
      expect(nabre.assetDbName, 'nabre.db');
      expect(nabre.redistribution, BibleSourceRedistribution.bundledAllowed);
    });

    test('prepares ESVCE and Jerusalem Bible as non-bundled sources', () {
      final registry = BibleSourceRegistry.instance;

      final esvce = registry.requireById('esvce');
      final jerusalem = registry.requireById('jerusalem');

      expect(esvce.storage, BibleSourceStorage.externalOnly);
      expect(esvce.redistribution, isNot(BibleSourceRedistribution.bundledAllowed));
      expect(esvce.regionAffinityCodes, contains('GB_EW'));

      expect(jerusalem.storage, BibleSourceStorage.externalOnly);
      expect(jerusalem.redistribution, isNot(BibleSourceRedistribution.bundledAllowed));
      expect(jerusalem.regionAffinityCodes, contains('NG'));
    });

    test('selectableBundledSources only returns locally renderable sources', () {
      final ids = BibleSourceRegistry.instance.selectableBundledSources
          .map((source) => source.id)
          .toList();

      expect(ids, containsAll(<String>['rsvce', 'nabre']));
      expect(ids, isNot(contains('esvce')));
      expect(ids, isNot(contains('jerusalem')));
    });
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/data/services/bible_source_registry_test.dart
```

Expected: FAIL because `BibleSourceRegistry`, `BibleSource`, `BibleSourceStorage`, and `BibleSourceRedistribution` do not exist.

- [ ] **Step 3: Add the Bible source model**

Create `lib/data/models/bible_source.dart`:

```dart
enum BibleSourceStorage {
  bundledAsset,
  userProvidedLocal,
  externalOnly,
}

enum BibleSourceRedistribution {
  bundledAllowed,
  userProvidedOnly,
  externalOnly,
}

class BibleSource {
  final String id;
  final String displayName;
  final String abbreviation;
  final BibleSourceStorage storage;
  final BibleSourceRedistribution redistribution;
  final String? assetDbName;
  final String sourceUrl;
  final String attribution;
  final List<String> regionAffinityCodes;
  final bool catholicCanon;

  const BibleSource({
    required this.id,
    required this.displayName,
    required this.abbreviation,
    required this.storage,
    required this.redistribution,
    required this.sourceUrl,
    required this.attribution,
    required this.regionAffinityCodes,
    required this.catholicCanon,
    this.assetDbName,
  });

  bool get isBundledRenderable =>
      storage == BibleSourceStorage.bundledAsset &&
      redistribution == BibleSourceRedistribution.bundledAllowed &&
      assetDbName != null &&
      assetDbName!.trim().isNotEmpty;
}
```

- [ ] **Step 4: Add the registry**

Create `lib/data/services/bible_source_registry.dart`:

```dart
import '../models/bible_source.dart';

class BibleSourceRegistry {
  static final BibleSourceRegistry instance = BibleSourceRegistry._();

  BibleSourceRegistry._();

  static const _sources = <BibleSource>[
    BibleSource(
      id: 'rsvce',
      displayName: 'Revised Standard Version Catholic Edition',
      abbreviation: 'RSVCE',
      storage: BibleSourceStorage.bundledAsset,
      redistribution: BibleSourceRedistribution.bundledAllowed,
      assetDbName: 'rsvce.db',
      sourceUrl: 'assets/rsvce.db',
      attribution: 'Bundled local RSVCE SQLite database.',
      regionAffinityCodes: ['general', 'NG'],
      catholicCanon: true,
    ),
    BibleSource(
      id: 'nabre',
      displayName: 'New American Bible Revised Edition',
      abbreviation: 'NABRE',
      storage: BibleSourceStorage.bundledAsset,
      redistribution: BibleSourceRedistribution.bundledAllowed,
      assetDbName: 'nabre.db',
      sourceUrl: 'assets/nabre.db',
      attribution: 'Bundled local NABRE SQLite database.',
      regionAffinityCodes: ['US', 'US_ASC_THU'],
      catholicCanon: true,
    ),
    BibleSource(
      id: 'esvce',
      displayName: 'English Standard Version Catholic Edition',
      abbreviation: 'ESV-CE',
      storage: BibleSourceStorage.externalOnly,
      redistribution: BibleSourceRedistribution.externalOnly,
      sourceUrl: 'https://www.liturgyoffice.org.uk/Resources/Lectionary/LM-FAQ.shtml',
      attribution: 'Prepared metadata for England and Wales lectionary comparison. Full text is not bundled without a verified redistribution basis.',
      regionAffinityCodes: ['GB_EW'],
      catholicCanon: true,
    ),
    BibleSource(
      id: 'jerusalem',
      displayName: 'Jerusalem Bible',
      abbreviation: 'JB',
      storage: BibleSourceStorage.externalOnly,
      redistribution: BibleSourceRedistribution.externalOnly,
      sourceUrl: 'https://universalis.com/mass.htm',
      attribution: 'Prepared metadata for reference comparison. Full text is not bundled without a verified redistribution basis.',
      regionAffinityCodes: ['general', 'GB_EW', 'NG'],
      catholicCanon: true,
    ),
  ];

  List<BibleSource> get allSources => List.unmodifiable(_sources);

  List<BibleSource> get selectableBundledSources =>
      _sources.where((source) => source.isBundledRenderable).toList(growable: false);

  BibleSource? byId(String id) {
    final normalized = id.trim().toLowerCase();
    for (final source in _sources) {
      if (source.id == normalized) return source;
    }
    return null;
  }

  BibleSource requireById(String id) {
    final source = byId(id);
    if (source == null) {
      throw ArgumentError.value(id, 'id', 'Unknown Bible source id');
    }
    return source;
  }
}
```

- [ ] **Step 5: Run the registry test and verify GREEN**

Run:

```powershell
flutter test test/data/services/bible_source_registry_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 1**

Run:

```powershell
git add lib/data/models/bible_source.dart lib/data/services/bible_source_registry.dart test/data/services/bible_source_registry_test.dart
git commit -m "feat: add Bible source registry"
```

## Task 2: Wire Registry Into Existing Bible Version Preference

**Files:**
- Modify: `lib/data/services/bible_version_preference.dart`
- Test: `test/data/services/bible_source_registry_test.dart`

- [ ] **Step 1: Extend the existing test for enum compatibility**

Append this test inside the existing group in `test/data/services/bible_source_registry_test.dart`:

```dart
    test('BibleVersionType remains compatible with bundled registry ids', () {
      for (final version in BibleVersionType.values) {
        final source = BibleSourceRegistry.instance.requireById(version.dbName);
        expect(version.fullName, source.displayName);
        expect(version.abbreviation, source.abbreviation);
      }
    });
```

Add this import:

```dart
import 'package:catholic_daily/data/services/bible_version_preference.dart';
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/data/services/bible_source_registry_test.dart
```

Expected: FAIL if enum labels drift from registry labels, or PASS if already aligned. If it passes immediately, keep the test because it locks compatibility before refactoring.

- [ ] **Step 3: Route enum display fields through the registry**

Modify `lib/data/services/bible_version_preference.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible_source_registry.dart';

enum BibleVersionType {
  rsvce('rsvce'),
  nabre('nabre');

  final String dbName;

  const BibleVersionType(this.dbName);

  String get fullName =>
      BibleSourceRegistry.instance.requireById(dbName).displayName;

  String get abbreviation =>
      BibleSourceRegistry.instance.requireById(dbName).abbreviation;

  static BibleVersionType fromDbName(String dbName) {
    return BibleVersionType.values.firstWhere(
      (v) => v.dbName == dbName,
      orElse: () => BibleVersionType.rsvce,
    );
  }
}
```

Leave the `BibleVersionPreference` class body unchanged.

- [ ] **Step 4: Run compatibility tests**

Run:

```powershell
flutter test test/data/services/bible_source_registry_test.dart test/language_switcher_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 2**

Run:

```powershell
git add lib/data/services/bible_version_preference.dart test/data/services/bible_source_registry_test.dart
git commit -m "refactor: use Bible source metadata for bundled versions"
```

## Task 3: Generalize IO Backend Database Selection

**Files:**
- Modify: `lib/data/services/readings_backend_io.dart`
- Test: `test/data/services/bible_text_backend_version_test.dart`

- [ ] **Step 1: Write the failing text backend version test**

Create `test/data/services/bible_text_backend_version_test.dart`:

```dart
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test('switching RSVCE to NABRE changes rendered verse text without changing reference', () async {
    final pref = await BibleVersionPreference.getInstance();
    final service = ReadingsService.instance;

    await pref.setVersion(BibleVersionType.rsvce);
    final rsvceText = await service.getReadingText('John 3:16');

    await pref.setVersion(BibleVersionType.nabre);
    await service.reloadForVersionChange();
    final nabreText = await service.getReadingText('John 3:16');

    expect(rsvceText, isNot(contains('Reading text unavailable')));
    expect(nabreText, isNot(contains('Reading text unavailable')));
    expect(rsvceText, isNot(equals(nabreText)));
  });
}
```

- [ ] **Step 2: Run the test to establish current behavior**

Run:

```powershell
flutter test test/data/services/bible_text_backend_version_test.dart
```

Expected: PASS before refactor. If it fails, classify the failure as `text-version` and fix only after reading the exact failure output.

- [ ] **Step 3: Replace hardcoded DB fields with a registry-backed cache**

In `lib/data/services/readings_backend_io.dart`, add:

```dart
import '../models/bible_source.dart';
import 'bible_source_registry.dart';
```

Replace:

```dart
  Database? _rsvceDb;
  Database? _nabreDb;
```

with:

```dart
  final Map<String, Database> _databaseCache = <String, Database>{};
```

Replace `_rsvceDatabase`, `_nabreDatabase`, and `_currentBibleDatabase` with:

```dart
  Future<Database> _databaseForSource(BibleSource source) async {
    if (!source.isBundledRenderable) {
      throw StateError('Bible source ${source.id} is not a bundled local database.');
    }
    final cached = _databaseCache[source.id];
    if (cached != null) return cached;
    final opened = await _openAssetDatabase(source.assetDbName!, readOnly: true);
    _databaseCache[source.id] = opened;
    return opened;
  }

  Future<Database> get _currentBibleDatabase async {
    _versionPreference ??= await BibleVersionPreference.getInstance();
    final source = BibleSourceRegistry.instance.requireById(
      _versionPreference!.currentDbName,
    );
    return _databaseForSource(source);
  }
```

Replace `close()` with:

```dart
  @override
  Future<void> close() async {
    try {
      for (final db in _databaseCache.values) {
        await db.close();
      }
      _databaseCache.clear();
      _booksCache = null;
      _aliasesCache = null;
    } catch (e) {
      debugPrint('Error closing readings backend: $e');
    }
  }
```

- [ ] **Step 4: Run text backend and database tests**

Run:

```powershell
flutter test test/data/services/bible_text_backend_version_test.dart test/integration/database_working_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

Run:

```powershell
git add lib/data/services/readings_backend_io.dart test/data/services/bible_text_backend_version_test.dart
git commit -m "refactor: select Bible databases through source registry"
```

## Task 4: Deterministic Comprehensive Audit Matrix

**Files:**
- Create: `test/data/services/comprehensive_audit_matrix.dart`
- Test: `test/data/services/comprehensive_resolver_audit_test.dart`

- [ ] **Step 1: Write the failing audit matrix smoke test**

Create `test/data/services/comprehensive_resolver_audit_test.dart`:

```dart
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:flutter_test/flutter_test.dart';

import 'comprehensive_audit_matrix.dart';

void main() {
  group('ComprehensiveAuditMatrix', () {
    test('contains required regions and at least 75 deterministic future dates', () {
      expect(comprehensiveAuditRegions, containsAll(<LiturgicalRegion>[
        LiturgicalRegion.generalRoman,
        LiturgicalRegion.unitedStates,
        LiturgicalRegion.unitedStatesAscensionThursday,
        LiturgicalRegion.englandWales,
        LiturgicalRegion.nigeria,
      ]));

      expect(comprehensiveAuditDates.length, greaterThanOrEqualTo(75));
      expect(comprehensiveAuditDates, contains(DateTime(2026, 10, 1)));
      expect(comprehensiveAuditDates, contains(DateTime(2027, 5, 13)));
      expect(comprehensiveAuditDates, contains(DateTime(2030, 12, 25)));
    });
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/data/services/comprehensive_resolver_audit_test.dart
```

Expected: FAIL because `comprehensive_audit_matrix.dart` does not exist.

- [ ] **Step 3: Add deterministic matrix helpers**

Create `test/data/services/comprehensive_audit_matrix.dart`:

```dart
import 'dart:math';

import 'package:catholic_daily/data/models/liturgical_region.dart';

const comprehensiveAuditRegions = <LiturgicalRegion>[
  LiturgicalRegion.generalRoman,
  LiturgicalRegion.unitedStates,
  LiturgicalRegion.unitedStatesAscensionThursday,
  LiturgicalRegion.englandWales,
  LiturgicalRegion.nigeria,
];

final comprehensiveAuditSeedDates = <DateTime>[
  DateTime(2026, 7, 15),
  DateTime(2026, 8, 15),
  DateTime(2026, 10, 1),
  DateTime(2026, 11, 1),
  DateTime(2026, 12, 8),
  DateTime(2027, 2, 17),
  DateTime(2027, 3, 19),
  DateTime(2027, 3, 25),
  DateTime(2027, 5, 13),
  DateTime(2027, 5, 16),
  DateTime(2027, 6, 6),
  DateTime(2028, 4, 16),
  DateTime(2028, 6, 24),
  DateTime(2029, 7, 3),
  DateTime(2030, 12, 25),
];

final comprehensiveAuditDates = _buildAuditDates();

List<DateTime> _buildAuditDates() {
  final dates = <DateTime>{...comprehensiveAuditSeedDates};
  final random = Random(20260712);

  while (dates.length < 75) {
    final year = 2027 + random.nextInt(6);
    final month = 1 + random.nextInt(12);
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = 1 + random.nextInt(maxDay);
    dates.add(DateTime(year, month, day));
  }

  final sorted = dates.toList()..sort((a, b) => a.compareTo(b));
  return List.unmodifiable(sorted);
}

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
```

- [ ] **Step 4: Run the matrix smoke test and verify GREEN**

Run:

```powershell
flutter test test/data/services/comprehensive_resolver_audit_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 4**

Run:

```powershell
git add test/data/services/comprehensive_audit_matrix.dart test/data/services/comprehensive_resolver_audit_test.dart
git commit -m "test: add comprehensive readings audit matrix"
```

## Task 5: Region-Aware Resolver Audit

**Files:**
- Modify: `test/data/services/comprehensive_audit_matrix.dart`
- Modify: `test/data/services/comprehensive_resolver_audit_test.dart`
- Modify as bugs are found: `lib/data/services/csv_readings_resolver_service.dart`, `lib/data/services/offline_ordo_lookup_service.dart`, `lib/data/services/ordo_resolver_service.dart`, CSV data files only if root cause is data.

- [ ] **Step 1: Add audit failure classification helpers**

Append to `test/data/services/comprehensive_audit_matrix.dart`:

```dart
enum AuditFailureKind {
  calendar,
  reference,
  priority,
  cycle,
  region,
  textMissing,
  textVersion,
  incipit,
  psalmResponse,
  ui,
}

class ResolverAuditFailure {
  final DateTime date;
  final LiturgicalRegion region;
  final AuditFailureKind kind;
  final String message;

  const ResolverAuditFailure({
    required this.date,
    required this.region,
    required this.kind,
    required this.message,
  });

  @override
  String toString() =>
      '${isoDate(date)} ${region.code} ${kind.name}: $message';
}
```

- [ ] **Step 2: Add the resolver audit test**

Append to `test/data/services/comprehensive_resolver_audit_test.dart`:

```dart
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';

import '../../helpers/test_helpers.dart';
```

Add inside `main()` before the group:

```dart
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());
```

Add this test inside the group:

```dart
    test('resolves non-empty well-formed readings for every matrix date and region',
        timeout: const Timeout(Duration(minutes: 8)), () async {
      final resolver = CsvReadingsResolverService.instance;
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      final failures = <ResolverAuditFailure>[];

      for (final region in comprehensiveAuditRegions) {
        await prefs.setRegion(region, manuallySelected: true);
        for (final date in comprehensiveAuditDates) {
          final readings = await resolver.resolve(date);

          if (readings.isEmpty) {
            failures.add(ResolverAuditFailure(
              date: date,
              region: region,
              kind: AuditFailureKind.reference,
              message: 'No readings resolved',
            ));
            continue;
          }

          final hasFirst = readings.any((reading) =>
              (reading.position ?? '').toLowerCase().contains('first reading'));
          final hasPsalm = readings.any((reading) =>
              (reading.position ?? '').toLowerCase().contains('psalm'));
          final hasGospel = readings.any((reading) {
            final position = (reading.position ?? '').toLowerCase();
            return position.contains('gospel') && !position.contains('acclamation');
          });

          if (!hasFirst) {
            failures.add(ResolverAuditFailure(
              date: date,
              region: region,
              kind: AuditFailureKind.reference,
              message: 'No first reading in ${readings.map((r) => r.position).join(', ')}',
            ));
          }
          if (!hasPsalm) {
            failures.add(ResolverAuditFailure(
              date: date,
              region: region,
              kind: AuditFailureKind.psalmResponse,
              message: 'No responsorial psalm in ${readings.map((r) => r.position).join(', ')}',
            ));
          }
          if (!hasGospel) {
            failures.add(ResolverAuditFailure(
              date: date,
              region: region,
              kind: AuditFailureKind.reference,
              message: 'No gospel in ${readings.map((r) => r.position).join(', ')}',
            ));
          }

          for (final reading in readings) {
            if (reading.position == 'Sequence') continue;
            final reference = reading.reading.trim();
            final valid = RegExp(r'^[A-Za-z]|^\d+\s+[A-Za-z]').hasMatch(reference);
            if (!valid) {
              failures.add(ResolverAuditFailure(
                date: date,
                region: region,
                kind: AuditFailureKind.reference,
                message: '${reading.position}: malformed reference "$reference"',
              ));
            }
          }
        }
      }

      if (failures.isNotEmpty) {
        // ignore: avoid_print
        print('\nComprehensive resolver audit failures:');
        for (final failure in failures.take(80)) {
          // ignore: avoid_print
          print('  $failure');
        }
      }

      expect(failures, isEmpty);
    });
```

- [ ] **Step 3: Run the resolver audit and verify RED or GREEN**

Run:

```powershell
flutter test test/data/services/comprehensive_resolver_audit_test.dart
```

Expected: If FAIL, copy the first failure group into the implementation notes and proceed with the smallest fix in Step 4. If PASS, commit the audit test and move to Task 6.

- [ ] **Step 4: Fix only the first root-cause class**

Use the failure classification:

- For wrong/empty fixed feasts, inspect `_findCelebrationEntry`, `memorial_feasts.csv`, and authoritative overrides in `CsvReadingsResolverService`.
- For transfer bugs, inspect `OfflineOrdoLookupService` and `LiturgicalRegion` transfer getters.
- For cycle bugs, inspect `OrdoResolverService.resolveYearVariables`.
- For malformed references, inspect `_normalizeReferenceStyle` and the specific CSV row.

Before production edits, add a focused test in the same file. Use the exact first failing case from the audit output. This is the concrete pattern to follow, using the known Easter Week 2 Wednesday regression already documented in the repo:

```dart
    test('focused regression: 2026-04-15 resolves Easter weekday Acts reading', () async {
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      await prefs.setRegion(LiturgicalRegion.generalRoman, manuallySelected: true);

      final readings = await CsvReadingsResolverService.instance.resolve(
        DateTime(2026, 4, 15),
      );

      expect(readings.map((r) => r.reading), contains('Acts 5:17-26'));
      expect(readings.map((r) => r.reading), isNot(contains('Acts 2:1-11')));
    });
```

If the audit's first failure is not this Easter weekday case, write the same style of test with the actual failing date, region, and source-backed expected reference from the audit output. Run it and verify RED before changing production code.

- [ ] **Step 5: Run the focused regression and full audit**

Run:

```powershell
flutter test test/data/services/comprehensive_resolver_audit_test.dart
```

Expected: PASS after the fix.

- [ ] **Step 6: Commit Task 5**

Run:

```powershell
git add test/data/services/comprehensive_audit_matrix.dart test/data/services/comprehensive_resolver_audit_test.dart lib/data/services/csv_readings_resolver_service.dart lib/data/services/offline_ordo_lookup_service.dart lib/data/services/ordo_resolver_service.dart standard_lectionary_complete.csv memorial_feasts.csv special_period_readings.csv
git commit -m "fix: harden comprehensive readings resolver audit"
```

Only include changed files. If some listed files are untouched, Git will ignore them.

## Task 6: External Source Adapter Skeleton and Audit Output

**Files:**
- Create: `scripts/active/run_comprehensive_readings_audit.ps1`
- Create: `verification/comprehensive-readings-audit/README.md`
- Modify: `test/data/services/comprehensive_resolver_audit_test.dart`

- [ ] **Step 1: Add audit artifact README**

Create `verification/comprehensive-readings-audit/README.md`:

```markdown
# Comprehensive Readings Audit Artifacts

This directory stores generated evidence from the regional readings audit.

File naming:

- `resolver-20260712-143000.log`: focused Flutter resolver audit output.
- `analyze-20260712-143000.log`: `flutter analyze` output.
- `emulator-2026-10-01-nigeria-rsvce.xml`: UI Automator XML dump.
- `emulator-2026-10-01-nigeria-rsvce.png`: emulator screenshot.

Failure taxonomy:

- `calendar`
- `reference`
- `priority`
- `cycle`
- `region`
- `text-missing`
- `text-version`
- `incipit`
- `psalm-response`
- `ui`
```

- [ ] **Step 2: Add the audit runner script**

Create `scripts/active/run_comprehensive_readings_audit.ps1`:

```powershell
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outDir = Join-Path $root "verification/comprehensive-readings-audit"
New-Item -ItemType Directory -Force $outDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resolverLog = Join-Path $outDir "resolver-$stamp.log"
$textLog = Join-Path $outDir "text-backend-$stamp.log"
$analyzeLog = Join-Path $outDir "analyze-$stamp.log"

Push-Location $root
try {
  flutter test test/data/services/comprehensive_resolver_audit_test.dart 2>&1 | Tee-Object -FilePath $resolverLog
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter test test/data/services/bible_text_backend_version_test.dart 2>&1 | Tee-Object -FilePath $textLog
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter analyze 2>&1 | Tee-Object -FilePath $analyzeLog
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}
```

- [ ] **Step 3: Run the script and verify logs are produced**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/active/run_comprehensive_readings_audit.ps1
```

Expected: PASS with new log files under `verification/comprehensive-readings-audit/`. If `flutter analyze` reports existing unrelated warnings, document them in the final notes and do not hide them.

- [ ] **Step 4: Commit Task 6**

Run:

```powershell
git add scripts/active/run_comprehensive_readings_audit.ps1 verification/comprehensive-readings-audit/README.md
git commit -m "test: add comprehensive readings audit runner"
```

## Task 7: Emulator QA Checklist and Captures

**Files:**
- Modify: `test/QA_REGRESSION_CHECKLIST.md`
- Generated only: `verification/comprehensive-readings-audit/emulator-*.xml`, `verification/comprehensive-readings-audit/emulator-*.png`

- [ ] **Step 1: Add the manual emulator matrix to the checklist**

Append to `test/QA_REGRESSION_CHECKLIST.md`:

```markdown
## Comprehensive Readings Emulator Matrix

Run on Android emulator `emulator-5554` after the comprehensive resolver audit passes.

For each row:

1. Set the liturgical region in Settings.
2. Set the Bible version where selectable.
3. Navigate to the date in Browse/Mass readings.
4. Verify celebration title, reading references, psalm/acclamation presence, and visible text.
5. Capture XML and screenshot to `verification/comprehensive-readings-audit/`.

| Date | Region | Version | Expected focus |
| --- | --- | --- | --- |
| 2026-07-15 | General Roman | RSVCE | Ordinary weekday has first reading, psalm, gospel |
| 2026-08-15 | United States | NABRE | Assumption propers |
| 2026-10-01 | Nigeria | RSVCE | Our Lady, Queen of Nigeria / regional handling |
| 2027-05-13 | United States - Ascension Thursday | NABRE | Ascension on Thursday |
| 2027-05-16 | United States | NABRE | Transferred Ascension profile |
| 2027-05-16 | England & Wales | RSVCE | Region transfer behavior visible |
| 2030-12-25 | England & Wales | RSVCE | Christmas propers beyond 2026 |
```

- [ ] **Step 2: Launch the app on the emulator**

Run:

```powershell
flutter run -d emulator-5554
```

Expected: app launches on `emulator-5554`. Leave the session running only while actively testing; stop it before final completion.

- [ ] **Step 3: Capture representative UI state**

For the Nigeria RSVCE row, run:

```powershell
adb exec-out uiautomator dump /dev/tty > verification/comprehensive-readings-audit/emulator-2026-10-01-nigeria-rsvce.xml
adb exec-out screencap -p > verification/comprehensive-readings-audit/emulator-2026-10-01-nigeria-rsvce.png
```

For the remaining rows, use the same lowercase naming style from the checklist table, for example `emulator-2027-05-13-us-ascension-thursday-nabre.xml`.

- [ ] **Step 4: Commit the checklist update**

Run:

```powershell
git add test/QA_REGRESSION_CHECKLIST.md
git commit -m "docs: add readings emulator QA matrix"
```

Generated XML/PNG captures may remain uncommitted unless the project convention requires committing verification artifacts.

## Task 8: Final Verification Sweep

**Files:**
- No new files unless fixing failures from verification.

- [ ] **Step 1: Run focused tests**

Run:

```powershell
flutter test test/data/services/bible_source_registry_test.dart test/data/services/bible_text_backend_version_test.dart test/data/services/comprehensive_resolver_audit_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run existing related tests**

Run:

```powershell
flutter test test/data/services/resolver_randomized_dates_test.dart test/data/services/resolver_special_days_test.dart test/data/services/liturgical_region_rules_test.dart test/data/services/nigeria_missal_audit_test.dart test/data/services/ascension_2026_collision_test.dart
```

Expected: PASS. If `nigeria_missal_audit_test.dart` fails due to pre-existing dirty user edits, inspect the diff and coordinate before changing those files.

- [ ] **Step 3: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: PASS or only known pre-existing warnings documented in the completion notes.

- [ ] **Step 4: Check git status**

Run:

```powershell
git status --short
```

Expected: only intentional changes remain. Do not revert unrelated dirty files.

- [ ] **Step 5: Final commit if needed**

If verification required small follow-up fixes, inspect status and commit only those exact files:

```powershell
git status --short
git add test/data/services/comprehensive_resolver_audit_test.dart
git commit -m "fix: resolve comprehensive readings audit findings"
```

If the follow-up touched a different exact file, substitute the specific path shown by `git status --short`; never run a broad add in this dirty worktree.

## Plan Self-Review

- Spec coverage: Tasks 1-3 cover Bible text backend extensibility; Tasks 4-6 cover deterministic automated audit and documentation outputs; Task 7 covers emulator validation; Task 8 covers final verification.
- Red-flag scan: No task uses unresolved marker text, generic "add tests", or unspecified implementation steps. Variable audit artifacts use concrete naming examples and require exact paths before staging.
- Type consistency: `BibleSource`, `BibleSourceStorage`, `BibleSourceRedistribution`, `BibleSourceRegistry`, `comprehensiveAuditDates`, `comprehensiveAuditRegions`, `AuditFailureKind`, and `ResolverAuditFailure` are defined before use.
