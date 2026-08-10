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
      id: 'douay_rheims',
      displayName: 'Douay-Rheims Bible',
      abbreviation: 'DR',
      storage: BibleSourceStorage.userProvidedLocal,
      redistribution: BibleSourceRedistribution.userProvidedOnly,
      assetDbName: 'engdra.db',
      downloadTableName: 'engdra_vpl',
      sourceUrl: 'https://api.elbiblio.com/dbs/engdra.db',
      attribution:
          'Downloaded on demand from the eBible.org VPL database mirror.',
      regionAffinityCodes: ['general', 'NG'],
      catholicCanon: true,
    ),
    BibleSource(
      id: 'esvce',
      displayName: 'English Standard Version Catholic Edition',
      abbreviation: 'ESV-CE',
      storage: BibleSourceStorage.externalOnly,
      redistribution: BibleSourceRedistribution.externalOnly,
      sourceUrl:
          'https://www.liturgyoffice.org.uk/Resources/Lectionary/LM-FAQ.shtml',
      attribution:
          'Prepared metadata for England and Wales lectionary comparison. Full text is not bundled without a verified redistribution basis.',
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
      attribution:
          'Prepared metadata for reference comparison. Full text is not bundled without a verified redistribution basis.',
      regionAffinityCodes: ['general', 'GB_EW', 'NG'],
      catholicCanon: true,
    ),
  ];

  List<BibleSource> get allSources => List.unmodifiable(_sources);

  List<BibleSource> get selectableBundledSources => _sources
      .where((source) => source.isBundledRenderable)
      .toList(growable: false);

  List<BibleSource> get downloadableLocalSources => _sources
      .where((source) => source.isDownloadableLocal && source.catholicCanon)
      .toList(growable: false);

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
