import '../../tool/saint_research_queue.dart';
import 'package:test/test.dart';

void main() {
  test('queue preserves legacy order across migration states', () {
    final result = SaintResearchQueue.compute(
      legacyIds: const ['a', 'b', 'c'],
      indexedProfiles: const [
        IndexedSaintProfile(id: 'b', state: 'researched'),
        IndexedSaintProfile(id: 'a', state: 'published'),
      ],
    );

    expect(result.published, ['a']);
    expect(result.inProgress, ['b']);
    expect(result.remaining, ['c']);
    expect(result.unknownIndexedIds, isEmpty);
  });

  test('queue reports duplicate and unknown indexed ids', () {
    final result = SaintResearchQueue.compute(
      legacyIds: const ['a'],
      indexedProfiles: const [
        IndexedSaintProfile(id: 'x', state: 'published'),
        IndexedSaintProfile(id: 'x', state: 'published'),
      ],
    );

    expect(result.duplicateIndexedIds, ['x']);
    expect(result.unknownIndexedIds, ['x']);
    expect(result.isComplete, isFalse);
  });

  test('queue does not treat duplicate published entries as completion', () {
    final result = SaintResearchQueue.compute(
      legacyIds: const ['a', 'b'],
      indexedProfiles: const [
        IndexedSaintProfile(id: 'a', state: 'published'),
        IndexedSaintProfile(id: 'b', state: 'published'),
        IndexedSaintProfile(id: 'b', state: 'published'),
      ],
    );

    expect(result.published, ['a', 'b']);
    expect(result.duplicateIndexedIds, ['b']);
    expect(result.isComplete, isFalse);
  });

  group('research dossier gate', () {
    const profileSources = {'source-one', 'source-two'};

    test('accepts populated ledgers whose source IDs match the profile', () {
      expect(
        SaintResearchDossierGate.isValid(
          text: _dossier(
            sourceRows: const [
              '| source-one | 1 | Institution A | Title A | Publisher A | https://example.com/a | 2026-08-10 | Original synthesis |',
              '| source-two | 2 | Institution B | Title B | Publisher B | https://example.com/b | 2026-08-10 | Factual cross-check |',
            ],
            claimRows: const [
              '| identity | The identity is reconciled. | source-one; source-two | High | Sources agree. |',
            ],
          ),
          profileId: 'sample_saint',
          profileSourceIds: profileSources,
        ),
        isTrue,
      );
    });

    test('rejects empty source and claim table shells', () {
      expect(
        SaintResearchDossierGate.isValid(
          text: _dossier(),
          profileId: 'sample_saint',
          profileSourceIds: profileSources,
        ),
        isFalse,
      );
    });

    test('rejects ledger IDs that do not exactly match the profile', () {
      expect(
        SaintResearchDossierGate.isValid(
          text: _dossier(
            sourceRows: const [
              '| source-one | 1 | Institution A | Title A | Publisher A | https://example.com/a | 2026-08-10 | Original synthesis |',
              '| unknown-source | 2 | Institution B | Title B | Publisher B | https://example.com/b | 2026-08-10 | Factual cross-check |',
            ],
            claimRows: const [
              '| identity | The identity is reconciled. | source-one; unknown-source | High | Sources agree. |',
            ],
          ),
          profileId: 'sample_saint',
          profileSourceIds: profileSources,
        ),
        isFalse,
      );
    });

    test('rejects malformed tier, date, certainty, and claim references', () {
      expect(
        SaintResearchDossierGate.isValid(
          text: _dossier(
            sourceRows: const [
              '| source-one | primary | Institution A | Title A | Publisher A | https://example.com/a | yesterday | Original synthesis |',
              '| source-two | 2 | Institution B | Title B | Publisher B | https://example.com/b | 2026-08-10 | Factual cross-check |',
            ],
            claimRows: const [
              '| identity | The identity is reconciled. | missing-source | Certain | Sources agree. |',
            ],
          ),
          profileId: 'sample_saint',
          profileSourceIds: profileSources,
        ),
        isFalse,
      );
    });
  });
}

String _dossier({
  List<String> sourceRows = const [],
  List<String> claimRows = const [],
}) =>
    '''
# Sample Saint

## Identity resolution

- Stable ID: `sample_saint`
- Profile kind: Individual
- Celebration IDs: `sample_saint`
- Canonical name and aliases: Sample Saint
- Feast date and calendar scope: January 1; universal
- Identity conflicts resolved: Sources agree on the identity.

## Source ledger

| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|
${sourceRows.join('\n')}

## Claim ledger

| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|
${claimRows.join('\n')}

## Copyright and media decision

All prose is original and no unlicensed media is included.

## Content review

The content review verified chronology, tone, practical benefit, and source support. ${'review ' * 25}

## Theological review

The theological review verified Christ-centered devotion and appropriate distinctions. ${'theology ' * 25}

## Final validation

The profile received separate factual and theological review before publication. ${'validation ' * 25}
''';
