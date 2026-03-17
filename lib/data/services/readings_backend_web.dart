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
    final cleanedText = _cleanFirstLineForIncipit(processed.correctedText, cleanIncipit);
    return '$cleanIncipit: $cleanedText';
  }

  String _replaceFirstNonEmptyLine(String text, String replacementLine) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        continue;
      }

      final originalLine = lines[i].trim();
      final hasOwnVerseNumber = RegExp(r'^\d+[a-z]?[.\s]+').hasMatch(replacementLine);

      // Check if the replacement is a lectionary-style incipit that should
      // NOT get a verse number prepended. These start with known incipit
      // prefixes (e.g., "At that time,", "Thus says the LORD:", "Brethren:")
      // or are capitalized prose that clearly isn't a raw verse.
      final isIncipitReplacement = _looksLikeIncipitText(replacementLine);

      if (!hasOwnVerseNumber && !isIncipitReplacement) {
        final versePrefix = RegExp(r'^(\d+[a-z]?)').firstMatch(originalLine)?.group(1);
        if (versePrefix != null && versePrefix.isNotEmpty) {
          lines[i] = '$versePrefix. $replacementLine';
          return lines.join('\n');
        }
      }

      // Apply conjunction cleaning for incipit replacements
      if (isIncipitReplacement) {
        lines[i] = _cleanCsvIncipit(replacementLine);
      } else {
        lines[i] = replacementLine;
      }
      return lines.join('\n');
    }

    return replacementLine;
  }

  /// Clean a CSV incipit value before using it to replace the first verse line.
  ///
  /// CSV incipits often contain embedded verse numbers and lectionary-style
  /// formatting that should not appear in the rendered text:
  ///   "At that time: 1. An account of..."  →  "At that time: An account of..."
  ///   "In those days: 1. Now the time..." → "In those days: The time..."
  String _cleanCsvIncipit(String text) {
    var cleaned = text.trim();
    
    // Remove verse number after incipit prefix: "In those days: 1. " → "In those days: "
    cleaned = cleaned.replaceFirst(RegExp(r'(?<=:\s*)\d+[a-z]?\.\s*'), '');
    
    // Remove leading conjunctions that are awkward with temporal incipits
    final lowerText = cleaned.toLowerCase();
    if (lowerText.startsWith('in those days') || lowerText.startsWith('at that time')) {
      // Extract the prefix before the colon and preserve it
      final colonIndex = cleaned.indexOf(':');
      if (colonIndex > 0) {
        final prefix = cleaned.substring(0, colonIndex + 1);
        final suffix = cleaned.substring(colonIndex + 1).trim();
        
        // Remove leading conjunctions from suffix
        final cleanSuffix = suffix.replaceFirst(
          RegExp(r'^(?:Now,?\s*|Then,?\s*|And,?\s*|But,?\s*|So,?\s*|For,?\s*)', caseSensitive: false),
          '',
        ).trim();
        
        if (cleanSuffix.isNotEmpty) {
          cleaned = prefix + ' ' + cleanSuffix[0].toUpperCase() + cleanSuffix.substring(1);
        } else {
          cleaned = prefix;
        }
      }
    } else {
      // General conjunction stripping for non-temporal incipits
      cleaned = cleaned.replaceFirst(
        RegExp(r'^(?:And |But |Now |Then |So |For |Thus |Therefore |Moreover |However |Also |Plus )', caseSensitive: false),
        '',
      );
      
      // Capitalize if we removed something
      if (cleaned != text && cleaned.isNotEmpty && cleaned[0] != '"' && cleaned[0] != '\u201C') {
        cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
      }
    }
    
    return cleaned;
  }

  /// Clean the first line of DB text before prepending a derived incipit.
  ///
  /// Strips verse numbers, leading conjunctions, and tautological temporal
  /// phrases from the first line so the rendered output reads naturally:
  ///   "In those days: 1. Now Moses was..." → "In those days: Moses was..."
  ///   "At that time: 35. On that day..."   → "At that time: When evening had come..."
  ///   "Beloved: 5. Who is it..."           → "Beloved: Who is it..."
  String _cleanFirstLineForIncipit(String text, String incipitPrefix) {
    final lines = text.split('\n');
    if (lines.isEmpty) return text;

    // Find the first non-empty line
    var firstIdx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) {
        firstIdx = i;
        break;
      }
    }
    if (firstIdx < 0) return text;

    var firstLine = lines[firstIdx].trim();

    // Strip verse number prefix: "1. text" → "text", "35. text" → "text"
    firstLine = firstLine.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');

    // Strip leading conjunctions that are tautological with the incipit prefix
    final incipitLower = incipitPrefix.toLowerCase();

    // Temporal tautology: "In those days" + "Now..." or "In those days..."
    if (incipitLower.contains('in those days') || incipitLower.contains('at that time')) {
      firstLine = firstLine.replaceFirst(
        RegExp(r'^(?:Now,?\s*|Then,?\s*|And,?\s*|But,?\s*|So,?\s*|For,?\s*|On that day,?\s*|At that time,?\s*|In those days,?\s*|One day,?\s*|Once,?\s*|On (?:that|one|a certain) (?:day|occasion),?\s*)', caseSensitive: false),
        '',
      );
    } else {
      // General conjunction stripping for non-temporal incipits
      firstLine = firstLine.replaceFirst(
        RegExp(r'^(?:And |But |Now |Then |So |For |Thus |Therefore |Moreover )', caseSensitive: false),
        '',
      );
    }

    // Capitalize the first letter
    if (firstLine.isNotEmpty && firstLine[0] != '"' && firstLine[0] != '\u201C') {
      firstLine = firstLine[0].toUpperCase() + firstLine.substring(1);
    }

    lines[firstIdx] = firstLine;
    return lines.join('\n');
  }

  /// Check if text looks like a lectionary incipit (not a raw verse).
  bool _looksLikeIncipitText(String text) {
    final lower = text.toLowerCase().trim();
    const incipitPrefixes = [
      'at that time',
      'in those days',
      'in the beginning',
      'thus says the lord',
      'the lord said',
      'the lord spoke',
      'jesus said',
      'jesus told',
      'moses said',
      'brethren',
      'brothers and sisters',
      'beloved',
      'my child',
      'my son',
      'hear, my children',
      'children',
      'i said to myself',
      'the word of the lord came',
      'job answered',
      'wisdom has been',
      'with their',
      'the angel',
      'now',
      'then',
      'and',
      'but',
      'so',
      'for',
      'therefore',
      'however',
    ];
    return incipitPrefixes.any((p) => lower.startsWith(p));
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
