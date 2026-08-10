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

  static SaintEditorialState fromJson(String? value) =>
      values.firstWhere((state) => state.name == value, orElse: () => draft);
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
      supports: stringList(json['supports']),
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
      warnings: stringList(value['warnings']),
    );
  }

  final SaintEditorialState state;
  final String researcher;
  final String reviewer;
  final DateTime? reviewedAt;
  final int revision;
  final List<String> warnings;
}

List<String> stringList(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const <String>[];
