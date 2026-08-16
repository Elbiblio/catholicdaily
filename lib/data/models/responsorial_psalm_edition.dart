enum ResponsorialPsalmSourceKind { lectionary, bible, psalter }

class ResponsorialPsalmEdition {
  final String id;
  final String displayName;
  final String abbreviation;
  final ResponsorialPsalmSourceKind sourceKind;
  final List<String> territories;
  final String coverageStatus;
  final String packAsset;
  final bool isInstalled;
  final bool isDownloadable;
  final String sourceUrl;
  final String fallbackRole;
  final int selectionCount;

  const ResponsorialPsalmEdition({
    required this.id,
    required this.displayName,
    required this.abbreviation,
    required this.sourceKind,
    required this.territories,
    required this.coverageStatus,
    required this.packAsset,
    required this.isInstalled,
    required this.isDownloadable,
    required this.sourceUrl,
    this.fallbackRole = 'none',
    this.selectionCount = 0,
  });

  factory ResponsorialPsalmEdition.fromJson(Map<String, dynamic> json) {
    return ResponsorialPsalmEdition(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      abbreviation: json['abbreviation'] as String,
      sourceKind: ResponsorialPsalmSourceKind.values.firstWhere(
        (value) => value.name == json['sourceKind'],
      ),
      territories: List<String>.from(json['territories'] as List? ?? const []),
      coverageStatus: json['coverageStatus'] as String? ?? 'unavailable',
      packAsset: json['packAsset'] as String? ?? '',
      isInstalled: json['installed'] as bool? ?? false,
      isDownloadable: json['downloadable'] as bool? ?? false,
      sourceUrl: json['sourceUrl'] as String? ?? '',
      fallbackRole: json['fallbackRole'] as String? ?? 'none',
      selectionCount: json['selectionCount'] as int? ?? 0,
    );
  }
}
