import 'saint_profile_source.dart';

class SaintLifeSection {
  const SaintLifeSection({
    required this.heading,
    required this.body,
    required this.sourceIds,
  });

  factory SaintLifeSection.fromJson(Map<String, dynamic> json) {
    return SaintLifeSection(
      heading: json['heading'] as String? ?? '',
      body: json['body'] as String? ?? '',
      sourceIds: stringList(json['sourceIds']),
    );
  }

  final String heading;
  final String body;
  final List<String> sourceIds;
}

class SaintVirtue {
  const SaintVirtue({
    required this.name,
    required this.evidence,
    required this.imitation,
    required this.sourceIds,
  });

  factory SaintVirtue.fromJson(Map<String, dynamic> json) {
    return SaintVirtue(
      name: json['name'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
      imitation: json['imitation'] as String? ?? '',
      sourceIds: stringList(json['sourceIds']),
    );
  }

  final String name;
  final String evidence;
  final String imitation;
  final List<String> sourceIds;
}

class SaintPractice {
  const SaintPractice({required this.spiritual, required this.action});

  factory SaintPractice.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const <String, dynamic>{};
    return SaintPractice(
      spiritual: value['spiritual'] as String? ?? '',
      action: value['action'] as String? ?? '',
    );
  }

  final String spiritual;
  final String action;
}

class SaintScriptureCompanion {
  const SaintScriptureCompanion({
    required this.reference,
    required this.connection,
  });

  factory SaintScriptureCompanion.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const <String, dynamic>{};
    return SaintScriptureCompanion(
      reference: value['reference'] as String? ?? '',
      connection: value['connection'] as String? ?? '',
    );
  }

  final String reference;
  final String connection;
}

class SaintVerifiedQuote {
  const SaintVerifiedQuote({
    required this.text,
    required this.attribution,
    required this.sourceId,
  });

  factory SaintVerifiedQuote.fromJson(Map<String, dynamic> json) {
    return SaintVerifiedQuote(
      text: json['text'] as String? ?? '',
      attribution: json['attribution'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
    );
  }

  final String text;
  final String attribution;
  final String sourceId;
}

class SaintSpiritualGuide {
  const SaintSpiritualGuide({
    required this.whyItMatters,
    required this.oneMinuteSummary,
    required this.lifeSections,
    required this.gospelTheme,
    required this.struggle,
    required this.response,
    required this.virtues,
    required this.practice,
    required this.reflectionQuestions,
    required this.scripture,
    required this.prayer,
    required this.quote,
  });

  factory SaintSpiritualGuide.fromJson(Map<String, dynamic> json) {
    final life = json['life'] is Map<String, dynamic>
        ? json['life'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final sections = life['sections'];
    final virtues = json['virtues'];
    final quote = json['quote'];

    return SaintSpiritualGuide(
      whyItMatters: json['whyItMatters'] as String? ?? '',
      oneMinuteSummary: json['oneMinuteSummary'] as String? ?? '',
      lifeSections: sections is List
          ? sections
                .whereType<Map<String, dynamic>>()
                .map(SaintLifeSection.fromJson)
                .toList(growable: false)
          : const <SaintLifeSection>[],
      gospelTheme: life['gospelTheme'] as String? ?? '',
      struggle: life['struggle'] as String? ?? '',
      response: life['response'] as String? ?? '',
      virtues: virtues is List
          ? virtues
                .whereType<Map<String, dynamic>>()
                .map(SaintVirtue.fromJson)
                .toList(growable: false)
          : const <SaintVirtue>[],
      practice: SaintPractice.fromJson(
        json['practice'] as Map<String, dynamic>?,
      ),
      reflectionQuestions: stringList(json['reflectionQuestions']),
      scripture: SaintScriptureCompanion.fromJson(
        json['scripture'] as Map<String, dynamic>?,
      ),
      prayer: json['prayer'] as String? ?? '',
      quote: quote is Map<String, dynamic>
          ? SaintVerifiedQuote.fromJson(quote)
          : null,
    );
  }

  final String whyItMatters;
  final String oneMinuteSummary;
  final List<SaintLifeSection> lifeSections;
  final String gospelTheme;
  final String struggle;
  final String response;
  final List<SaintVirtue> virtues;
  final SaintPractice practice;
  final List<String> reflectionQuestions;
  final SaintScriptureCompanion scripture;
  final String prayer;
  final SaintVerifiedQuote? quote;
}
