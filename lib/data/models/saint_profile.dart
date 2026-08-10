import 'saint_profile_content.dart';
import 'saint_profile_source.dart';

enum SaintProfileKind {
  individual,
  group,
  biblical,
  angelic,
  marian,
  collective,
  observance;

  static SaintProfileKind fromJson(String? value) =>
      values.firstWhere((kind) => kind.name == value, orElse: () => individual);
}

class SaintProfile {
  final int schemaVersion;
  final String id;
  final List<String> celebrationIds;
  final SaintProfileKind kind;
  final String name;
  final List<String> alternateNames;
  final String ecclesialTitle;
  final String lifeSpan;
  final String lifeLength;
  final String vocation;
  final List<String> places;
  final List<String> patronage;
  final List<String> symbols;
  final String briefBio;
  final String? wikipediaUrl;
  final String? wikidataId;
  final List<String> feastDates;
  final HistoricalCertainty historicalCertainty;
  final List<SaintSource> sources;
  final SaintImageAttribution? image;
  final SaintEditorialMetadata editorial;
  final SaintSpiritualGuide? guide;

  const SaintProfile({
    this.schemaVersion = 1,
    required this.id,
    required this.celebrationIds,
    this.kind = SaintProfileKind.individual,
    required this.name,
    this.alternateNames = const [],
    this.ecclesialTitle = '',
    required this.lifeSpan,
    required this.lifeLength,
    this.vocation = '',
    this.places = const [],
    required this.patronage,
    this.symbols = const [],
    required this.briefBio,
    this.wikipediaUrl,
    this.wikidataId,
    required this.feastDates,
    this.historicalCertainty = HistoricalCertainty.mixed,
    required this.sources,
    this.image,
    this.editorial = const SaintEditorialMetadata(
      state: SaintEditorialState.draft,
      researcher: '',
      reviewer: '',
      reviewedAt: null,
      revision: 0,
      warnings: ['Legacy profile awaiting research'],
    ),
    this.guide,
  });

  factory SaintProfile.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? 1;
    final guide = schemaVersion >= 2
        ? SaintSpiritualGuide.fromJson(json)
        : null;
    final imageJson = json['image'];
    final editorialJson = json['editorial'];

    return SaintProfile(
      schemaVersion: schemaVersion,
      id: json['id'] as String,
      celebrationIds: stringList(json['celebrationIds']),
      kind: SaintProfileKind.fromJson(json['profileKind'] as String?),
      name: json['name'] as String,
      alternateNames: stringList(json['alternateNames']),
      ecclesialTitle: json['ecclesialTitle'] as String? ?? '',
      lifeSpan: json['lifeSpan'] as String? ?? '',
      lifeLength: json['lifeLength'] as String? ?? '',
      vocation: json['vocation'] as String? ?? '',
      places: stringList(json['places']),
      patronage: stringList(json['patronage']),
      symbols: stringList(json['symbols']),
      briefBio: json['briefBio'] as String? ?? guide?.oneMinuteSummary ?? '',
      wikipediaUrl: json['wikipediaUrl'] as String?,
      wikidataId: json['wikidataId'] as String?,
      feastDates: stringList(json['feastDates']),
      historicalCertainty: HistoricalCertainty.fromJson(
        json['historicalCertainty'] as String?,
      ),
      sources: _parseSources(json['sources']),
      image: imageJson is Map<String, dynamic>
          ? SaintImageAttribution.fromJson(imageJson)
          : null,
      editorial: schemaVersion >= 2
          ? SaintEditorialMetadata.fromJson(
              editorialJson is Map<String, dynamic> ? editorialJson : null,
            )
          : const SaintEditorialMetadata(
              state: SaintEditorialState.draft,
              researcher: '',
              reviewer: '',
              reviewedAt: null,
              revision: 0,
              warnings: ['Legacy profile awaiting research'],
            ),
      guide: guide,
    );
  }

  bool get hasWikipediaLink =>
      wikipediaUrl != null && wikipediaUrl!.trim().isNotEmpty;

  bool get hasLifeInfo => lifeSpan.isNotEmpty || lifeLength.isNotEmpty;

  bool get isPublished => editorial.state == SaintEditorialState.published;

  bool get hasFullGuide {
    final value = guide;
    if (value == null) return false;
    return value.whyItMatters.trim().isNotEmpty &&
        value.oneMinuteSummary.trim().isNotEmpty &&
        value.lifeSections.isNotEmpty &&
        value.lifeSections.every(
          (section) =>
              section.heading.trim().isNotEmpty &&
              section.body.trim().isNotEmpty,
        ) &&
        value.gospelTheme.trim().isNotEmpty &&
        value.struggle.trim().isNotEmpty &&
        value.response.trim().isNotEmpty &&
        value.virtues.isNotEmpty &&
        value.virtues.length <= 3 &&
        value.practice.spiritual.trim().isNotEmpty &&
        value.practice.action.trim().isNotEmpty &&
        value.reflectionQuestions.length == 2 &&
        value.reflectionQuestions.every(
          (question) => question.trim().isNotEmpty,
        ) &&
        value.scripture.reference.trim().isNotEmpty &&
        value.scripture.connection.trim().isNotEmpty &&
        value.prayer.trim().isNotEmpty;
  }

  static List<SaintSource> _parseSources(Object? value) {
    if (value is! List) return const [];
    final sources = <SaintSource>[];
    var legacyIndex = 0;
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        sources.add(SaintSource.fromJson(item));
      } else if (item is String) {
        legacyIndex++;
        sources.add(
          SaintSource(
            id: 'legacy-$legacyIndex',
            title: item,
            authorOrInstitution: '',
            publisher: '',
            url: null,
            publicationDate: null,
            accessedDate: null,
            tier: SaintSourceTier.discovery,
            reuseBasis: 'Legacy discovery source',
            supports: const [],
          ),
        );
      }
    }
    return List.unmodifiable(sources);
  }
}
