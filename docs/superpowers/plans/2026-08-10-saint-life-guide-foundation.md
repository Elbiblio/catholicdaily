# Saint Life Guide Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a versioned, source-aware saint content model and mobile life-guide UI while keeping all 158 legacy profiles readable during the editorial migration.

**Architecture:** Keep `assets/data/saints_profiles.json` as the legacy baseline and overlay researched v2 profiles listed by `assets/data/saints/index.json`. Parse identity, spiritual-guide, provenance, and editorial metadata into focused immutable models; validate the merged corpus before a profile can be treated as published. Render researched profiles with the new Life → Gospel → Practice → Prayer view and preserve the existing brief view for unmigrated profiles.

**Tech Stack:** Flutter/Dart 3.9, Material 3, bundled JSON assets, `rootBundle`, `flutter_test`, existing calendar/profile services.

---

## File responsibility map

- `lib/data/models/saint_profile.dart`: aggregate identity model, legacy compatibility, publication/full-guide helpers.
- `lib/data/models/saint_profile_content.dart`: life-guide value objects: narrative, virtues, practices, Scripture, prayer, quotation.
- `lib/data/models/saint_profile_source.dart`: source, certainty, image attribution, and editorial metadata.
- `lib/data/services/saint_profile_repository.dart`: load legacy corpus, load v2 index/files, overlay by stable ID, reject ambiguous index entries.
- `lib/data/services/saint_profile_service.dart`: celebration/title lookup over repository data; stable profile-ID lookup; no asset parsing responsibility.
- `lib/data/services/saint_profile_validator.dart`: pure validation and issue reporting for one profile or a corpus.
- `tool/validate_saint_profiles.dart`: command-line gate for local development and CI.
- `lib/ui/widgets/saint_profile/saint_life_guide_view.dart`: ordered researched-profile presentation.
- `lib/ui/widgets/saint_profile/saint_profile_section.dart`: accessible reusable section container.
- `lib/ui/widgets/saint_profile/saint_sources_sheet.dart`: provenance and attribution presentation.
- `lib/ui/screens/saint_detail_screen.dart`: asynchronous route shell, legacy/researched/error-state selection, external-link handling.
- `assets/data/saints/index.json`: schema version plus researched profile asset paths.
- `test/data/models/saint_profile_v2_test.dart`: v2 and legacy parsing tests.
- `test/data/services/saint_profile_repository_test.dart`: deterministic overlay and lookup tests.
- `test/data/services/saint_profile_validator_test.dart`: profile-kind, provenance, placeholder, Unicode, and duplication tests.
- `test/ui/screens/saint_detail_screen_test.dart`: researched, legacy, non-applicable-field, and accessibility rendering tests.

### Task 1: Add provenance and editorial value types

**Files:**
- Create: `lib/data/models/saint_profile_source.dart`
- Test: `test/data/models/saint_profile_v2_test.dart`

- [ ] **Step 1: Write the failing source-metadata parsing test**

```dart
import 'package:catholic_daily/data/models/saint_profile_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses source, certainty, image, and editorial metadata', () {
    final json = _provenanceFields();
    final source = SaintSource.fromJson(
      (json['sources'] as List).single as Map<String, dynamic>,
    );
    final image = SaintImageAttribution.fromJson(
      json['image'] as Map<String, dynamic>,
    );
    final editorial = SaintEditorialMetadata.fromJson(
      json['editorial'] as Map<String, dynamic>,
    );

    expect(HistoricalCertainty.fromJson('documented'), HistoricalCertainty.documented);
    expect(source.tier, SaintSourceTier.primary);
    expect(source.supports, contains('life.turning_point'));
    expect(image.license, 'CC BY-SA 4.0');
    expect(editorial.state, SaintEditorialState.published);
    expect(editorial.reviewedAt, DateTime(2026, 8, 10));
  });
}

Map<String, Object?> _provenanceFields() => {
  'sources': [
    {
      'id': 'official-biography',
      'title': 'Official Biography',
      'authorOrInstitution': 'Example Diocese',
      'publisher': 'Example Diocese',
      'url': 'https://example.org/saint',
      'accessedDate': '2026-08-10',
      'tier': 1,
      'reuseBasis': 'Facts only; original synthesis',
      'supports': ['identity', 'life.turning_point'],
    },
  ],
  'image': {
    'assetPath': 'assets/images/saints/sample_saint.jpg',
    'creator': 'Example Artist',
    'sourceUrl': 'https://commons.wikimedia.org/wiki/File:Example.jpg',
    'license': 'CC BY-SA 4.0',
    'creditLine': 'Example Artist / Wikimedia Commons / CC BY-SA 4.0',
    'isDerivative': false,
  },
  'editorial': {
    'state': 'published',
    'researcher': 'Catholic Daily editorial',
    'reviewer': 'Catholic Daily reviewer',
    'reviewedAt': '2026-08-10',
    'revision': 1,
    'warnings': <String>[],
  },
};
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/models/saint_profile_v2_test.dart`

Expected: FAIL because `saint_profile_source.dart` and the v2 fields do not exist.

- [ ] **Step 3: Implement the complete provenance types**

```dart
enum HistoricalCertainty {
  documented,
  reliablyTraditional,
  legendary,
  disputed,
  mixed;

  static HistoricalCertainty fromJson(String? value) => switch (value) {
    'documented' => documented,
    'reliablyTraditional' => reliablyTraditional,
    'legendary' => legendary,
    'disputed' => disputed,
    _ => mixed,
  };
}

enum SaintSourceTier {
  primary,
  scholarly,
  discovery;

  static SaintSourceTier fromJson(Object? value) => switch (value) {
    1 => primary,
    2 => scholarly,
    _ => discovery,
  };
}

enum SaintEditorialState {
  draft,
  researched,
  contentReviewed,
  theologicallyReviewed,
  published;

  static SaintEditorialState fromJson(String? value) => values.firstWhere(
    (state) => state.name == value,
    orElse: () => draft,
  );
}

class SaintSource {
  const SaintSource({
    required this.id,
    required this.title,
    required this.authorOrInstitution,
    required this.publisher,
    required this.url,
    required this.publicationDate,
    required this.accessedDate,
    required this.tier,
    required this.reuseBasis,
    required this.supports,
  });

  factory SaintSource.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['url'] as String? ?? '').trim();
    return SaintSource(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      authorOrInstitution: json['authorOrInstitution'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      url: rawUrl.isEmpty ? null : Uri.tryParse(rawUrl),
      publicationDate: json['publicationDate'] as String?,
      accessedDate: DateTime.tryParse(json['accessedDate'] as String? ?? ''),
      tier: SaintSourceTier.fromJson(json['tier']),
      reuseBasis: json['reuseBasis'] as String? ?? '',
      supports: _strings(json['supports']),
    );
  }

  final String id;
  final String title;
  final String authorOrInstitution;
  final String publisher;
  final Uri? url;
  final String? publicationDate;
  final DateTime? accessedDate;
  final SaintSourceTier tier;
  final String reuseBasis;
  final List<String> supports;
}

class SaintImageAttribution {
  const SaintImageAttribution({
    required this.assetPath,
    required this.creator,
    required this.sourceUrl,
    required this.license,
    required this.creditLine,
    required this.isDerivative,
  });

  factory SaintImageAttribution.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['sourceUrl'] as String? ?? '').trim();
    return SaintImageAttribution(
      assetPath: json['assetPath'] as String? ?? '',
      creator: json['creator'] as String? ?? '',
      sourceUrl: rawUrl.isEmpty ? null : Uri.tryParse(rawUrl),
      license: json['license'] as String? ?? '',
      creditLine: json['creditLine'] as String? ?? '',
      isDerivative: json['isDerivative'] as bool? ?? false,
    );
  }

  final String assetPath;
  final String creator;
  final Uri? sourceUrl;
  final String license;
  final String creditLine;
  final bool isDerivative;
}

class SaintEditorialMetadata {
  const SaintEditorialMetadata({
    required this.state,
    required this.researcher,
    required this.reviewer,
    required this.reviewedAt,
    required this.revision,
    required this.warnings,
  });

  factory SaintEditorialMetadata.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const <String, dynamic>{};
    return SaintEditorialMetadata(
      state: SaintEditorialState.fromJson(value['state'] as String?),
      researcher: value['researcher'] as String? ?? '',
      reviewer: value['reviewer'] as String? ?? '',
      reviewedAt: DateTime.tryParse(value['reviewedAt'] as String? ?? ''),
      revision: value['revision'] as int? ?? 0,
      warnings: _strings(value['warnings']),
    );
  }

  final SaintEditorialState state;
  final String researcher;
  final String reviewer;
  final DateTime? reviewedAt;
  final int revision;
  final List<String> warnings;
}

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const <String>[];
```

- [ ] **Step 4: Run formatting and the focused test**

Run: `dart format lib/data/models/saint_profile_source.dart test/data/models/saint_profile_v2_test.dart && flutter test test/data/models/saint_profile_v2_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the provenance types and passing test**

```powershell
git add lib/data/models/saint_profile_source.dart test/data/models/saint_profile_v2_test.dart
git commit -m "test: define saint profile provenance contract"
```

### Task 2: Add the structured spiritual-guide model and legacy compatibility

**Files:**
- Create: `lib/data/models/saint_profile_content.dart`
- Modify: `lib/data/models/saint_profile.dart`
- Modify: `lib/data/services/saint_profile_service.dart`
- Modify: `test/data/models/saint_profile_v2_test.dart`

- [ ] **Step 1: Extend the failing test with the spiritual-guide contract**

Add a `SaintProfile.fromJson(_researchedProfileJson())` test and define `_researchedProfileJson()` by combining these identity fields, `_provenanceFields()`, and the following spiritual fields:

```dart
Map<String, Object?> _researchedProfileJson() => {
  'schemaVersion': 2,
  'id': 'sample_saint',
  'profileKind': 'individual',
  'celebrationIds': ['sample_saint'],
  'name': 'Saint Sample',
  'historicalCertainty': 'documented',
  ..._provenanceFields(),
'whyItMatters': 'Saint Sample chose mercy when retaliation was easier.',
'oneMinuteSummary': 'A concise, source-grounded summary of the life and mission.',
'life': {
  'sections': [
    {
      'heading': 'A decisive choice',
      'body': 'A documented turning point written in original prose.',
      'sourceIds': ['official-biography'],
    },
  ],
  'gospelTheme': 'Mercy received becomes mercy offered.',
  'struggle': 'The saint faced a costly conflict.',
  'response': 'The saint responded through prayer and concrete charity.',
},
'virtues': [
  {
    'name': 'Mercy',
    'evidence': 'The documented turning point.',
    'imitation': 'Refuse one cycle of retaliation today.',
    'sourceIds': ['official-biography'],
  },
],
'practice': {
  'spiritual': 'Spend five minutes praying for someone difficult.',
  'action': 'Make one concrete act of reconciliation.',
},
'reflectionQuestions': [
  'Where am I tempted to retaliate?',
  'What would mercy require today?',
],
'scripture': {
  'reference': 'Luke 6:36',
  'connection': 'Jesus places mercy at the centre of discipleship.',
},
'prayer': 'God of mercy, teach us to receive and offer your forgiveness through Christ our Lord. Amen.',
'quote': {
  'text': 'Verified words from the saint.',
  'attribution': 'Saint Sample',
  'sourceId': 'official-biography',
},
};
```

```dart
expect(profile.kind, SaintProfileKind.individual);
expect(profile.guide?.virtues.single.name, 'Mercy');
expect(profile.guide?.reflectionQuestions, hasLength(2));
expect(profile.isPublished, isTrue);
expect(profile.hasFullGuide, isTrue);
```

- [ ] **Step 2: Run the test to verify the model contract fails**

Run: `flutter test test/data/models/saint_profile_v2_test.dart`

Expected: FAIL with missing `SaintProfileKind`, `guide`, and publication helpers.

- [ ] **Step 3: Implement `saint_profile_content.dart`**

Define immutable `SaintLifeSection`, `SaintVirtue`, `SaintPractice`, `SaintScriptureCompanion`, `SaintVerifiedQuote`, and `SaintSpiritualGuide` classes. Every class must expose a `fromJson(Map<String, dynamic>)` constructor, convert arrays with `whereType`, and default missing strings to empty strings. `SaintSpiritualGuide.fromJson` must read the exact keys introduced in Step 1 and preserve section and virtue `sourceIds`.

Use this public shape:

```dart
class SaintSpiritualGuide {
  const SaintSpiritualGuide({
    required this.whyItMatters,
    required this.oneMinuteSummary,
    required this.lifeSections,
    required this.gospelTheme,
    required this.struggle,
    required this.response,
    required this.virtues,
    required this.practice,
    required this.reflectionQuestions,
    required this.scripture,
    required this.prayer,
    required this.quote,
  });

  final String whyItMatters;
  final String oneMinuteSummary;
  final List<SaintLifeSection> lifeSections;
  final String gospelTheme;
  final String struggle;
  final String response;
  final List<SaintVirtue> virtues;
  final SaintPractice practice;
  final List<String> reflectionQuestions;
  final SaintScriptureCompanion scripture;
  final String prayer;
  final SaintVerifiedQuote? quote;
}
```

- [ ] **Step 4: Extend `SaintProfile` without breaking legacy callers**

Add `SaintProfileKind`, alternate names, vocation, places, symbols, certainty, structured sources, image, editorial metadata, and optional guide. Preserve the current `lifeSpan`, `lifeLength`, `briefBio`, `wikipediaUrl`, `wikidataId`, `feastDates`, and patronage getters/constructor arguments so the existing screen and tests compile during migration.

Use this exact profile-kind mapping:

```dart
enum SaintProfileKind {
  individual,
  group,
  biblical,
  angelic,
  marian,
  collective,
  observance;

  static SaintProfileKind fromJson(String? value) => values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => individual,
  );
}
```

Legacy JSON rules are exact:

```dart
final schemaVersion = json['schemaVersion'] as int? ?? 1;
final guide = schemaVersion >= 2 ? SaintSpiritualGuide.fromJson(json) : null;
final editorial = schemaVersion >= 2
    ? SaintEditorialMetadata.fromJson(json['editorial'] as Map<String, dynamic>?)
    : const SaintEditorialMetadata(
        state: SaintEditorialState.draft,
        researcher: '',
        reviewer: '',
        reviewedAt: null,
        revision: 0,
        warnings: ['Legacy profile awaiting research'],
      );
```

`isPublished` is true only for `SaintEditorialState.published`; `hasFullGuide` is true only when the guide exists and its required user-facing fields are non-empty. Convert legacy string sources into Tier 3 `SaintSource` records with stable IDs `legacy-1`, `legacy-2`, and so on.

Update `SaintProfileService.buildFallbackProfile` in the same step so its constructor uses one explicit Tier 3 `SaintSource` record for `Catholic Daily calendar`. This keeps the application compiling at the Task 2 commit boundary after `SaintProfile.sources` changes from strings to structured sources.

- [ ] **Step 5: Add an explicit legacy regression test**

```dart
test('legacy profiles remain readable but are not publishable', () {
  final profile = SaintProfile.fromJson({
    'id': 'legacy',
    'celebrationIds': ['legacy'],
    'name': 'Saint Legacy',
    'briefBio': 'Existing offline biography.',
    'patronage': ['travelers'],
    'feastDates': ['January 2'],
    'sources': ['Legacy source'],
  });

  expect(profile.briefBio, 'Existing offline biography.');
  expect(profile.sources.single.tier, SaintSourceTier.discovery);
  expect(profile.editorial.state, SaintEditorialState.draft);
  expect(profile.hasFullGuide, isFalse);
  expect(profile.isPublished, isFalse);
});
```

- [ ] **Step 6: Format and run model tests plus existing saint tests**

Run: `dart format lib/data/models/saint_profile*.dart test/data/models/saint_profile_v2_test.dart && flutter test test/data/models/saint_profile_v2_test.dart test/data/services/saint_profile_service_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit the model**

```powershell
git add lib/data/models/saint_profile.dart lib/data/models/saint_profile_content.dart lib/data/models/saint_profile_source.dart lib/data/services/saint_profile_service.dart test/data/models/saint_profile_v2_test.dart
git commit -m "feat: add structured saint life guide model"
```

### Task 3: Load researched v2 profiles as an overlay

**Files:**
- Create: `lib/data/services/saint_profile_repository.dart`
- Create: `assets/data/saints/index.json`
- Modify: `pubspec.yaml`
- Modify: `lib/data/services/saint_profile_service.dart`
- Test: `test/data/services/saint_profile_repository_test.dart`

- [ ] **Step 1: Write repository overlay tests with injected asset reads**

```dart
test('v2 profile replaces the legacy record with the same stable id', () async {
  final assets = <String, String>{
    'legacy.json': jsonEncode([_legacyProfile('sample_saint')]),
    'index.json': jsonEncode({
      'schemaVersion': 2,
      'profiles': ['v2/sample_saint.json'],
    }),
    'v2/sample_saint.json': jsonEncode(_publishedProfile('sample_saint')),
  };
  final repository = SaintProfileRepository(
    legacyPath: 'legacy.json',
    indexPath: 'index.json',
    loadString: (path) async => assets[path]!,
  );

  final profiles = await repository.loadProfiles();

  expect(profiles, hasLength(1));
  expect(profiles.single.id, 'sample_saint');
  expect(profiles.single.isPublished, isTrue);
});

test('duplicate v2 paths and mismatched schema fail closed', () async {
  final repository = SaintProfileRepository(
    legacyPath: 'legacy.json',
    indexPath: 'index.json',
    loadString: (path) async => path == 'legacy.json'
        ? '[]'
        : '{"schemaVersion":1,"profiles":["a.json","a.json"]}',
  );

  expect(repository.loadProfiles(), throwsFormatException);
});
```

- [ ] **Step 2: Run the repository test to verify failure**

Run: `flutter test test/data/services/saint_profile_repository_test.dart`

Expected: FAIL because `SaintProfileRepository` does not exist.

- [ ] **Step 3: Implement the repository**

Use `typedef SaintAssetLoader = Future<String> Function(String path);`. The default loader calls `rootBundle.loadString`; tests inject a map loader. Load the legacy array first, then require v2 index `schemaVersion == 2`, reject duplicate file paths, decode each file as one map, require its `schemaVersion == 2`, and replace the legacy map entry by stable ID while retaining legacy order. Append researched IDs that are not present in legacy data in index order. Cache only the fully successful merged result.

The production constants are:

```dart
static const legacyAssetPath = 'assets/data/saints_profiles.json';
static const indexAssetPath = 'assets/data/saints/index.json';
```

- [ ] **Step 4: Add the empty v2 index and asset directory**

```json
{
  "schemaVersion": 2,
  "profiles": []
}
```

Add `assets/data/saints/` to `pubspec.yaml`. Keep `assets/data/saints_profiles.json` until the final corpus migration task explicitly removes it.

- [ ] **Step 5: Delegate loading to the repository and add stable-ID lookup**

Change `SaintProfileService` to accept a repository in a visible-for-testing constructor, keep the singleton for production, remove direct `rootBundle` and JSON decoding, and build both `_byCelebrationId` and `_byId` indexes. Add:

```dart
Future<SaintProfile?> findById(String profileId) async {
  final profiles = await loadProfiles();
  _byId ??= {for (final profile in profiles) profile.id: profile};
  return _byId![profileId];
}
```

Retain `parseProfiles` temporarily by forwarding to a static legacy parser in the repository so existing tests do not lose coverage.

- [ ] **Step 6: Run repository and existing service tests**

Run: `dart format lib/data/services/saint_profile_repository.dart lib/data/services/saint_profile_service.dart test/data/services/saint_profile_repository_test.dart && flutter test test/data/services/saint_profile_repository_test.dart test/data/services/saint_profile_service_test.dart`

Expected: PASS with 158 legacy profiles when the v2 index is empty.

- [ ] **Step 7: Commit the overlay loader**

```powershell
git add assets/data/saints/index.json pubspec.yaml lib/data/services/saint_profile_repository.dart lib/data/services/saint_profile_service.dart test/data/services/saint_profile_repository_test.dart
git commit -m "feat: overlay researched saint profiles"
```

### Task 4: Add corpus validation and a command-line gate

**Files:**
- Create: `lib/data/services/saint_profile_validator.dart`
- Create: `tool/validate_saint_profiles.dart`
- Create: `test/data/services/saint_profile_validator_test.dart`

- [ ] **Step 1: Write failing validator tests**

Cover these exact issue codes: `duplicate_id`, `duplicate_celebration_id`, `missing_required`, `forbidden_field`, `placeholder_text`, `malformed_text`, `mojibake`, `duplicate_content`, `missing_source`, `unknown_source_id`, `unverified_quote`, `missing_image_attribution`, and `invalid_publication_state`.

```dart
test('published profile rejects placeholder, unknown source, and mojibake', () {
  final profile = publishedProfile().copyWith(
    name: 'Saint BrÃ©beuf',
    briefBio: 'Profile available offline.',
    guide: publishedProfile().guide!.copyWith(
      virtues: const [
        SaintVirtue(
          name: 'Courage',
          evidence: 'Documented event.',
          imitation: 'Do the right thing.',
          sourceIds: ['missing-source'],
        ),
      ],
    ),
  );

  final codes = SaintProfileValidator().validateProfile(profile).map(
    (issue) => issue.code,
  );

  expect(codes, containsAll(['mojibake', 'placeholder_text', 'unknown_source_id']));
});
```

- [ ] **Step 2: Run the validator tests to confirm failure**

Run: `flutter test test/data/services/saint_profile_validator_test.dart`

Expected: FAIL because the validator and copy helpers do not exist.

- [ ] **Step 3: Implement pure validation**

Create `SaintProfileIssue` with `severity`, `code`, `profileId`, `field`, and `message`. Validation must:

- require stable ID, celebration IDs, name, feast date, kind, certainty, and at least one source;
- require every full-guide field for published profiles;
- require one-to-three virtues, exactly two reflection questions, and a non-empty source linkage for life sections and virtue evidence;
- reject `lifeSpan` on `angelic`, `collective`, `marian`, and `observance` unless a kind-specific validation rule explicitly permits historical-period text outside that field;
- reject a quote whose source ID is absent;
- reject image objects missing creator, source URL, license, or credit line;
- scan user-facing strings for `\uFFFD`, `Ã`, `Â`, control characters, dangling date fragments, “profile available offline”, “fuller curated biography”, and repeated generic templates;
- normalize whitespace/case and flag long content repeated across two profiles;
- reject duplicate IDs or celebration IDs at corpus scope; and
- reject `published` if researcher, reviewer, reviewed date, revision, or warnings policy is invalid.

Add `copyWith` only to the value objects used by tests and UI state; do not add serialization or mutation APIs that the feature does not need.

- [ ] **Step 4: Implement `tool/validate_saint_profiles.dart`**

The tool reads the legacy file and v2 index from disk, overlays records exactly as the repository does, prints one line per issue as `severity profileId field code: message`, prints a final profile/error/warning count, and exits with code 1 if any error exists. It accepts `--published-only` to ignore warnings on unmigrated legacy records while still validating all published v2 records.

- [ ] **Step 5: Run validator tests and the migration-safe CLI mode**

Run: `dart format lib/data/services/saint_profile_validator.dart tool/validate_saint_profiles.dart test/data/services/saint_profile_validator_test.dart && flutter test test/data/services/saint_profile_validator_test.dart && dart run tool/validate_saint_profiles.dart --published-only`

Expected: tests PASS; CLI exits 0 with zero published profiles and reports the legacy profile count separately.

- [ ] **Step 6: Commit the validation gate**

```powershell
git add lib/data/services/saint_profile_validator.dart tool/validate_saint_profiles.dart test/data/services/saint_profile_validator_test.dart
git commit -m "feat: validate researched saint profiles"
```

### Task 5: Build the researched life-guide widgets

**Files:**
- Create: `lib/ui/widgets/saint_profile/saint_profile_section.dart`
- Create: `lib/ui/widgets/saint_profile/saint_life_guide_view.dart`
- Create: `lib/ui/widgets/saint_profile/saint_sources_sheet.dart`
- Create: `test/ui/screens/saint_detail_screen_test.dart`

- [ ] **Step 1: Write the researched-profile widget test**

Pump `SaintLifeGuideView(profile: publishedProfile())` inside a `MaterialApp` and assert the ordered headings `Why this saint matters today`, `In one minute`, `Their life and journey`, `The Gospel visible in their life`, `The struggle and response`, `Virtues to imitate`, `Live it today`, `Reflect`, `Scripture companion`, and `Prayer`. Assert that a verified quotation is shown only when non-null and that `SemanticsTester` finds header semantics for each section.

- [ ] **Step 2: Write conditional-kind widget tests**

Pump an angelic profile and a Marian profile. Assert that neither displays `Lived` or `Length`; both still render the applicable Gospel, reflection, Scripture, and prayer sections. Pump a long profile at text scale 2.0 in a 320×640 surface and call `tester.takeException()`; expect null after scrolling to the bottom.

- [ ] **Step 3: Run the widget tests to verify failure**

Run: `flutter test test/ui/screens/saint_detail_screen_test.dart`

Expected: FAIL because the widgets do not exist.

- [ ] **Step 4: Implement the reusable section and life-guide view**

`SaintProfileSection` accepts `title`, optional `icon`, and `child`, uses a semantic header, and never owns profile-specific logic. `SaintLifeGuideView` renders the approved section order, skips non-applicable empty optional fields, uses numbered virtue cards tied to evidence, distinguishes the spiritual practice from concrete action, and labels the prayer `A prayer from Catholic Daily`.

The view must expose callbacks rather than launching URLs itself:

```dart
class SaintLifeGuideView extends StatelessWidget {
  const SaintLifeGuideView({
    super.key,
    required this.profile,
    required this.onShowSources,
  });

  final SaintProfile profile;
  final VoidCallback onShowSources;
}
```

At the end, show patronage/symbols only when sourced and a `Sources and review` button containing the reviewed date and certainty label.

- [ ] **Step 5: Implement the sources sheet**

`SaintSourcesSheet.show(context, profile)` lists each source’s title, institution, tier label, and access date; URL rows call a supplied `ValueChanged<Uri>` callback. Show certainty, editorial revision/review date, warnings, and complete image credit. Do not render empty URLs as buttons.

- [ ] **Step 6: Format and run focused widget tests**

Run: `dart format lib/ui/widgets/saint_profile test/ui/screens/saint_detail_screen_test.dart && flutter test test/ui/screens/saint_detail_screen_test.dart`

Expected: PASS with no layout exception at 2.0 text scale.

- [ ] **Step 7: Commit the life-guide widgets**

```powershell
git add lib/ui/widgets/saint_profile test/ui/screens/saint_detail_screen_test.dart
git commit -m "feat: render saint spiritual life guides"
```

### Task 6: Integrate researched and legacy detail states

**Files:**
- Modify: `lib/ui/screens/saint_detail_screen.dart`
- Modify: `test/ui/screens/saint_detail_screen_test.dart`
- Modify: `test/widgets/todays_saint_card_test.dart`

- [ ] **Step 1: Add failing route-state tests**

Inject a `Future<SaintProfile?>` loader into `SaintDetailScreen` for tests. Assert:

- a published full guide renders `SaintLifeGuideView`;
- a legacy profile renders the existing `Brief Bio` body and a visible `Research in progress` note;
- a null profile renders `Profile unavailable` without offering a fabricated biography;
- a thrown load error renders a retry button; and
- tapping retry invokes a fresh loader future rather than reusing the failed future.

- [ ] **Step 2: Run the tests to verify failure**

Run: `flutter test test/ui/screens/saint_detail_screen_test.dart test/widgets/todays_saint_card_test.dart`

Expected: FAIL because the screen cannot inject/retry loading and does not select the new view.

- [ ] **Step 3: Refactor the detail screen shell**

Add an optional `SaintProfileLoader` parameter defaulting to `SaintProfileService.instance.findForCelebration`. Replace the `late final Future` with a retryable `_load()` method stored in state. Render:

```dart
if (profile == null) return _MissingProfile(...);
if (profile.isPublished && profile.hasFullGuide) {
  return SaintLifeGuideView(
    profile: profile,
    onShowSources: () => SaintSourcesSheet.show(
      context,
      profile,
      onOpenUrl: _openExternalUri,
    ),
  );
}
return _LegacyProfileBody(profile: profile, showResearchNotice: true);
```

Catch `snapshot.hasError` separately and keep all network/source links optional. Rename `Read More` to `Open reference article` so Wikipedia is not presented as the authoritative continuation of the profile.

- [ ] **Step 4: Preserve Today’s Saints navigation behavior**

Re-run the existing card callback test and add a detail-route smoke test from `PremiumBrowseScreen` using the current `OptionalCelebration`. No notification/deep-link behavior is added in this plan.

- [ ] **Step 5: Run all saint-focused tests**

Run: `dart format lib/ui/screens/saint_detail_screen.dart test/ui/screens/saint_detail_screen_test.dart && flutter test test/data/models/saint_profile_v2_test.dart test/data/services/saint_profile_repository_test.dart test/data/services/saint_profile_validator_test.dart test/data/services/saint_profile_service_test.dart test/ui/screens/saint_detail_screen_test.dart test/widgets/todays_saint_card_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit screen integration**

```powershell
git add lib/ui/screens/saint_detail_screen.dart test/ui/screens/saint_detail_screen_test.dart test/widgets/todays_saint_card_test.dart
git commit -m "feat: integrate researched saint detail states"
```

### Task 7: Run foundation verification

**Files:**
- Modify only if verification exposes a defect in files already listed above.

- [ ] **Step 1: Validate formatting and static analysis**

Run: `dart format --output=none --set-exit-if-changed lib/data/models/saint_profile*.dart lib/data/services/saint_profile*.dart lib/ui/widgets/saint_profile lib/ui/screens/saint_detail_screen.dart test/data/models/saint_profile_v2_test.dart test/data/services/saint_profile*_test.dart test/ui/screens/saint_detail_screen_test.dart`

Expected: exit 0.

Run: `flutter analyze`

Expected: no issues.

- [ ] **Step 2: Run the complete Flutter suite**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 3: Run the migration-safe content validator**

Run: `dart run tool/validate_saint_profiles.dart --published-only`

Expected: exit 0; 158 legacy records reported, zero invalid published profiles.

- [ ] **Step 4: Build Android debug**

Run: `flutter build apk --debug`

Expected: exit 0 and `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 5: Commit any verification-only correction**

If verification required a correction, stage only the foundation files, rerun the failing command and the focused suite, then commit:

```powershell
git commit -m "fix: stabilize saint life guide foundation"
```

If no correction was required, do not create an empty commit.
