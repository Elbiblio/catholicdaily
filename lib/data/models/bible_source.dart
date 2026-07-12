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
