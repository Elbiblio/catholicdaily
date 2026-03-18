import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/bible_book.dart';
import '../models/daily_reading.dart';
import 'csv_readings_resolver_service.dart';
import 'daniel_verse_mapper.dart' show DeuterocanonicalVerseMapper;
import 'official_lectionary_incipit_service.dart';
import 'reading_reference_parser.dart';
import 'readings_backend.dart';
import 'lectionary_psalm_formatter.dart';
import 'psalm_verse_splitter.dart';
import 'bible_version_preference.dart';
import 'shared_service_utils.dart';

ReadingsBackend createReadingsBackend() => ReadingsBackendIo();

class ReadingsBackendIo implements ReadingsBackend {
  ReadingsBackendIo() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  final OfficialLectionaryIncipitService _incipitService = OfficialLectionaryIncipitService();
  final CsvReadingsResolverService _csvResolver = CsvReadingsResolverService.instance;

  Database? _rsvceDb;
  Database? _nabreDb;
  List<Book>? _booksCache;
  Map<String, String>? _aliasesCache;
  BibleVersionPreference? _versionPreference;

  Future<Database> get _rsvceDatabase async {
    _rsvceDb ??= await _openAssetDatabase('rsvce.db', readOnly: true);
    return _rsvceDb!;
  }

  Future<Database> get _nabreDatabase async {
    _nabreDb ??= await _openAssetDatabase('nabre.db', readOnly: true);
    return _nabreDb!;
  }

  Future<Database> get _currentBibleDatabase async {
    _versionPreference ??= await BibleVersionPreference.getInstance();
    final version = _versionPreference!.currentVersion;
    
    switch (version) {
      case BibleVersionType.nabre:
        return _nabreDatabase;
      case BibleVersionType.rsvce:
        return _rsvceDatabase;
    }
  }

  @override
  Future<List<DailyReading>> getReadingsForDate(DateTime date) async {
    final readings = await _csvResolver.resolve(date);

    // Decode psalm responses that are verse references into actual text.
    // Preserve gospel acclamation values as stored so higher-level date-aware
    // resolution can prefer the official liturgical acclamation text.
    for (var i = 0; i < readings.length; i++) {
      final r = readings[i];
      String? decodedPsalm = r.psalmResponse;
      
      if (r.psalmResponse != null) {
        decodedPsalm = await _decodePsalmResponseRef(r.psalmResponse!, r.reading);
      }

      if (decodedPsalm != r.psalmResponse) {
        readings[i] = r.copyWith(psalmResponse: decodedPsalm);
      }
    }

    return readings;
  }

  /// If [response] looks like a verse reference (e.g. "Ps 147:12" or "Ps 145:8a"),
  /// fetch the verse text from the RSVCE database and return it.
  /// Otherwise return the original string unchanged.
  Future<String> _decodePsalmResponseRef(String response, String reading) async {
    // Only decode if it looks like a verse reference (short, starts with Ps/Psalm)
    if (!_looksLikePsalmReference(response)) return response;
    
    final match = RegExp(
      r'^(?:Ps|Psalm)\s*\.?\s*(\d+):(\d+)([a-d])?$',
      caseSensitive: false,
    ).firstMatch(response.trim());
    if (match == null) return response; // already plain text

    final chapter = int.parse(match.group(1)!);
    final verseNum = int.parse(match.group(2)!);
    final partLetter = match.group(3);

    try {
      final db = await _currentBibleDatabase;
      final rows = await db.rawQuery('''
        SELECT v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE b.shortname = 'Ps' AND v.chapter_id = ? AND v.verse_id = ?
      ''', [chapter, verseNum]);

      if (rows.isEmpty) return response;
      final verseText = rows.first['text'] as String;

      if (partLetter != null) {
        final extracted = PsalmVerseSplitter.getVersePart(verseText, partLetter);
        return extracted ?? response;
      }

      // Return full verse cleaned of leading number
      return verseText.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
    } catch (_) {
      return response;
    }
  }

  /// Check if a string looks like a psalm verse reference
  bool _looksLikePsalmReference(String text) {
    final trimmed = text.trim();
    // Must be short and start with Ps/Psalm followed by chapter:verse
    return trimmed.length < 30 && 
           RegExp(r'^(?:Ps|Psalm)\s*\.?\s*\d+:\d+', caseSensitive: false).hasMatch(trimmed);
  }

  @override
  Future<String> getReadingText(
    String reference, {
    String? psalmResponse,
    String? incipit,
  }) async {
    // Check if this is a responsorial psalm that needs special formatting
    if (_isResponsorialPsalm(reference)) {
      return await _getResponsorialPsalmText(reference, psalmResponse: psalmResponse);
    }
    
    final ranges = ReadingReferenceParser.parse(reference);
    if (ranges.isEmpty) {
      return 'Reading text unavailable for $reference.';
    }

    final aliases = await _bookAliases;
    final lines = <String>[];

    for (final range in ranges) {
      final shortName = ReadingReferenceParser.resolveBookShortName(
        range.book,
        aliases,
      );
      if (shortName == null) continue;

      final rangeLines = await _fetchRange(shortName: shortName, range: range);
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
      final cleaned = _cleanCsvIncipit(incipit.trim());
      if (cleaned.isNotEmpty) {
        return _mergeIncipitIntoFirstVerse(processed.correctedText, cleaned);
      }
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
  
  /// Check if a reference is a responsorial psalm with complex notation
  bool _isResponsorialPsalm(String reference) {
    final normalized = reference.toLowerCase().trim();
    
    // Must start with Ps or Psalm
    if (!normalized.startsWith('ps ') && !normalized.startsWith('psalm ')) {
      return false;
    }
    
    // Check for patterns that indicate lectionary-style psalm formatting:
    // - Letter parts: "4bc-5ab", "13cd-14"
    // - "and" notation: "6 and 7bc"
    // - Refrain notation: "(R. 6a)"
    // - Comma-separated ranges: "12-13, 15-16, 19-20"
    return normalized.contains(RegExp(r'\d+[a-d]')) ||
           normalized.contains(' and ') ||
           normalized.contains(RegExp(r'\(r\.\s*\d+[a-d]?\)')) ||
           normalized.contains(','); // Comma-separated stanza groups
  }
  
  /// Get responsorial psalm text with lectionary formatting
  Future<String> _getResponsorialPsalmText(String reference, {String? psalmResponse}) async {
    try {
      // Extract psalm chapter number
      final chapterMatch = RegExp(r'(?:Ps|Psalm)\s+(\d+)', caseSensitive: false).firstMatch(reference);
      if (chapterMatch == null) {
        return 'Psalm text unavailable for $reference.';
      }
      
      final chapter = int.parse(chapterMatch.group(1)!);
      
      // Extract verse range to know which verses to fetch
      final verseMatch = RegExp(r'[:\.](.+?)(?:\(|$)').firstMatch(reference);
      if (verseMatch == null) {
        return 'Psalm text unavailable for $reference.';
      }
      
      final versePart = verseMatch.group(1)!.trim();
      
      // Determine which verses we need
      final versesToFetch = _extractVerseNumbers(versePart);
      if (versesToFetch.isEmpty) {
        return 'Psalm text unavailable for $reference.';
      }
      
      // If psalmResponse is a verse reference, include that verse in the fetch range
      int? refrainVerseNum;
      int? refrainChapter;
      String? refrainPart;
      bool refrainIsVerseRef = false;
      
      if (psalmResponse != null) {
        final verseRefMatch = RegExp(
          r'(?:Ps|Psalm)\s*\.?\s*(\d+):(\d+)([a-d])?',
          caseSensitive: false,
        ).firstMatch(psalmResponse);
        if (verseRefMatch != null) {
          refrainIsVerseRef = true;
          refrainChapter = int.parse(verseRefMatch.group(1)!);
          refrainVerseNum = int.parse(verseRefMatch.group(2)!);
          refrainPart = verseRefMatch.group(3);
          // Add refrain verse to fetch set if same chapter
          if (refrainChapter == chapter) {
            versesToFetch.add(refrainVerseNum);
          }
        }
      }
      
      // Fetch the verses from database
      final db = await _rsvceDatabase;
      final minVerse = versesToFetch.reduce((a, b) => a < b ? a : b);
      final maxVerse = versesToFetch.reduce((a, b) => a > b ? a : b);
      
      final rows = await db.rawQuery('''
        SELECT v.verse_id, v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE b.shortname = 'Ps' AND v.chapter_id = ? 
          AND v.verse_id >= ? AND v.verse_id <= ?
        ORDER BY v.verse_id
      ''', [chapter, minVerse, maxVerse]);
      
      if (rows.isEmpty) {
        return 'Psalm text unavailable for $reference.';
      }
      
      // Build verse map
      final verses = <int, String>{};
      for (var row in rows) {
        verses[row['verse_id'] as int] = row['text'] as String;
      }
      
      // Resolve the refrain text
      String refrain = 'Lord, hear our prayer.';
      String? refrainVerseLabel;
      
      if (psalmResponse != null) {
        if (refrainIsVerseRef && refrainVerseNum != null) {
          // psalmResponse is a verse reference – decode to actual text
          refrainVerseLabel = '$refrainVerseNum${refrainPart ?? ""}';
          
          // Fetch from a different chapter if needed
          Map<int, String> refrainSource = verses;
          if (refrainChapter != null && refrainChapter != chapter) {
            final refrainRows = await db.rawQuery('''
              SELECT v.verse_id, v.text
              FROM verses v
              JOIN books b ON b._id = v.book_id
              WHERE b.shortname = 'Ps' AND v.chapter_id = ? AND v.verse_id = ?
            ''', [refrainChapter, refrainVerseNum]);
            if (refrainRows.isNotEmpty) {
              refrainSource = {refrainRows.first['verse_id'] as int: refrainRows.first['text'] as String};
            }
          }
          
          if (refrainSource.containsKey(refrainVerseNum)) {
            final refrainText = refrainSource[refrainVerseNum]!;
            if (refrainPart != null) {
              final extracted = PsalmVerseSplitter.getVersePart(refrainText, refrainPart);
              if (extracted != null) {
                refrain = extracted;
              }
            } else {
              // Use the full verse text (cleaned) as the refrain
              refrain = refrainText.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
            }
          }
        } else {
          // It's actual text, use it directly
          refrain = psalmResponse;
        }
      } else {
        // Try to extract from (R. N) notation in the reference
        final refrainMatch = RegExp(r'\(R\.\s*(\d+)([a-d])?\)', caseSensitive: false).firstMatch(reference);
        if (refrainMatch != null) {
          final rVerseNum = int.parse(refrainMatch.group(1)!);
          final rPart = refrainMatch.group(2);
          refrainVerseLabel = '${refrainMatch.group(1)}${rPart ?? ""}';
          
          if (verses.containsKey(rVerseNum)) {
            final refrainText = verses[rVerseNum]!;
            if (rPart != null) {
              final extracted = PsalmVerseSplitter.getVersePart(refrainText, rPart);
              if (extracted != null) {
                refrain = extracted;
              }
            } else {
              refrain = refrainText.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
            }
          }
        }
      }
      
      // Format with lectionary style
      return LectionaryPsalmFormatter.format(
        reference: reference,
        verses: verses,
        refrain: refrain,
        refrainVerse: refrainVerseLabel,
      );
    } catch (e) {
      // Fallback to regular text if formatting fails
      return 'Psalm text unavailable for $reference. Error: $e';
    }
  }
  
  /// Extract all verse numbers from a verse notation string
  Set<int> _extractVerseNumbers(String versePart) {
    final verses = <int>{};
    
    // Remove refrain notation
    versePart = versePart.replaceAll(RegExp(r'\(R\.\s*[^)]+\)'), '').trim();
    
    // Split on commas
    final segments = versePart.split(',');
    
    for (var segment in segments) {
      segment = segment.trim();
      
      // Handle "and" notation
      if (segment.contains(' and ')) {
        final andParts = segment.split(' and ');
        for (var part in andParts) {
          verses.addAll(_extractVerseNumbersFromSegment(part.trim()));
        }
      } else {
        verses.addAll(_extractVerseNumbersFromSegment(segment));
      }
    }
    
    return verses;
  }
  
  /// Extract verse numbers from a single segment
  Set<int> _extractVerseNumbersFromSegment(String segment) {
    final verses = <int>{};

    final normalizedSegment = segment.replaceAll('&', ' and ');

    if (normalizedSegment.contains(' and ')) {
      final andParts = normalizedSegment.split(' and ');
      for (final part in andParts) {
        verses.addAll(_extractVerseNumbersFromSegment(part.trim()));
      }
      return verses;
    }

    if (normalizedSegment.contains('+')) {
      final plusParts = normalizedSegment.split('+');
      for (final part in plusParts) {
        verses.addAll(_extractVerseNumbersFromSegment(part.trim()));
      }
      return verses;
    }
    
    // Handle range (e.g., "4bc-5ab" or "8-9")
    if (normalizedSegment.contains('-')) {
      final parts = normalizedSegment.split('-');
      if (parts.length == 2) {
        final startMatch = RegExp(r'(\d+)').firstMatch(parts[0]);
        final endMatch = RegExp(r'(\d+)').firstMatch(parts[1]);
        
        if (startMatch != null && endMatch != null) {
          final start = int.parse(startMatch.group(1)!);
          final end = int.parse(endMatch.group(1)!);
          
          for (var i = start; i <= end; i++) {
            verses.add(i);
          }
        }
      }
    } else {
      // Single verse
      final match = RegExp(r'(\d+)').firstMatch(normalizedSegment);
      if (match != null) {
        verses.add(int.parse(match.group(1)!));
      }
    }
    
    return verses;
  }

  @override
  Future<List<Book>> getBooks() async {
    if (_booksCache != null) return _booksCache!;

    final db = await _currentBibleDatabase;
    final rows = await db.rawQuery('''
      SELECT b._id AS id, b.text AS name, b.shortname AS shortname,
             MAX(v.chapter_id) AS chapter_count
      FROM books b
      LEFT JOIN verses v ON v.book_id = b._id
      GROUP BY b._id, b.text, b.shortname
      ORDER BY b._id
      ''');

    _booksCache = rows
        .map(
          (row) => Book(
            id: row['id'] as int,
            name: row['name'] as String,
            shortName: row['shortname'] as String,
            chapterCount: row['chapter_count'] as int? ?? 0,
          ),
        )
        .toList();

    return _booksCache!;
  }

  @override
  Future<String> getChapterText({
    required String bookShortName,
    required int chapter,
  }) async {
    final db = await _rsvceDatabase;
    final rows = await db.rawQuery(
      '''
      SELECT v.verse_id, v.text
      FROM verses v
      JOIN books b ON b._id = v.book_id
      WHERE b.shortname = ? AND v.chapter_id = ?
      ORDER BY v.verse_id
      ''',
      [bookShortName, chapter],
    );

    if (rows.isEmpty) {
      return 'Chapter text unavailable for $bookShortName $chapter.';
    }

    return rows.map((row) => '${row['verse_id']}. ${row['text']}').join('\n');
  }

  @override
  Future<void> close() async {
    if (_rsvceDb != null) {
      await _rsvceDb!.close();
      _rsvceDb = null;
    }
    if (_nabreDb != null) {
      await _nabreDb!.close();
      _nabreDb = null;
    }
  }

  Future<Map<String, String>> get _bookAliases async {
    if (_aliasesCache != null) return _aliasesCache!;
    final books = await getBooks();
    _aliasesCache = ReadingReferenceParser.buildBookAliasMap(books);
    return _aliasesCache!;
  }

  Future<List<String>> _fetchRange({
    required String shortName,
    required ScriptureRange range,
  }) async {
    final db = await _currentBibleDatabase;
    final lines = <String>[];

    for (
      var chapter = range.startChapter;
      chapter <= range.endChapter;
      chapter++
    ) {
      var startVerse = chapter == range.startChapter ? range.startVerse : 1;
      var endVerse = chapter == range.endChapter ? range.endVerse : null;

      // Universal handling for deuterocanonical additions
      // The lectionary uses NAB/Vulgate numbering which differs from RSVCE database
      final needsTranslation = DeuterocanonicalVerseMapper.needsTranslation(
        shortName,
        chapter,
        startVerse,
      );
      
      if (needsTranslation) {
        // Translate NAB verse numbers to RSVCE verse numbers
        startVerse = DeuterocanonicalVerseMapper.nabToRsvce(
          shortName,
          chapter,
          startVerse,
        );
        if (endVerse != null) {
          endVerse = DeuterocanonicalVerseMapper.nabToRsvce(
            shortName,
            chapter,
            endVerse,
          );
        }
      }

      final where = StringBuffer(
        'b.shortname = ? AND v.chapter_id = ? AND v.verse_id >= ?',
      );
      final args = <Object?>[shortName, chapter, startVerse];

      if (endVerse != null) {
        where.write(' AND v.verse_id <= ?');
        args.add(endVerse);
      }
      
      // For deuterocanonical additions, restrict to the specific section
      // to avoid picking up duplicate verse numbers
      if (needsTranslation) {
        final constraints = DeuterocanonicalVerseMapper.getRowConstraints(
          shortName,
          chapter,
        );
        if (constraints != null && 
            constraints.startRow != null && 
            constraints.endRow != null) {
          where.write(' AND v._id >= ? AND v._id < ?');
          args.add(constraints.startRow);
          args.add(constraints.endRow);
        }
      }

      final rows = await db.rawQuery('''
        SELECT v.verse_id, v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE ${where.toString()}
        ORDER BY v._id
        ''', args);

      final isSingleVerseWithParts =
          range.startChapter == range.endChapter &&
          range.startVerse == range.endVerse &&
          range.startVerseParts != null;

      if (isSingleVerseWithParts && rows.isNotEmpty) {
        final verseText = rows.first['text'] as String;
        final extracted = PsalmVerseSplitter.getVerseParts(
          verseText,
          range.startVerseParts!,
        );
        if (extracted != null && extracted.trim().isNotEmpty) {
          lines.add('${rows.first['verse_id']}. ${extracted.trim()}');
          continue;
        }
      }

      for (final row in rows) {
        var verseText = row['text'] as String;
        final verseId = row['verse_id'] as int;

        final isStartVerse =
            chapter == range.startChapter && verseId == range.startVerse;
        final isEndVerse =
            chapter == range.endChapter && verseId == range.endVerse;

        if (isStartVerse && range.startVerseParts != null) {
          verseText = PsalmVerseSplitter.getVerseParts(
                verseText,
                range.startVerseParts!,
              ) ??
              verseText;
        }

        if (isEndVerse &&
            range.endVerseParts != null &&
            !(isStartVerse && range.startVerseParts == range.endVerseParts)) {
          verseText = PsalmVerseSplitter.getVerseParts(
                row['text'] as String,
                range.endVerseParts!,
              ) ??
              verseText;
        }

        lines.add('$verseId. $verseText');
      }
    }

    return lines;
  }

  Future<Database> _openAssetDatabase(String dbName, {bool readOnly = false}) async {
    return await SharedServiceUtils.openValidatedAssetDatabase(dbName, readOnly: readOnly);
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

  /// Clean a CSV incipit value before using it to replace the first verse line.
  ///
  /// CSV incipits often contain embedded verse numbers and lectionary-style
  /// formatting that should not appear in the rendered text:
  ///   "At that time: 1. An account of..."  →  "At that time, an account of..."
  ///   "Thus says the LORD: 5. "The days..." →  "Thus says the LORD: "The days..."
  ///   "Brethren: 32. What more..."          →  "Brethren: What more..."
  String _cleanCsvIncipit(String raw) {
    var r = raw.trim();
    if (r.isEmpty) return r;

    // Pattern: "Prefix: NN. Text..." — strip the verse number after the colon
    // e.g., "At that time: 1. An account" → "At that time: An account"
    // e.g., "Brethren: 32. What more" → "Brethren: What more"
    r = r.replaceFirstMapped(
      RegExp(r'^(.+?:\s*)\d+[a-z]?\.\s*(.*)$', dotAll: true),
      (m) => '${m.group(1)!}${m.group(2)!}',
    );

    // If the entire incipit is just a verse number + text (no prefix),
    // strip the verse number: "1. Jacob called..." → "Jacob called..."
    if (RegExp(r'^\d+[a-z]?\.\s').hasMatch(r)) {
      r = r.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    }

    // Clean tautological temporal phrases after the incipit prefix:
    //   "At that time: One day, while..." → "At that time, while..."
    //   "At that time: Once when..."      → "At that time, when..."
    //   "In those days: Now..."           → "In those days,"
    final prefixMatch = RegExp(
      r'^((?:At that time|In those days|Jesus said to (?:his disciples|the crowds?|them)|Thus says the LORD|Brethren|Beloved|My son|The LORD said)[,:]\s*)',
      caseSensitive: false,
    ).firstMatch(r);
    if (prefixMatch != null) {
      final prefix = prefixMatch.group(1)!;
      var after = r.substring(prefix.length).trim();

      // Strip tautological temporal openers
      after = after.replaceFirst(
        RegExp(r'^(?:one day,?\s*|once,?\s*|on (?:that|one|a certain) (?:day|occasion),?\s*|at that (?:time|very moment),?\s*|now,?\s*)', caseSensitive: false),
        '',
      );

      // Strip leading conjunctions
      after = after.replaceFirst(
        RegExp(r'^(?:and|but|then|so|for|now|thus|therefore|moreover)\s+', caseSensitive: false),
        '',
      );

      // Capitalize the first letter of what remains
      if (after.isNotEmpty) {
        after = after[0].toUpperCase() + after.substring(1);
      }

      if (prefix.toLowerCase().startsWith('at that time') && after.isNotEmpty) {
        after = after.replaceFirstMapped(
          RegExp(r'^(?:(While|As|When|After)\s+)(?:he|him)\b', caseSensitive: false),
          (m) => '${m.group(1)} Jesus',
        );
        after = after.replaceFirstMapped(
          RegExp(r'^(?:He|Him)\b', caseSensitive: false),
          (_) => 'Jesus',
        );
      }

      // Reconstruct: ensure prefix ends with clean separator
      final cleanPrefix = prefix.replaceAll(RegExp(r'[,:;\s]+$'), '');
      r = after.isNotEmpty ? '$cleanPrefix, $after' : cleanPrefix;
    }

    return r.trim();
  }

  String _mergeIncipitIntoFirstVerse(String text, String incipitText) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        continue;
      }

      final originalLine = lines[i].trim();
      final verseMatch = RegExp(r'^(\d+[a-z]?)\.\s*(.*)$').firstMatch(originalLine);
      final versePrefix = verseMatch?.group(1);
      final verseBody = (verseMatch?.group(2) ?? originalLine).trim();
      final mergedLine = _mergeIncipitWithVerseText(incipitText, verseBody);

      lines[i] = versePrefix != null && versePrefix.isNotEmpty
          ? '$versePrefix. $mergedLine'
          : mergedLine;
      return lines.join('\n');
    }

    return incipitText;
  }

  String _mergeIncipitWithVerseText(String incipitText, String verseText) {
    final cleanedIncipit = _cleanCsvIncipit(incipitText);
    final cleanedVerse = verseText.trim();
    if (cleanedIncipit.isEmpty || cleanedVerse.isEmpty) {
      return cleanedIncipit.isEmpty ? cleanedVerse : cleanedIncipit;
    }

    final incipitParts = _splitIncipitParts(cleanedIncipit);
    final incipitBody = incipitParts.$2;
    final normalizedIncipit = _normalizeMergedIncipit(cleanedIncipit);

    if (incipitBody.isNotEmpty) {
      final overlap = _findLoosePhraseMatch(cleanedVerse, incipitBody);
      if (overlap != null) {
        final remainder = cleanedVerse.substring(overlap.end).trimLeft().replaceFirst(
          RegExp(r'^[,;:!?.\-–—]+\s*'),
          '',
        );
        if (remainder.isEmpty) {
          return normalizedIncipit;
        }
        return _joinSentenceParts(normalizedIncipit, remainder);
      }
    }

    if (_looksLikeIncipitText(cleanedIncipit)) {
      final cleanedFirstLine = _cleanFirstLineForIncipit(cleanedVerse, normalizedIncipit);
      return _joinIncipitAndVerse(normalizedIncipit, cleanedFirstLine);
    }

    return _joinIncipitAndVerse(normalizedIncipit, cleanedVerse);
  }

  (String, String) _splitIncipitParts(String incipit) {
    final colonIndex = incipit.indexOf(':');
    if (colonIndex >= 0) {
      final prefix = incipit.substring(0, colonIndex).trim();
      final body = incipit.substring(colonIndex + 1).trim();
      return (prefix, body);
    }
    return ('', incipit.trim());
  }

  String _normalizeMergedIncipit(String incipit) {
    return incipit.trim().replaceAll(RegExp(r'[,:;]+\s*$'), '').trim();
  }

  RegExpMatch? _findLoosePhraseMatch(String verseText, String phrase) {
    var normalizedPhrase = phrase.trim();
    normalizedPhrase = normalizedPhrase
        .replaceAll('“', '')
        .replaceAll('”', '')
        .replaceFirst(RegExp("^[\"']+"), '')
        .trim();
    while (normalizedPhrase.isNotEmpty && '"\':;,.!?'.contains(normalizedPhrase[normalizedPhrase.length - 1])) {
      normalizedPhrase = normalizedPhrase.substring(0, normalizedPhrase.length - 1).trimRight();
    }
    if (normalizedPhrase.isEmpty) {
      return null;
    }

    final tokens = normalizedPhrase
        .split(RegExp(r'\s+'))
        .map((token) => token.replaceAll(RegExp("[^A-Za-z0-9']"), ''))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.length < 3) {
      return null;
    }

    final pattern = tokens.map(RegExp.escape).join(r'[\s\W_]+');
    return RegExp(pattern, caseSensitive: false).firstMatch(verseText);
  }

  String _joinSentenceParts(String leading, String trailing) {
    final trimmedLeading = leading.trimRight();
    final trimmedTrailing = trailing.trimLeft();
    if (trimmedLeading.isEmpty) {
      return trimmedTrailing;
    }
    if (trimmedTrailing.isEmpty) {
      return trimmedLeading;
    }

    if (RegExp(r'[.!?]$').hasMatch(trimmedLeading)) {
      return '$trimmedLeading $trimmedTrailing';
    }
    return '$trimmedLeading. $trimmedTrailing';
  }

  String _joinIncipitAndVerse(String incipit, String verse) {
    final trimmedIncipit = incipit.trimRight();
    final trimmedVerse = verse.trimLeft();
    if (trimmedIncipit.isEmpty) {
      return trimmedVerse;
    }
    if (trimmedVerse.isEmpty) {
      return trimmedIncipit;
    }

    if (RegExp(r'[:,;]$').hasMatch(trimmedIncipit)) {
      return '$trimmedIncipit $trimmedVerse';
    }
    if (RegExp(r'[.!?]$').hasMatch(trimmedIncipit)) {
      return '$trimmedIncipit $trimmedVerse';
    }
    return '$trimmedIncipit: $trimmedVerse';
  }

  /// Check if text looks like a lectionary incipit (not a raw verse).
  bool _looksLikeIncipitText(String text) {
    final lower = text.toLowerCase().trim();
    
    // Check for common incipit prefixes with colons (CSV format)
    if (RegExp(r'^(at that time|in those days|thus says the lord|brethren|beloved|my son|the lord said|jesus said):', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    
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
}
