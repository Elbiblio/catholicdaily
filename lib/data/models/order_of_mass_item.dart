class OrderOfMassItem {
  final String id;
  final String title;
  final String insertionPoint;
  final int order;
  final String? prayerSlug;
  final Map<String, List<String>>? contentByLanguage;
  final List<String> availableLanguages;
  final List<String> conditions;
  final bool isOptional;
  final String? type;
  final String? source;
  final String? sourceField;
  final String? role;
  final bool isDialogue;
  final bool isResponsive;
  final String? alternativeGroup;

  const OrderOfMassItem({
    required this.id,
    required this.title,
    required this.insertionPoint,
    required this.order,
    this.prayerSlug,
    this.contentByLanguage,
    required this.availableLanguages,
    required this.conditions,
    required this.isOptional,
    this.type,
    this.source,
    this.sourceField,
    this.role,
    this.isDialogue = false,
    this.isResponsive = false,
    this.alternativeGroup,
  });

  factory OrderOfMassItem.fromMap(Map<String, dynamic> map) {
    final rawContent = map['contentByLanguage'];
    Map<String, List<String>>? parsedContent;
    if (rawContent is Map) {
      parsedContent = rawContent.map(
        (key, value) => MapEntry(
          key.toString(),
          List<String>.from((value as List).map((item) => item.toString())),
        ),
      );
    }

    final parsedLanguages = map['availableLanguages'] is List
        ? List<String>.from((map['availableLanguages'] as List).map((item) => item.toString()))
        : <String>[];

    final parsedConditions = map['conditions'] is List
        ? List<String>.from((map['conditions'] as List).map((item) => item.toString()))
        : <String>['always'];

    return OrderOfMassItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      insertionPoint: map['insertionPoint']?.toString() ?? 'after_readings',
      order: (map['order'] as num?)?.toInt() ?? 0,
      prayerSlug: map['prayerSlug']?.toString(),
      contentByLanguage: parsedContent,
      availableLanguages: parsedLanguages,
      conditions: parsedConditions,
      isOptional: map['isOptional'] == true,
      type: map['type']?.toString(),
      source: map['source']?.toString(),
      sourceField: map['sourceField']?.toString(),
      role: map['role']?.toString(),
      isDialogue: map['isDialogue'] == true,
      isResponsive: map['isResponsive'] == true,
      alternativeGroup: map['alternativeGroup']?.toString(),
    );
  }

  bool get hasInlineContent => contentByLanguage != null && contentByLanguage!.isNotEmpty;
}
