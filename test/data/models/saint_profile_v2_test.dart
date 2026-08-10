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
