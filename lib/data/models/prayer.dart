class Prayer {
  final int id;
  final String slug;
  final String title;
  final String firstLine;
  final String category;
  final List<String> text;
  final String? sourceFile;
  final String? htmlContent;

  const Prayer({
    required this.id,
    required this.slug,
    required this.title,
    required this.firstLine,
    required this.category,
    required this.text,
    this.sourceFile,
    this.htmlContent,
  });

  factory Prayer.fromMap(Map<String, dynamic> map) {
    return Prayer(
      id: (map['id'] as num?)?.toInt() ?? 0,
      slug: map['slug']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      firstLine: map['first_line']?.toString() ?? map['firstLine']?.toString() ?? '',
      category: map['category']?.toString() ?? 'prayer',
      text: List<String>.from(map['text'] ?? const []),
      sourceFile: map['source_file']?.toString() ?? map['sourceFile']?.toString(),
      htmlContent: map['html_content']?.toString() ?? map['htmlContent']?.toString(),
    );
  }

  String get displayText => text.join('\n\n');

  Prayer copyWith({
    int? id,
    String? slug,
    String? title,
    String? firstLine,
    String? category,
    List<String>? text,
    String? sourceFile,
    String? htmlContent,
  }) {
    return Prayer(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      firstLine: firstLine ?? this.firstLine,
      category: category ?? this.category,
      text: text ?? this.text,
      sourceFile: sourceFile ?? this.sourceFile,
      htmlContent: htmlContent ?? this.htmlContent,
    );
  }
}
