import 'package:catholic_daily/data/models/saint_profile.dart';
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

    expect(
      HistoricalCertainty.fromJson('documented'),
      HistoricalCertainty.documented,
    );
    expect(source.tier, SaintSourceTier.primary);
    expect(source.supports, contains('life.turning_point'));
    expect(image.license, 'CC BY-SA 4.0');
    expect(editorial.state, SaintEditorialState.published);
    expect(editorial.reviewedAt, DateTime(2026, 8, 10));
  });

  test('parses the complete spiritual life guide', () {
    final profile = SaintProfile.fromJson(_researchedProfileJson());

    expect(profile.kind, SaintProfileKind.individual);
    expect(profile.alternateNames, ['Sample of Rome']);
    expect(profile.ecclesialTitle, 'Religious');
    expect(profile.vocation, 'Service to people in need');
    expect(profile.places, ['Rome']);
    expect(profile.symbols, ['lamp']);
    expect(profile.historicalCertainty, HistoricalCertainty.documented);
    expect(profile.guide?.virtues.single.name, 'Mercy');
    expect(profile.guide?.reflectionQuestions, hasLength(2));
    expect(profile.sources.single.tier, SaintSourceTier.primary);
    expect(profile.isPublished, isTrue);
    expect(profile.hasFullGuide, isTrue);
  });

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
    expect(profile.sources.join(', '), 'Legacy source');
    expect(profile.editorial.state, SaintEditorialState.draft);
    expect(profile.hasFullGuide, isFalse);
    expect(profile.isPublished, isFalse);
  });
}

Map<String, Object?> _researchedProfileJson() => {
  'schemaVersion': 2,
  'id': 'sample_saint',
  'profileKind': 'individual',
  'celebrationIds': ['sample_saint'],
  'name': 'Saint Sample',
  'alternateNames': ['Sample of Rome'],
  'ecclesialTitle': 'Religious',
  'lifeSpan': '1900–1970',
  'lifeLength': '70 years',
  'vocation': 'Service to people in need',
  'places': ['Rome'],
  'patronage': ['reconciliation'],
  'symbols': ['lamp'],
  'feastDates': ['January 2'],
  'historicalCertainty': 'documented',
  ..._provenanceFields(),
  'whyItMatters': 'Saint Sample chose mercy when retaliation was easier.',
  'oneMinuteSummary':
      'A concise, source-grounded summary of the life and mission.',
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
