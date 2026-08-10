import 'package:catholic_daily/data/models/saint_profile.dart';
import 'package:catholic_daily/data/services/saint_profile_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final validator = SaintProfileValidator();

  test('accepts a complete, reviewed, source-linked published profile', () {
    final issues = validator.validateProfile(_profile());

    expect(issues.where((issue) => issue.isError), isEmpty);
  });

  test('reports missing required guide content and source links', () {
    final json = _profileJson();
    json['prayer'] = '';
    final life = json['life']! as Map<String, Object?>;
    final sections = life['sections']! as List<Object?>;
    (sections.single! as Map<String, Object?>)['sourceIds'] = <String>[];

    final codes = _codes(
      validator.validateProfile(SaintProfile.fromJson(json)),
    );

    expect(codes, containsAll(['missing_required', 'missing_source']));
  });

  test('rejects life span for a profile kind where it is not applicable', () {
    final json = _profileJson();
    json['profileKind'] = 'angelic';
    json['lifeSpan'] = 'Before the creation of the world';

    expect(
      _codes(validator.validateProfile(SaintProfile.fromJson(json))),
      contains('forbidden_field'),
    );
  });

  test('rejects placeholder, malformed, mojibake, and unknown sources', () {
    final json = _profileJson();
    json['name'] = 'Saint BrÃ©beuf';
    json['briefBio'] = 'Profile available offline.';
    json['whyItMatters'] = 'A malformed control character: \u0001';
    final virtues = json['virtues']! as List<Object?>;
    (virtues.single! as Map<String, Object?>)['sourceIds'] = ['not-a-source'];

    final codes = _codes(
      validator.validateProfile(SaintProfile.fromJson(json)),
    );

    expect(
      codes,
      containsAll([
        'placeholder_text',
        'malformed_text',
        'mojibake',
        'unknown_source_id',
      ]),
    );
  });

  test('requires verifiable quote and complete image attribution', () {
    final json = _profileJson();
    json['quote'] = {
      'text': 'An attractive but unsourced quotation.',
      'attribution': 'Saint Sample',
      'sourceId': '',
    };
    final image = json['image']! as Map<String, Object?>;
    image['creator'] = '';
    image['sourceUrl'] = '';

    final codes = _codes(
      validator.validateProfile(SaintProfile.fromJson(json)),
    );

    expect(
      codes,
      containsAll(['unverified_quote', 'missing_image_attribution']),
    );
  });

  test('requires valid publication review metadata', () {
    final json = _profileJson();
    json['editorial'] = {
      'state': 'published',
      'researcher': '',
      'reviewer': '',
      'reviewedAt': '',
      'revision': 0,
      'warnings': ['Needs theological review'],
    };

    expect(
      _codes(validator.validateProfile(SaintProfile.fromJson(json))),
      contains('invalid_publication_state'),
    );
  });

  test('reports duplicate IDs and celebration IDs across the corpus', () {
    final first = _profile();
    final secondJson = _profileJson(id: 'another_saint');
    secondJson['celebrationIds'] = ['sample_saint'];

    final codes = _codes(
      validator.validateCorpus([
        first,
        first,
        SaintProfile.fromJson(secondJson),
      ]),
    );

    expect(codes, containsAll(['duplicate_id', 'duplicate_celebration_id']));
  });

  test('reports long repeated content across different profiles', () {
    const repeated =
        'This source-grounded account is deliberately long enough to identify '
        'an accidental repeated editorial template across two distinct saints.';
    final firstJson = _profileJson();
    final secondJson = _profileJson(id: 'another_saint');
    secondJson['celebrationIds'] = ['another_saint'];
    firstJson['oneMinuteSummary'] = repeated;
    secondJson['oneMinuteSummary'] = '  ${repeated.toUpperCase()}  ';

    expect(
      _codes(
        validator.validateCorpus([
          SaintProfile.fromJson(firstJson),
          SaintProfile.fromJson(secondJson),
        ]),
      ),
      contains('duplicate_content'),
    );
  });
}

Set<String> _codes(List<SaintProfileIssue> issues) =>
    issues.map((issue) => issue.code).toSet();

SaintProfile _profile() => SaintProfile.fromJson(_profileJson());

Map<String, dynamic> _profileJson({String id = 'sample_saint'}) => {
  'schemaVersion': 2,
  'id': id,
  'profileKind': 'individual',
  'celebrationIds': [id],
  'name': 'Saint Sample',
  'alternateNames': ['Sample of Rome'],
  'ecclesialTitle': 'Religious',
  'lifeSpan': '1900-1970',
  'lifeLength': '70 years',
  'vocation': 'Service to people in need',
  'places': ['Rome'],
  'patronage': ['reconciliation'],
  'symbols': ['lamp'],
  'briefBio': 'A concise account of a life shaped by mercy and service.',
  'feastDates': ['January 2'],
  'historicalCertainty': 'documented',
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
    'sourceUrl': 'https://example.org/image',
    'license': 'CC BY-SA 4.0',
    'creditLine': 'Example Artist / CC BY-SA 4.0',
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
  'whyItMatters': 'Saint Sample chose mercy when retaliation was easier.',
  'oneMinuteSummary':
      'A concise, source-grounded summary of the saint and mission.',
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
  'prayer':
      'God of mercy, teach us to receive and offer your forgiveness through Christ our Lord. Amen.',
  'quote': {
    'text': 'Verified words from the saint.',
    'attribution': 'Saint Sample',
    'sourceId': 'official-biography',
  },
};
