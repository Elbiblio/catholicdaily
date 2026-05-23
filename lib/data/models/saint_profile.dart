class SaintProfile {
  final String id;
  final List<String> celebrationIds;
  final String name;
  final String lifeSpan;
  final String lifeLength;
  final List<String> patronage;
  final String briefBio;
  final String? wikipediaUrl;
  final String? wikidataId;
  final List<String> feastDates;
  final List<String> sources;

  const SaintProfile({
    required this.id,
    required this.celebrationIds,
    required this.name,
    required this.lifeSpan,
    required this.lifeLength,
    required this.patronage,
    required this.briefBio,
    this.wikipediaUrl,
    this.wikidataId,
    required this.feastDates,
    required this.sources,
  });

  factory SaintProfile.fromJson(Map<String, dynamic> json) {
    return SaintProfile(
      id: json['id'] as String,
      celebrationIds: _stringList(json['celebrationIds']),
      name: json['name'] as String,
      lifeSpan: json['lifeSpan'] as String? ?? '',
      lifeLength: json['lifeLength'] as String? ?? '',
      patronage: _stringList(json['patronage']),
      briefBio: json['briefBio'] as String? ?? '',
      wikipediaUrl: json['wikipediaUrl'] as String?,
      wikidataId: json['wikidataId'] as String?,
      feastDates: _stringList(json['feastDates']),
      sources: _stringList(json['sources']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  bool get hasWikipediaLink =>
      wikipediaUrl != null && wikipediaUrl!.trim().isNotEmpty;

  bool get hasLifeInfo => lifeSpan.isNotEmpty || lifeLength.isNotEmpty;
}
