import '../models/daily_reading.dart';

enum NarrationSegmentKind {
  position,
  reference,
  incipit,
  response,
  acclamation,
  body,
}

class ReadingNarrationSegment {
  final NarrationSegmentKind kind;
  final String text;

  const ReadingNarrationSegment({required this.kind, required this.text});
}

class ReadingNarration {
  final List<ReadingNarrationSegment> segments;
  final String? unavailableMessage;

  const ReadingNarration({required this.segments, this.unavailableMessage});

  const ReadingNarration.unavailable(String message)
    : segments = const <ReadingNarrationSegment>[],
      unavailableMessage = message;

  bool get isAvailable => segments.isNotEmpty;

  String get text => segments.map((segment) => segment.text).join('\n\n');
}

class ReadingNarrationComposer {
  static const unavailableMessage = 'This reading is not available to narrate.';

  const ReadingNarrationComposer();

  ReadingNarration compose({
    required DailyReading reading,
    required String displayedText,
    bool showIncipit = true,
    bool isBibleChapter = false,
    String? displayedPsalmResponse,
    String? displayedGospelAcclamation,
  }) {
    final body = _cleanDisplayedText(displayedText);
    if (_isUnavailable(body)) {
      return const ReadingNarration.unavailable(unavailableMessage);
    }

    final segments = <ReadingNarrationSegment>[];
    final position = _sentence(
      isBibleChapter ? 'Bible chapter' : _cleanPosition(reading.position),
    );
    if (position.isNotEmpty) {
      segments.add(
        ReadingNarrationSegment(
          kind: NarrationSegmentKind.position,
          text: position,
        ),
      );
    }

    final reference = _naturalReference(reading.reading);
    if (reference.isNotEmpty) {
      segments.add(
        ReadingNarrationSegment(
          kind: NarrationSegmentKind.reference,
          text: reference,
        ),
      );
    }

    final incipit = showIncipit && !isBibleChapter
        ? _cleanDisplayedText(reading.incipit ?? '')
        : '';
    if (incipit.isNotEmpty && !_isUnavailable(incipit)) {
      segments.add(
        ReadingNarrationSegment(
          kind: NarrationSegmentKind.incipit,
          text: _sentence(incipit),
        ),
      );
    }

    final response = _cleanResponse(
      displayedPsalmResponse ?? reading.psalmResponse ?? '',
    );
    if (response.isNotEmpty && !_isUnavailable(response)) {
      segments.add(
        ReadingNarrationSegment(
          kind: NarrationSegmentKind.response,
          text: 'Response. ${_sentence(response)}',
        ),
      );
    }

    final acclamation = _cleanDisplayedText(
      displayedGospelAcclamation ?? reading.gospelAcclamation ?? '',
    );
    if (acclamation.isNotEmpty && !_isUnavailable(acclamation)) {
      segments.add(
        ReadingNarrationSegment(
          kind: NarrationSegmentKind.acclamation,
          text: acclamation,
        ),
      );
    }

    var bodyWithoutResponse = _removeRepeatedResponse(body, response);
    if (_equivalent(bodyWithoutResponse, acclamation)) {
      bodyWithoutResponse = '';
    }
    if (bodyWithoutResponse.isNotEmpty) {
      segments.add(
        ReadingNarrationSegment(
          kind: NarrationSegmentKind.body,
          text: bodyWithoutResponse,
        ),
      );
    }

    if (segments.every(
      (segment) =>
          segment.kind == NarrationSegmentKind.position ||
          segment.kind == NarrationSegmentKind.reference,
    )) {
      return const ReadingNarration.unavailable(unavailableMessage);
    }
    return ReadingNarration(segments: List.unmodifiable(segments));
  }

  static String _cleanPosition(String? value) {
    final cleaned = _cleanDisplayedText(value ?? 'Reading');
    return cleaned.replaceFirstMapped(
      RegExp(r'\s*\(alternative(?:\s+(\d+))?\)\s*$', caseSensitive: false),
      (match) => match.group(1) == null
          ? ', alternative'
          : ', alternative ${match.group(1)}',
    );
  }

  static String _cleanResponse(String value) {
    return _cleanDisplayedText(value)
        .replaceFirst(
          RegExp(r'^\s*(?:\(?\s*R[.):]|Response[.:])\s*', caseSensitive: false),
          '',
        )
        .trim();
  }

  static String _removeRepeatedResponse(String body, String response) {
    if (body.isEmpty || response.isEmpty) return body;
    final kept = body.split('\n').where((line) {
      final candidate = _cleanResponse(line);
      return !_equivalent(candidate, response);
    }).toList();
    return kept.join('\n').trim();
  }

  static bool _equivalent(String first, String second) {
    if (first.trim().isEmpty || second.trim().isEmpty) return false;
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return normalize(first) == normalize(second);
  }

  static bool _isUnavailable(String text) {
    if (text.trim().isEmpty) return true;
    return RegExp(
      r'^(?:reading|psalm) text unavailable\b',
      caseSensitive: false,
    ).hasMatch(text.trim());
  }

  static String _cleanDisplayedText(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(
          RegExp(
            r'\s+(?:MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY|SUNDAY)\s+\d{3,4}(?:\s+YEARS?\s+[A-C](?:\s+AND\s+[A-C])?)?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .join('\n')
        .trim();
  }

  static String _sentence(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || RegExp(r"[.!?][”']?$").hasMatch(trimmed)) {
      return trimmed;
    }
    return '$trimmed.';
  }

  static String _naturalReference(String rawReference) {
    final cleaned = _cleanDisplayedText(rawReference);
    final match = RegExp(
      r'^(.+?)\s+(\d+)(?:[:.]\s*(.+))?$',
    ).firstMatch(cleaned);
    if (match == null) return _sentence(cleaned);

    final book =
        _bookNames[match.group(1)!.trim().toLowerCase()] ??
        match.group(1)!.trim();
    final chapter = match.group(2)!;
    var verses = match.group(3)?.trim();
    if (verses == null || verses.isEmpty) {
      return '$book, chapter $chapter.';
    }

    verses = verses
        .replaceFirst(
          RegExp(r'\s*\(R\.\s*[^)]*\)\s*$', caseSensitive: false),
          '',
        )
        .trim();
    final crossChapter = RegExp(
      r'^(\d+[a-z]?)[-–—](\d+):(\d+[a-z]?)$',
      caseSensitive: false,
    ).firstMatch(verses);
    if (crossChapter != null) {
      return '$book, chapter $chapter, verse ${crossChapter.group(1)} '
          'to chapter ${crossChapter.group(2)}, verse ${crossChapter.group(3)}.';
    }

    final spokenVerses = verses
        .replaceAll('+', ' and ')
        .replaceAll(RegExp(r'\s*[-–—]\s*'), ' to ')
        .replaceAllMapped(
          RegExp(r'(\d)\.(?=\d)'),
          (match) => '${match.group(1)}, ',
        )
        .replaceAll(RegExp(r'\s*[;,]\s*'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final verseLabel =
        RegExp(r'[,;+\-–—]').hasMatch(verses) ||
            RegExp(r'\d\s*[a-z]', caseSensitive: false).hasMatch(verses)
        ? 'verses'
        : 'verse';
    return '$book, chapter $chapter, $verseLabel $spokenVerses.';
  }

  static const Map<String, String> _bookNames = <String, String>{
    'gen': 'Genesis',
    'exod': 'Exodus',
    'lev': 'Leviticus',
    'num': 'Numbers',
    'deut': 'Deuteronomy',
    'ps': 'Psalms',
    'psalm': 'Psalms',
    'isa': 'Isaiah',
    'jer': 'Jeremiah',
    'ezek': 'Ezekiel',
    'matt': 'Matthew',
    'mt': 'Matthew',
    'mark': 'Mark',
    'mk': 'Mark',
    'luke': 'Luke',
    'lk': 'Luke',
    'john': 'John',
    'jn': 'John',
    'acts': 'Acts',
    'rom': 'Romans',
    '1 cor': 'First Corinthians',
    '2 cor': 'Second Corinthians',
    'gal': 'Galatians',
    'eph': 'Ephesians',
    'phil': 'Philippians',
    'col': 'Colossians',
    '1 thess': 'First Thessalonians',
    '2 thess': 'Second Thessalonians',
    '1 tim': 'First Timothy',
    '2 tim': 'Second Timothy',
    'heb': 'Hebrews',
    'jas': 'James',
    '1 pet': 'First Peter',
    '2 pet': 'Second Peter',
    '1 jn': 'First John',
    '2 jn': 'Second John',
    '3 jn': 'Third John',
    'rev': 'Revelation',
  };
}
