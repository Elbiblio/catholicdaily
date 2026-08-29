import '../models/daily_reading.dart';
import 'reading_reference_parser.dart';
import 'scripture_book_names.dart';

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
      r'^(?:reading|psalm|chapter) text unavailable\b',
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
    var cleaned = _cleanDisplayedText(rawReference)
        .replaceFirst(
          RegExp(r'\s*\(R\.\s*[^)]*\)\s*$', caseSensitive: false),
          '',
        )
        .trim();
    cleaned = cleaned.replaceFirstMapped(
      RegExp(r'^(.+?\s+\d+)\.(?=\d)'),
      (match) => '${match.group(1)}:',
    );
    final joinedVerseReplacements = <String, String>{
      for (final match in RegExp(
        r'\d+[a-z]?(?:\+\d+[a-z]?)+',
        caseSensitive: false,
      ).allMatches(cleaned))
        match.group(0)!.replaceAll('+', ', '): match
            .group(0)!
            .replaceAll('+', ' and '),
    };
    cleaned = cleaned.replaceAll('+', ',');

    final ranges = ReadingReferenceParser.parse(cleaned);
    if (ranges.isNotEmpty) {
      final book = ScriptureBookNames.spokenName(ranges.first.book);
      final clauses = <String>[];
      var index = 0;
      while (index < ranges.length) {
        final range = ranges[index];
        if (range.startChapter != range.endChapter) {
          clauses.add(
            'chapter ${range.startChapter}, verse ${_startToken(range)} '
            'to chapter ${range.endChapter}, verse ${_endToken(range)}',
          );
          index++;
          continue;
        }

        final chapter = range.startChapter;
        final chapterRanges = <ScriptureRange>[];
        while (index < ranges.length &&
            ranges[index].startChapter == chapter &&
            ranges[index].endChapter == chapter) {
          chapterRanges.add(ranges[index]);
          index++;
        }
        final tokens = chapterRanges.map(_rangeToken).toList();
        final plural =
            chapterRanges.length > 1 ||
            chapterRanges.any((item) => item.startVerse != item.endVerse);
        clauses.add(
          'chapter $chapter, ${plural ? 'verses' : 'verse'} '
          '${tokens.join(', ')}',
        );
      }
      var spoken = '$book, ${clauses.join('; ')}.';
      for (final replacement in joinedVerseReplacements.entries) {
        spoken = spoken.replaceAll(replacement.key, replacement.value);
      }
      return spoken;
    }

    final match = RegExp(r'^(.+?)\s+(\d+)$').firstMatch(cleaned);
    if (match == null) return _sentence(cleaned);

    final book = ScriptureBookNames.spokenName(match.group(1)!);
    final chapter = match.group(2)!;
    return '$book, chapter $chapter.';
  }

  static String _rangeToken(ScriptureRange range) {
    final start = _startToken(range);
    final end = _endToken(range);
    return start == end ? start : '$start to $end';
  }

  static String _startToken(ScriptureRange range) =>
      '${range.startVerse}${range.startVerseParts ?? ''}';

  static String _endToken(ScriptureRange range) =>
      '${range.endVerse}${range.endVerseParts ?? ''}';
}
