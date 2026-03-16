import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/bible_book.dart';
import '../models/daily_reading.dart';
import 'csv_readings_resolver_service.dart';
import 'official_lectionary_incipit_service.dart';
import 'reading_reference_parser.dart';
import 'readings_backend.dart';
import 'shared_service_utils.dart';

ReadingsBackend createReadingsBackend() => ReadingsBackendWeb();

class ReadingsBackendWeb implements ReadingsBackend {
  bool _isLoaded = false;
  List<Book> _books = const [];
  Map<String, String> _aliases = const {};
  Map<String, Map<int, Map<int, String>>> _versesByBook = const {};
  
  final OfficialLectionaryIncipitService _incipitService = OfficialLectionaryIncipitService();
  final CsvReadingsResolverService _csvResolver = CsvReadingsResolverService.instance;

  @override
  Future<List<DailyReading>> getReadingsForDate(DateTime date) async {
    return _csvResolver.resolve(date);
  }

  @override
  Future<String> getReadingText(
    String reference, {
    String? psalmResponse,
    String? incipit,
  }) async {
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

    if (SharedServiceUtils.isPsalmLikeReference(reference)) {
      return fullText;
    }

    final processed = _incipitService.processReading(reference, fullText);
    if (incipit != null && incipit.trim().isNotEmpty) {
      return _replaceFirstNonEmptyLine(processed.correctedText, incipit.trim());
    }

    final derivedIncipit = processed.incipit;
    if (derivedIncipit == null || derivedIncipit.trim().isEmpty) {
      return processed.correctedText;
    }

    final cleanIncipit = derivedIncipit
        .trim()
        .replaceAll(RegExp(r'[,:;]\s*$'), '');
    return '$cleanIncipit: ${processed.correctedText}';
  }

  String _replaceFirstNonEmptyLine(String text, String replacementLine) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        continue;
      }

      final originalLine = lines[i].trim();
      final hasOwnVerseNumber = RegExp(r'^\d+[a-z]?[.\s]+').hasMatch(replacementLine);
      if (!hasOwnVerseNumber) {
        final versePrefix = RegExp(r'^(\d+[a-z]?)').firstMatch(originalLine)?.group(1);
        if (versePrefix != null && versePrefix.isNotEmpty) {
          lines[i] = '$versePrefix. $replacementLine';
          return lines.join('\n');
        }
      }

      lines[i] = replacementLine;
      return lines.join('\n');
    }

    return replacementLine;
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
    final versesJson = await rootBundle.loadString(
      'assets/data/verses_rows.json',
    );

    final booksRows = jsonDecode(_stripBom(booksJson)) as List<dynamic>;
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

  String _stripBom(String value) {
    if (value.isNotEmpty && value.codeUnitAt(0) == 0xFEFF) {
      return value.substring(1);
    }
    return value;
  }
}
