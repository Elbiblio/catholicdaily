import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/bible_book.dart';
import '../models/daily_reading.dart';
import 'daniel_verse_mapper.dart' show DeuterocanonicalVerseMapper;
import 'official_lectionary_incipit_service.dart';
import 'reading_reference_parser.dart';
import 'readings_backend.dart';
import 'lectionary_psalm_formatter.dart';
import 'psalm_verse_splitter.dart';
import 'bible_version_preference.dart';

ReadingsBackend createReadingsBackend() => ReadingsBackendIo();

class ReadingsBackendIo implements ReadingsBackend {
  ReadingsBackendIo() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  final OfficialLectionaryIncipitService _incipitService = OfficialLectionaryIncipitService();

  Database? _rsvceDb;
  Database? _nabreDb;
  Database? _readingsDb;
  List<Book>? _booksCache;
  Map<String, String>? _aliasesCache;
  final Map<String, bool> _columnSupportCache = {};
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

  Future<Database> get _readingsDatabase async {
    _readingsDb ??= await _openAssetDatabase('readings.db');
    return _readingsDb!;
  }

  @override
  Future<List<DailyReading>> getReadingsForDate(DateTime date) async {
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

    final db = await _readingsDatabase;
    final hasPsalmResponse = await _supportsPsalmResponse(db);
    final hasGospelAcclamation = await _supportsGospelAcclamation(db);
    final columns = <String>[
      'reading',
      'position',
      if (hasPsalmResponse) 'psalm_response',
      if (hasGospelAcclamation) 'gospel_acclamation',
    ];
    final rows = await db.rawQuery(
      'SELECT ${columns.join(', ')} FROM readings WHERE timestamp = ? ORDER BY position',
      [timestamp],
    );

    final totalRows = rows.length;
    final orderedReferences = rows
        .map((row) => row['reading'] as String)
        .toList(growable: false);

    final readings = rows.asMap().entries.map((entry) {
      final row = entry.value;
      final readingReference = row['reading'] as String;
      final normalizedReference = readingReference.trim().toLowerCase();
      final isPsalmLike = _isPsalmLikeReference(normalizedReference);
      final isGospelLike = _isGospelReference(normalizedReference);

      return DailyReading(
        id: null,
        reading: readingReference,
        position: _positionLabel(
          row['position'] as int?,
          readingReference,
          totalRows,
          orderedReferences,
          orderedIndex: entry.key,
        ),
        date: date,
        feast: null,
        psalmResponse: hasPsalmResponse && isPsalmLike
            ? row['psalm_response'] as String?
            : null,
        gospelAcclamation: hasGospelAcclamation && isGospelLike
            ? row['gospel_acclamation'] as String?
            : null,
      );
    }).toList();

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
        readings[i] = DailyReading(
          id: r.id,
          reading: r.reading,
          position: r.position,
          date: r.date,
          feast: r.feast,
          psalmResponse: decodedPsalm,
          gospelAcclamation: r.gospelAcclamation,
        );
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
  Future<String> getReadingText(String reference, {String? psalmResponse}) async {
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

    if (_isPsalmLikeReference(reference)) {
      return fullText;
    }
    
    // Get the incipit for this reading and prepend it
    final incipit = _incipitService.getOfficialIncipit(reference);
    if (incipit != null && incipit.isNotEmpty) {
      // Clean up incipit punctuation and ensure proper formatting
      var cleanIncipit = incipit.trim();
      cleanIncipit = cleanIncipit.replaceAll(RegExp(r'[,:;]\s*$'), '');
      final formattedIncipit = '$cleanIncipit:';
      
      // Check if text already starts with the incipit phrase (case-insensitive)
      final textLower = fullText.toLowerCase().trim();
      final incipitLower = cleanIncipit.toLowerCase();
      
      if (textLower.startsWith(incipitLower)) {
        // Text already has the incipit, don't duplicate it
        return fullText;
      }
      
      // Clean up the reading text to avoid duplicate words
      // E.g., "In those days: Then Azariah..." -> "In those days: Azariah..."
      final cleanedText = _removeRedundantIncipitWords(fullText, formattedIncipit);
      
      return '$formattedIncipit $cleanedText';
    }

    return fullText;
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
      final verseMatch = RegExp(r':(.+?)(?:\(|$)').firstMatch(reference);
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
    
    // Handle range (e.g., "4bc-5ab" or "8-9")
    if (segment.contains('-')) {
      final parts = segment.split('-');
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
      final match = RegExp(r'(\d+)').firstMatch(segment);
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
    if (_readingsDb != null) {
      await _readingsDb!.close();
      _readingsDb = null;
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
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, dbName);

    final file = File(path);
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/$dbName');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    var db = await openDatabase(path, readOnly: readOnly);
    if (!await _hasExpectedSchema(db, dbName)) {
      await db.close();
      final data = await rootBundle.load('assets/$dbName');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      db = await openDatabase(path, readOnly: readOnly);
    }

    return db;
  }

  Future<bool> _hasExpectedSchema(Database db, String dbName) async {
    try {
      final tableName = dbName == 'readings.db' ? 'readings' : 'books';
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [tableName],
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _supportsPsalmResponse(Database db) async {
    return _supportsColumn(db, 'psalm_response');
  }

  Future<bool> _supportsGospelAcclamation(Database db) async {
    return _supportsColumn(db, 'gospel_acclamation');
  }

  Future<bool> _supportsColumn(Database db, String column) async {
    if (_columnSupportCache.containsKey(column)) {
      return _columnSupportCache[column]!;
    }
    final rows = await db.rawQuery('PRAGMA table_info(readings)');
    final hasColumn = rows.any((row) => row['name'] == column);
    _columnSupportCache[column] = hasColumn;
    return hasColumn;
  }

  String _positionLabel(
    int? position,
    String reading,
    int totalRows,
    List<String> orderedReferences,
    {required int orderedIndex}
  ) {
    if (position == null) {
      return 'Reading';
    }

    final normalized = reading.trim().toLowerCase();
    
    // Check for Gospel readings (always labeled as Gospel)
    final isGospel =
        normalized.startsWith('matt ') ||
        normalized.startsWith('mark ') ||
        normalized.startsWith('luke ') ||
        normalized.startsWith('john ');
    
    if (isGospel) {
      return 'Gospel';
    }
    
    // Check for actual Psalm readings (not just Psalm-like texts)
    final isPsalmLike =
        normalized.startsWith('ps ') ||
        normalized.startsWith('psalm ') ||
        normalized.startsWith('isa 12') ||
        normalized.startsWith('exod 15') ||
        normalized.startsWith('1 sam 2') ||
        normalized.startsWith('luke 1:');
    
    // Only label as Responsorial Psalm if it's actually a Psalm
    // Daniel 3 is a First Reading, not a Psalm, even though it has Psalm-like elements
    if (totalRows > 4) {
      final orderedLabels = _buildComplexLayoutLabels(orderedReferences);
      final index = orderedIndex;
      if (index >= 0 && index < orderedLabels.length) {
        return orderedLabels[index];
      }
    }

    if (isPsalmLike && !normalized.startsWith('dan 3')) {
      return 'Responsorial Psalm';
    }
    
    if (totalRows <= 4) {
      switch (position) {
        case 1:
          return 'First Reading';
        case 2:
          // Don't assume position 2 is always a Psalm - check the actual reading
          if (isPsalmLike) {
            return 'Responsorial Psalm';
          }
          return 'Second Reading';
        case 3:
          // Position 3 could be Psalm or Second Reading depending on the reading
          if (isPsalmLike) {
            return 'Responsorial Psalm';
          }
          return 'Second Reading';
        case 4:
          return 'Gospel';
        default:
          return 'Reading';
      }
    }

    // For non-standard layouts, use smart detection
    if (position == totalRows) {
      return 'Gospel';
    }

    if (position == totalRows - 1 && !isPsalmLike) {
      return 'Second Reading';
    }

    if (position == 1) {
      return 'First Reading';
    }

    return 'Reading ${position.toString()}';
  }

  List<String> _buildComplexLayoutLabels(List<String> orderedReferences) {
    final labels = <String>[];
    var readingCount = 0;
    var psalmCount = 0;

    for (var index = 0; index < orderedReferences.length; index++) {
      final reference = orderedReferences[index];
      final normalized = reference.trim().toLowerCase();

      if (_isGospelReference(normalized)) {
        labels.add('Gospel');
        continue;
      }

      if (_isPsalmLikeReference(normalized) && !normalized.startsWith('dan 3')) {
        psalmCount += 1;
        if (psalmCount == orderedReferences.where((item) => _isPsalmLikeReference(item) && !item.trim().toLowerCase().startsWith('dan 3')).length &&
            normalized.startsWith('ps 118')) {
          labels.add('Alleluia Psalm');
          continue;
        }

        labels.add('Responsorial Psalm');
        continue;
      }

      readingCount += 1;
      if (readingCount == 1) {
        labels.add('First Reading');
      } else if (readingCount == 2) {
        labels.add('Second Reading');
      } else if (readingCount == 3) {
        labels.add('Third Reading');
      } else if (readingCount == 4) {
        labels.add('Fourth Reading');
      } else if (readingCount == 5) {
        labels.add('Fifth Reading');
      } else if (readingCount == 6) {
        labels.add('Sixth Reading');
      } else if (readingCount == 7) {
        labels.add('Seventh Reading');
      } else if (readingCount == 8) {
        labels.add('Epistle');
      } else {
        labels.add('Reading $readingCount');
      }
    }

    return labels;
  }

  bool _isPsalmLikeReference(String reference) {
    final normalized = reference.trim().toLowerCase();
    return normalized.startsWith('ps ') ||
        normalized.startsWith('psalm ') ||
        normalized.startsWith('isa 12') ||
        normalized.startsWith('exod 15') ||
        normalized.startsWith('1 sam 2') ||
        normalized.startsWith('luke 1:');
  }

  bool _isGospelReference(String reference) {
    final normalized = reference.trim().toLowerCase();
    return normalized.startsWith('matt ') ||
        normalized.startsWith('mark ') ||
        normalized.startsWith('luke ') ||
        normalized.startsWith('john ');
  }
  
  /// Remove redundant words that appear in both the incipit and the start of the text
  /// E.g., "In those days:" + "Then Azariah..." -> "In those days:" + "Azariah..."
  String _removeRedundantIncipitWords(String text, String incipit) {
    // Common redundant transition words that appear after incipits
    final redundantWords = [
      'Then ',
      'And ',
      'Now ',
      'So ',
      'But ',
      'For ',
      'When ',
      'After ',
    ];
    
    // Remove verse numbers at the start (e.g., "2. Then" -> "Then")
    var cleanedText = text.replaceFirst(RegExp(r'^\d+\.\s*'), '');
    
    // Check if the text starts with any redundant word
    for (final word in redundantWords) {
      if (cleanedText.startsWith(word)) {
        // Remove the redundant word
        cleanedText = cleanedText.substring(word.length);
        // Also remove the verse number from the cleaned text if it appears again
        cleanedText = cleanedText.replaceFirst(RegExp(r'^\d+\.\s*'), '');
        break;
      }
    }
    
    return cleanedText;
  }

}
