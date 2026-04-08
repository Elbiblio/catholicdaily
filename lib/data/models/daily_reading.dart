/// Represents a daily reading for a specific date
class DailyReading {
  final int? id;
  final String reading;
  final String? position;
  final DateTime date;
  final String? feast;
  final String? psalmResponse;
  final String? gospelAcclamation;
  final String? incipit;
  final String? source;

  DailyReading({
    this.id,
    required this.reading,
    this.position,
    required this.date,
    this.feast,
    this.psalmResponse,
    this.gospelAcclamation,
    this.incipit,
    this.source,
  });

  DailyReading copyWith({
    int? id,
    String? reading,
    String? position,
    DateTime? date,
    String? feast,
    String? psalmResponse,
    String? gospelAcclamation,
    String? incipit,
    String? source,
  }) {
    return DailyReading(
      id: id ?? this.id,
      reading: reading ?? this.reading,
      position: position ?? this.position,
      date: date ?? this.date,
      feast: feast ?? this.feast,
      psalmResponse: psalmResponse ?? this.psalmResponse,
      gospelAcclamation: gospelAcclamation ?? this.gospelAcclamation,
      incipit: incipit ?? this.incipit,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reading': reading,
      'position': position,
      'date': date.toIso8601String(),
      'feast': feast,
      'psalm_response': psalmResponse,
      'gospel_acclamation': gospelAcclamation,
      'incipit': incipit,
      'source': source,
    };
  }

  factory DailyReading.fromMap(Map<String, dynamic> map) {
    return DailyReading(
      id: map['id'] as int?,
      reading: map['reading'] as String,
      position: map['position'] as String?,
      date: DateTime.parse(map['date'] as String),
      feast: map['feast'] as String?,
      psalmResponse: map['psalm_response'] as String?,
      gospelAcclamation: map['gospel_acclamation'] as String?,
      incipit: map['incipit'] as String?,
      source: map['source'] as String?,
    );
  }

  /// Parse reading reference to extract book, chapter, and verses
  ReadingReference? parseReference() {
    final regex = RegExp(
      r'((?:\d*\s)?(?:\S*))\s(\d+)?:(\d+)?-?(\d+)?(?:,?\s?(\d+)?:?(\d+)?-?(\d+)?)?',
    );
    final match = regex.firstMatch(reading);
    if (match == null || match.group(1) == null) return null;

    return ReadingReference(
      bookName: match.group(1)!,
      chapter: int.tryParse(match.group(2) ?? ''),
      startVerse: int.tryParse(match.group(3) ?? ''),
      endVerse: int.tryParse(match.group(4) ?? ''),
      secondChapter: int.tryParse(match.group(5) ?? ''),
      secondStartVerse: int.tryParse(match.group(6) ?? ''),
      secondEndVerse: int.tryParse(match.group(7) ?? ''),
    );
  }
}

/// Represents a parsed Bible reference
class ReadingReference {
  final String bookName;
  final int? chapter;
  final int? startVerse;
  final int? endVerse;
  final int? secondChapter;
  final int? secondStartVerse;
  final int? secondEndVerse;

  ReadingReference({
    required this.bookName,
    this.chapter,
    this.startVerse,
    this.endVerse,
    this.secondChapter,
    this.secondStartVerse,
    this.secondEndVerse,
  });

  String get displayText {
    final buffer = StringBuffer(bookName);
    if (chapter != null) {
      buffer.write(' $chapter');
      if (startVerse != null) {
        buffer.write(':$startVerse');
        if (endVerse != null && endVerse != startVerse) {
          buffer.write('-$endVerse');
        }
      }
    }
    return buffer.toString();
  }
}
