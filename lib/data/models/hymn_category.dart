class HymnCategory {
  final String id;
  final String name;
  final String description;
  final String? icon;
  final int hymnCount;
  final String? color;
  final List<String> subcategories;

  HymnCategory({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    this.hymnCount = 0,
    this.color,
    this.subcategories = const [],
  });

  HymnCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    int? hymnCount,
    String? color,
    List<String>? subcategories,
  }) {
    return HymnCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      hymnCount: hymnCount ?? this.hymnCount,
      color: color ?? this.color,
      subcategories: subcategories ?? this.subcategories,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'hymnCount': hymnCount,
      'color': color,
      'subcategories': subcategories,
    };
  }

  factory HymnCategory.fromMap(Map<String, dynamic> map) {
    return HymnCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'],
      hymnCount: (map['hymnCount'] ?? map['hymn_count'])?.toInt() ?? 0,
      color: map['color'],
      subcategories: List<String>.from(map['subcategories'] ?? []),
    );
  }
}
