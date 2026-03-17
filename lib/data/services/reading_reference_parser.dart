import '../models/bible_book.dart';

class ScriptureRange {
  final String book;
  final int startChapter;
  final int startVerse;
  final int endChapter;
  final int endVerse;
  final String? startVerseParts;
  final String? endVerseParts;

  const ScriptureRange({
    required this.book,
    required this.startChapter,
    required this.startVerse,
    required this.endChapter,
    required this.endVerse,
    this.startVerseParts,
    this.endVerseParts,
  });
}

class ReadingReferenceParser {
  static List<ScriptureRange> parse(String reference) {
    final normalized = _normalizeReference(reference);
    if (normalized.isEmpty) return const [];

    final ranges = <ScriptureRange>[];
    String? currentBook;
    int? currentChapter;

    final majorParts = normalized
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    for (final majorPart in majorParts) {
      final segments = majorPart
          .split(',')
          .map((segment) => segment.trim())
          .where((segment) => segment.isNotEmpty);

      for (final segment in segments) {
        final fullRefMatch = RegExp(
          r'^(.+?)\s+(\d+):(.*)$',
        ).firstMatch(segment);
        if (fullRefMatch != null &&
            RegExp(r'[A-Za-z]').hasMatch(fullRefMatch.group(1)!)) {
          final book = fullRefMatch.group(1)!.trim();
          final chapter = int.tryParse(fullRefMatch.group(2)!);
          final verseExpr = fullRefMatch.group(3)!.trim();
          if (chapter == null) continue;

          currentBook = book;
          currentChapter = chapter;

          final range = _parseVerseExpression(
            book: book,
            chapter: chapter,
            expression: verseExpr,
          );
          if (range != null) {
            ranges.add(range);
            currentChapter = range.endChapter;
          }
          continue;
        }

        final chapterVerseMatch = RegExp(r'^(\d+):(.*)$').firstMatch(segment);
        if (chapterVerseMatch != null && currentBook != null) {
          final chapter = int.tryParse(chapterVerseMatch.group(1)!);
          final verseExpr = chapterVerseMatch.group(2)!.trim();
          if (chapter == null) continue;

          currentChapter = chapter;

          final range = _parseVerseExpression(
            book: currentBook,
            chapter: chapter,
            expression: verseExpr,
          );
          if (range != null) {
            ranges.add(range);
            currentChapter = range.endChapter;
          }
          continue;
        }

        final crossChapterToken = RegExp(
          r'^(\d+)-(\d+):(\d+)(?:-(\d+))?$',
        ).firstMatch(segment);
        if (crossChapterToken != null &&
            currentBook != null &&
            currentChapter != null) {
          final startVerse = _parseNumber(crossChapterToken.group(1)!);
          final endChapter = int.tryParse(crossChapterToken.group(2)!);
          final endVerse = _parseNumber(
            crossChapterToken.group(4) ?? crossChapterToken.group(3)!,
          );

          if (startVerse != null && endChapter != null && endVerse != null) {
            ranges.add(
              ScriptureRange(
                book: currentBook,
                startChapter: currentChapter,
                startVerse: startVerse,
                endChapter: endChapter,
                endVerse: endVerse,
              ),
            );
            currentChapter = endChapter;
          }
          continue;
        }

        if (currentBook != null && currentChapter != null) {
          final range = _parseVerseExpression(
            book: currentBook,
            chapter: currentChapter,
            expression: segment,
          );
          if (range != null) {
            ranges.add(range);
            currentChapter = range.endChapter;
          }
        }
      }
    }

    return ranges;
  }

  static String normalizeBookKey(String value) {
    var normalized = value
        .toLowerCase()
        .replaceAll('.', ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final tokens = normalized.split(' ');
    if (tokens.isNotEmpty) {
      switch (tokens.first) {
        case 'i':
          tokens[0] = '1';
          break;
        case 'ii':
          tokens[0] = '2';
          break;
        case 'iii':
          tokens[0] = '3';
          break;
      }
      normalized = tokens.join(' ');
    }

    normalized = normalized.replaceAll('of the apostles', '').trim();
    return normalized;
  }

  static Map<String, String> buildBookAliasMap(List<Book> books) {
    final aliases = <String, String>{};
    for (final book in books) {
      aliases[normalizeBookKey(book.shortName)] = book.shortName;
      aliases[normalizeBookKey(book.name)] = book.shortName;
    }

    const manualAliases = <String, String>{
      'act': 'Acts',
      'acts': 'Acts',
      'acts of apostles': 'Acts',
      'matthew': 'Matt',
      'matt': 'Matt',
      'mt': 'Matt',
      'mark': 'Mark',
      'mk': 'Mark',
      'luke': 'Luke',
      'lk': 'Luke',
      'john': 'John',
      'jn': 'John',
      '1 corinthians': '1 Cor',
      '1 cor': '1 Cor',
      'i corinthians': '1 Cor',
      '2 corinthians': '2 Cor',
      '2 cor': '2 Cor',
      'ii corinthians': '2 Cor',
      'ephesians': 'Eph',
      'eph': 'Eph',
      'philippians': 'Phil',
      'phil': 'Phil',
      '1 peter': '1 Pet',
      '1 pet': '1 Pet',
      'i peter': '1 Pet',
      '2 peter': '2 Pet',
      '2 pet': '2 Pet',
      'ii peter': '2 Pet',
      '1 john': '1 John',
      'i john': '1 John',
      '2 john': '2 John',
      'ii john': '2 John',
      '3 john': '3 John',
      'iii john': '3 John',
      'romans': 'Rom',
      'rom': 'Rom',
      'hebrews': 'Heb',
      'hebr': 'Heb',
      'james': 'Jas',
      'revelation': 'Rev',
      'apocalypse': 'Rev',
      'isaiah': 'Isa',
      'isa': 'Isa',
      'jeremiah': 'Jer',
      'jer': 'Jer',
      'ezekiel': 'Ezek',
      'ezek': 'Ezek',
      'hosea': 'Hos',
      'hos': 'Hos',
      'joel': 'Joel',
      'psalm': 'Ps',
      'psalms': 'Ps',
      'ps': 'Ps',
      'ecclesiastes': 'Eccles',
      'hag': 'Hagg',
      'jon': 'Jonah',
      'jdt': 'Jud',
      'zep': 'Zeph',
      'zephaniah': 'Zeph',
      'mi': 'Mic',
      'micah': 'Mic',
      'ez': 'Ezek',
      'am': 'Amos',
      'zec': 'Zech',
      'zechariah': 'Zech',
      'jas': 'Jas',
      'jude': 'Jude',
      'jd': 'Jude',
      'tobit': 'Tob',
      'tob': 'Tob',
      'judges': 'Judg',
      'dt': 'Deut',
      'deuteronomy': 'Deut',
      'deut': 'Deut',
      'sir': 'Sir',
      'sirach': 'Sir',
      'wisdom': 'Wis',
      'wis': 'Wis',
      'baruch': 'Bar',
      'bar': 'Bar',
      'lam': 'Lam',
      'lamentations': 'Lam',
      'obadiah': 'Obad',
      'obad': 'Obad',
      'nahum': 'Nah',
      'nah': 'Nah',
      'habakkuk': 'Hab',
      'hab': 'Hab',
      'malachi': 'Mal',
      'mal': 'Mal',
      'daniel': 'Dan',
      'dan': 'Dan',
      'rev': 'Rev',
    };

    manualAliases.forEach((alias, shortName) {
      aliases[alias] = shortName;
    });

    return aliases;
  }

  static String? resolveBookShortName(
    String book,
    Map<String, String> aliases,
  ) {
    final normalized = normalizeBookKey(book);
    if (aliases.containsKey(normalized)) {
      return aliases[normalized];
    }

    final compact = normalized.replaceAll(' ', '');
    for (final entry in aliases.entries) {
      if (entry.key.replaceAll(' ', '') == compact) {
        return entry.value;
      }
    }

    return null;
  }

  static ScriptureRange? _parseVerseExpression({
    required String book,
    required int chapter,
    required String expression,
  }) {
    final cleaned = expression.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return null;

    final crossWithTrailingRange = RegExp(
      r'^(\d+[a-z]*)-(\d+):(\d+[a-z]*)-(\d+[a-z]*)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (crossWithTrailingRange != null) {
      final startVerse = _parseNumber(crossWithTrailingRange.group(1)!);
      final endChapter = int.tryParse(crossWithTrailingRange.group(2)!);
      final endVerse = _parseNumber(crossWithTrailingRange.group(4)!);
      if (startVerse != null && endChapter != null && endVerse != null) {
        return ScriptureRange(
          book: book,
          startChapter: chapter,
          startVerse: startVerse,
          endChapter: endChapter,
          endVerse: endVerse,
          startVerseParts: _parseParts(crossWithTrailingRange.group(1)!),
          endVerseParts: _parseParts(crossWithTrailingRange.group(4)!),
        );
      }
    }

    final crossChapter = RegExp(
      r'^(\d+[a-z]*)-(\d+):(\d+[a-z]*)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (crossChapter != null) {
      final startVerse = _parseNumber(crossChapter.group(1)!);
      final endChapter = int.tryParse(crossChapter.group(2)!);
      final endVerse = _parseNumber(crossChapter.group(3)!);
      if (startVerse != null && endChapter != null && endVerse != null) {
        return ScriptureRange(
          book: book,
          startChapter: chapter,
          startVerse: startVerse,
          endChapter: endChapter,
          endVerse: endVerse,
          startVerseParts: _parseParts(crossChapter.group(1)!),
          endVerseParts: _parseParts(crossChapter.group(3)!),
        );
      }
    }

    final sameChapterRange = RegExp(
      r'^(\d+[a-z]*)-(\d+[a-z]*)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (sameChapterRange != null) {
      final startVerse = _parseNumber(sameChapterRange.group(1)!);
      final endVerse = _parseNumber(sameChapterRange.group(2)!);
      if (startVerse != null && endVerse != null) {
        return ScriptureRange(
          book: book,
          startChapter: chapter,
          startVerse: startVerse,
          endChapter: chapter,
          endVerse: endVerse,
          startVerseParts: _parseParts(sameChapterRange.group(1)!),
          endVerseParts: _parseParts(sameChapterRange.group(2)!),
        );
      }
    }

    final singleVerse = RegExp(
      r'^(\d+[a-z]*)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (singleVerse != null) {
      final verse = _parseNumber(singleVerse.group(1)!);
      if (verse != null) {
        return ScriptureRange(
          book: book,
          startChapter: chapter,
          startVerse: verse,
          endChapter: chapter,
          endVerse: verse,
          startVerseParts: _parseParts(singleVerse.group(1)!),
          endVerseParts: _parseParts(singleVerse.group(1)!),
        );
      }
    }

    return null;
  }

  static int? _parseNumber(String token) {
    final match = RegExp(r'\d+').firstMatch(token);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  static String? _parseParts(String token) {
    final match = RegExp(r'\d+([a-z]+)$', caseSensitive: false).firstMatch(token);
    if (match == null) return null;
    final parts = match.group(1)?.toLowerCase();
    return (parts == null || parts.isEmpty) ? null : parts;
  }

  static String _normalizeReference(String input) {
    return input
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
