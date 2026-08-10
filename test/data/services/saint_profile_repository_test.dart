import 'dart:convert';

import 'package:catholic_daily/data/services/saint_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'v2 profile replaces the legacy record with the same stable id',
    () async {
      final assets = <String, String>{
        'legacy.json': jsonEncode([
          _legacyProfile('sample_saint'),
          _legacyProfile('second_saint'),
        ]),
        'index.json': jsonEncode({
          'schemaVersion': 2,
          'profiles': ['v2/sample_saint.json', 'v2/new_saint.json'],
        }),
        'v2/sample_saint.json': jsonEncode(_publishedProfile('sample_saint')),
        'v2/new_saint.json': jsonEncode(_publishedProfile('new_saint')),
      };
      final repository = SaintProfileRepository(
        legacyPath: 'legacy.json',
        indexPath: 'index.json',
        loadString: (path) async => assets[path]!,
      );

      final profiles = await repository.loadProfiles();

      expect(profiles.map((profile) => profile.id), [
        'sample_saint',
        'second_saint',
        'new_saint',
      ]);
      expect(profiles.first.isPublished, isTrue);
      expect(profiles[1].isPublished, isFalse);
    },
  );

  test('duplicate v2 paths fail closed', () async {
    final repository = SaintProfileRepository(
      legacyPath: 'legacy.json',
      indexPath: 'index.json',
      loadString: (path) async => switch (path) {
        'legacy.json' => '[]',
        'index.json' => '{"schemaVersion":2,"profiles":["a.json","a.json"]}',
        _ => '{}',
      },
    );

    expect(repository.loadProfiles(), throwsFormatException);
  });

  test('mismatched v2 schema fails closed', () async {
    final repository = SaintProfileRepository(
      legacyPath: 'legacy.json',
      indexPath: 'index.json',
      loadString: (path) async => switch (path) {
        'legacy.json' => '[]',
        'index.json' => '{"schemaVersion":2,"profiles":["a.json"]}',
        'a.json' => '{"schemaVersion":1,"id":"a"}',
        _ => '{}',
      },
    );

    expect(repository.loadProfiles(), throwsFormatException);
  });

  test('duplicate v2 stable ids fail closed', () async {
    final repository = SaintProfileRepository(
      legacyPath: 'legacy.json',
      indexPath: 'index.json',
      loadString: (path) async => switch (path) {
        'legacy.json' => '[]',
        'index.json' => '{"schemaVersion":2,"profiles":["a.json","b.json"]}',
        'a.json' => jsonEncode(_publishedProfile('same_id')),
        'b.json' => jsonEncode(_publishedProfile('same_id')),
        _ => '{}',
      },
    );

    expect(repository.loadProfiles(), throwsFormatException);
  });
}

Map<String, Object?> _legacyProfile(String id) => {
  'id': id,
  'celebrationIds': [id],
  'name': 'Saint $id',
  'briefBio': 'Legacy biography.',
  'patronage': ['legacy patronage'],
  'feastDates': ['January 2'],
  'sources': ['Legacy source'],
};

Map<String, Object?> _publishedProfile(String id) => {
  'schemaVersion': 2,
  'id': id,
  'profileKind': 'individual',
  'celebrationIds': [id],
  'name': 'Saint $id',
  'historicalCertainty': 'documented',
  'sources': [
    {
      'id': 'source-1',
      'title': 'Official biography',
      'authorOrInstitution': 'Example Diocese',
      'publisher': 'Example Diocese',
      'url': 'https://example.org/$id',
      'accessedDate': '2026-08-10',
      'tier': 1,
      'reuseBasis': 'Facts only; original synthesis',
      'supports': ['identity'],
    },
  ],
  'editorial': {
    'state': 'published',
    'researcher': 'Researcher',
    'reviewer': 'Reviewer',
    'reviewedAt': '2026-08-10',
    'revision': 1,
    'warnings': <String>[],
  },
};
