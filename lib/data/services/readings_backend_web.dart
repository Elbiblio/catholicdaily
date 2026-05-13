import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import '../models/bible_book.dart';
import '../models/daily_reading.dart';
import 'csv_readings_resolver_service.dart';
import 'incipit_decision_service.dart';
import 'incipit_preference_service.dart';
import 'incipit_processing_service.dart';
import 'reading_reference_parser.dart';
import 'readings_backend.dart';
import 'shared_service_utils.dart';
import 'bible_version_preference.dart';

ReadingsBackend createReadingsBackend() => ReadingsBackendWeb();

class ReadingsBackendWeb implements ReadingsBackend {
  bool _isLoaded = false;
  List<Book> _books = const [];
  Map<String, String> _aliases = const {};
  Map<String, Map<int, Map<int, String>>> _versesByBook = const {};
  BibleVersionPreference? _versionPreference;

  final IncipitProcessingService _incipitService = IncipitProcessingService();
  final IncipitDecisionService _incipitDecision = IncipitDecisionService();
  final IncipitPreferenceService _incipitPreference =
      IncipitPreferenceService();
  final CsvReadingsResolverService _csvResolver =
      CsvReadingsResolverService.instance;

  @override
  Future<List<DailyReading>> getReadingsForDate(DateTime date) async {
    return _csvResolver.resolve(date);
  }

  @override
  Future<String> getReadingText(
    String reference, {
    String? psalmResponse,
    String? incipit,
    String? readingType,
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

    final showIncipit = await _incipitPreference.getShowIncipit();
    if (!showIncipit) {
      return fullText;
    }

    final locale = await _incipitPreference.getLocale();
    final decision = await _incipitDecision.decide(
      reference: reference,
      fullText: fullText,
      csvIncipit: incipit,
      locale: locale,
      readingType: readingType,
    );
    if (!decision.usesOpening) {
      return fullText;
    }

    if (decision.operation == 'generatedFallback' ||
        decision.rejectedAlternatives.isNotEmpty ||
        decision.warnings.isNotEmpty) {
      debugPrint('INCIPIT_AUDIT ${decision.auditRow}');
    }

    return _incipitService.processWithAuthoritativeIncipit(
      reference,
      fullText,
      decision.opening,
      joinStyle: decision.joinStyle,
    );
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

    _versionPreference ??= await BibleVersionPreference.getInstance();
    final currentVersion = _versionPreference!.currentVersion;

    // Try to load version-specific verses data, fall back to default
    String versesJson;
    try {
      versesJson = await rootBundle.loadString(
        'assets/data/verses_rows_${currentVersion.dbName}.json',
      );
    } catch (e) {
      // Fall back to default verses file if version-specific one doesn't exist
      versesJson = await rootBundle.loadString('assets/data/verses_rows.json');
    }

    // Load books data (same for all versions)
    final booksJson = await rootBundle.loadString(
      'assets/data/books_rows.json',
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

  /// Reload verses data for the current Bible version
  Future<void> reloadForVersionChange() async {
    _isLoaded = false;
    await _ensureLoaded();
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
