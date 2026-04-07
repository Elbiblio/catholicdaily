class RichTextSpanModel {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  const RichTextSpanModel({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  factory RichTextSpanModel.fromMap(Map<String, dynamic> map) {
    return RichTextSpanModel(
      text: map['text']?.toString() ?? '',
      bold: map['bold'] == true,
      italic: map['italic'] == true,
      underline: map['underline'] == true,
    );
  }
}

class RichLineModel {
  final String text;
  final List<RichTextSpanModel> spans;

  const RichLineModel({
    required this.text,
    this.spans = const [],
  });

  bool get isEmpty => text.trim().isEmpty;

  factory RichLineModel.fromMap(Map<String, dynamic> map) {
    final rawSpans = map['spans'];
    final spans = rawSpans is List
        ? rawSpans
            .whereType<Map>()
            .map((item) => RichTextSpanModel.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : <RichTextSpanModel>[];

    return RichLineModel(
      text: map['text']?.toString() ?? spans.map((span) => span.text).join(),
      spans: spans,
    );
  }
}

class RichBlockModel {
  final String kind;
  final String? label;
  final int? number;
  final List<RichLineModel> lines;

  const RichBlockModel({
    required this.kind,
    this.label,
    this.number,
    this.lines = const [],
  });

  bool get isRefrain => kind == 'refrain';

  String? get heading {
    if (label != null && label!.trim().isNotEmpty) {
      return label!.trim();
    }
    if (number != null) {
      return '$number.';
    }
    return null;
  }

  List<String> get plainLines => lines.map((line) => line.text).where((line) => line.trim().isNotEmpty).toList();

  factory RichBlockModel.fromMap(Map<String, dynamic> map) {
    final rawLines = map['lines'];
    return RichBlockModel(
      kind: map['kind']?.toString() ?? 'paragraph',
      label: map['label']?.toString(),
      number: map['number'] is num ? (map['number'] as num).toInt() : null,
      lines: rawLines is List
          ? rawLines
              .whereType<Map>()
              .map((item) => RichLineModel.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }
}

class RichContentModel {
  final String sourceFormat;
  final List<RichBlockModel> blocks;

  const RichContentModel({
    required this.sourceFormat,
    this.blocks = const [],
  });

  bool get hasBlocks => blocks.isNotEmpty;

  List<String> toPlainLyrics() {
    final output = <String>[];
    for (final block in blocks) {
      final heading = block.heading;
      final lines = block.plainLines;
      if (lines.isEmpty) {
        continue;
      }
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (index == 0 && heading != null) {
          if (block.label != null) {
            output.add('$heading: $line');
          } else {
            output.add('$heading $line');
          }
        } else {
          output.add(line);
        }
      }
      output.add('');
    }
    while (output.isNotEmpty && output.last.isEmpty) {
      output.removeLast();
    }
    return output;
  }

  factory RichContentModel.fromMap(Map<String, dynamic> map) {
    final rawBlocks = map['blocks'];
    return RichContentModel(
      sourceFormat: map['source_format']?.toString() ?? map['sourceFormat']?.toString() ?? 'plain',
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map((item) => RichBlockModel.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }
}
