import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/bible_book.dart';
import '../models/daily_reading.dart';
import 'official_lectionary_incipit_service.dart';
import 'reading_reference_parser.dart';
import 'readings_backend.dart';

ReadingsBackend createReadingsBackend() => ReadingsBackendWeb();

class ReadingsBackendWeb implements ReadingsBackend {
  bool _isLoaded = false;
  List<Book> _books = const [];
  Map<String, String> _aliases = const {};
  Map<int, List<_ReadingRow>> _readingsByTimestamp = const {};
  Map<String, Map<int, Map<int, String>>> _versesByBook = const {};
  
  final OfficialLectionaryIncipitService _incipitService = OfficialLectionaryIncipitService();

  @override
  Future<List<DailyReading>> getReadingsForDate(DateTime date) async {
    await _ensureLoaded();

    final timestamp =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
          8,
          0,
          0,
        ).millisecondsSinceEpoch ~/
        1000;

    final rows = _readingsByTimestamp[timestamp] ?? const [];
    return rows
        .map(
          (row) => DailyReading(
            id: null,
            reading: row.reference,
            position: _positionLabel(row.position),
            date: date,
            feast: null,
            psalmResponse: row.psalmResponse,
            gospelAcclamation: row.gospelAcclamation,
          ),
        )
        .toList();
  }

  @override
  Future<String> getReadingText(String reference, {String? psalmResponse}) async {
    await _ensureLoaded();

    final ranges = ReadingReferenceParser.parse(reference);
    if (ranges.isEmpty) {
      return 'Reading text unavailable for $reference.';
    }

    final lines = <String>[];
    for (final range in ranges) {
      final shortName = ReadingReferenceParser.resolveBookShortName(
        range.book,
        _aliases,
      );
      if (shortName == null) continue;

      final rangeLines = _readRangeFromMemory(shortName, range);
      if (rangeLines.isEmpty) continue;
      if (lines.isNotEmpty) {
        lines.add('');
      }
      lines.addAll(rangeLines);
    }

    if (lines.isEmpty) {
      return 'Reading text unavailable for $reference.';
    }

    final fullText = lines.join('\n');
    
    // Get the incipit for this reading and prepend it
    final incipit = _incipitService.getOfficialIncipit(reference);
    if (incipit != null && incipit.isNotEmpty) {
      // Ensure proper formatting: incipit with colon and space, then reading text
      final formattedIncipit = incipit.endsWith(':') ? incipit : '$incipit:';
      return '$formattedIncipit $fullText';
    }

    return fullText;
  }

  @override
  Future<List<Book>> getBooks() async {
    await _ensureLoaded();
    return _books;
  }

  @override
  Future<String> getChapterText({
    required String bookShortName,
    required int chapter,
  }) async {
    await _ensureLoaded();

    final chapterVerses = _versesByBook[bookShortName]?[chapter];
    if (chapterVerses == null || chapterVerses.isEmpty) {
      return 'Chapter text unavailable for $bookShortName $chapter.';
    }

    final verseNumbers = chapterVerses.keys.toList()..sort();
    final lines = verseNumbers
        .map((verse) => '$verse. ${chapterVerses[verse]}')
        .toList();

    return lines.join('\n');
  }

  @override
  Future<void> close() async {
    // No-op for in-memory web data.
  }

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;

    final booksJson = await rootBundle.loadString(
      'assets/data/books_rows.json',
    );
    final readingsJson = await rootBundle.loadString(
      'assets/data/readings_rows.json',
    );
    final versesJson = await rootBundle.loadString(
      'assets/data/verses_rows.json',
    );

    final booksRows = jsonDecode(_stripBom(booksJson)) as List<dynamic>;
    final readingsRows = jsonDecode(_stripBom(readingsJson)) as List<dynamic>;
    final versesRows = jsonDecode(_stripBom(versesJson)) as List<dynamic>;

    _books = booksRows.map((raw) {
      final row = raw as Map<String, dynamic>;
      return Book(
        id: row['_id'] as int,
        name: row['text'] as String,
        shortName: row['shortname'] as String,
        chapterCount: row['chapter_count'] as int? ?? 0,
      );
    }).toList();

    _aliases = ReadingReferenceParser.buildBookAliasMap(_books);

    final readingsByTimestamp = <int, List<_ReadingRow>>{};
    for (final raw in readingsRows) {
      final row = raw as Map<String, dynamic>;
      final timestamp = row['timestamp'] as int;
      final readingRow = _ReadingRow(
        position: row['position'] as int,
        reference: row['reading'] as String,
        psalmResponse: row['psalm_response'] as String?,
        gospelAcclamation: row['gospel_acclamation'] as String?,
      );
      readingsByTimestamp
          .putIfAbsent(timestamp, () => <_ReadingRow>[])
          .add(readingRow);
    }
    _readingsByTimestamp = readingsByTimestamp;

    final versesByBook = <String, Map<int, Map<int, String>>>{};
    for (final raw in versesRows) {
      final row = raw as Map<String, dynamic>;
      final shortName = row['shortname'] as String;
      final chapter = row['chapter_id'] as int;
      final verse = row['verse_id'] as int;
      final text = row['text'] as String;

      versesByBook
              .putIfAbsent(shortName, () => <int, Map<int, String>>{})
              .putIfAbsent(chapter, () => <int, String>{})[verse] =
          text;
    }
    _versesByBook = versesByBook;

    _isLoaded = true;
  }

  List<String> _readRangeFromMemory(String shortName, ScriptureRange range) {
    final chapters = _versesByBook[shortName];
    if (chapters == null) return const [];

    final lines = <String>[];
    for (
      var chapter = range.startChapter;
      chapter <= range.endChapter;
      chapter++
    ) {
      final verseMap = chapters[chapter];
      if (verseMap == null || verseMap.isEmpty) continue;

      final lowerBound = chapter == range.startChapter ? range.startVerse : 1;
      final upperBound = chapter == range.endChapter ? range.endVerse : null;

      final verseNumbers = verseMap.keys.toList()..sort();
      for (final verse in verseNumbers) {
        if (verse < lowerBound) continue;
        if (upperBound != null && verse > upperBound) continue;
        lines.add('$verse. ${verseMap[verse]}');
      }
    }

    return lines;
  }

  String _positionLabel(int? position) {
    switch (position) {
      case 1:
        return 'First Reading';
      case 2:
        return 'Responsorial Psalm';
      case 3:
        return 'Second Reading';
      case 4:
        return 'Gospel';
      default:
        return 'Reading';
    }
  }

  String _stripBom(String value) {
    if (value.isNotEmpty && value.codeUnitAt(0) == 0xFEFF) {
      return value.substring(1);
    }
    return value;
  }
}

class _ReadingRow {
  final int position;
  final String reference;
  final String? psalmResponse;
  final String? gospelAcclamation;

  const _ReadingRow({
    required this.position,
    required this.reference,
    this.psalmResponse,
    this.gospelAcclamation,
  });
}
