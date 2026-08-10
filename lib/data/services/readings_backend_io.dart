import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/bible_book.dart';
import '../models/bible_source.dart';
import '../models/daily_reading.dart';
import 'bible_source_registry.dart';
import 'csv_readings_resolver_service.dart';
import 'daniel_verse_mapper.dart' show DeuterocanonicalVerseMapper;
import 'lectionary_text_override_service.dart';
import 'incipit_preference_service.dart';
import 'lectionary_psalm_catalog_service.dart';
import 'reading_reference_parser.dart';
import 'readings_backend.dart';
import 'lectionary_psalm_formatter.dart';
import 'psalm_verse_splitter.dart';
import 'bible_version_preference.dart';
import 'shared_service_utils.dart';

ReadingsBackend createReadingsBackend() => ReadingsBackendIo();

class ReadingsBackendIo implements ReadingsBackend {
  final int minimumDownloadedBookCount;
  final int minimumDownloadedVerseCount;

  ReadingsBackendIo({
    this.minimumDownloadedBookCount = 73,
    this.minimumDownloadedVerseCount = 30000,
  }) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  final CsvReadingsResolverService _csvResolver =
      CsvReadingsResolverService.instance;
  final LectionaryPsalmCatalogService _psalmCatalog =
      LectionaryPsalmCatalogService.instance;
  final LectionaryTextOverrideService _lectionaryTextOverrides =
      LectionaryTextOverrideService.instance;

  final Map<String, Database> _databaseCache = <String, Database>{};
  List<Book>? _booksCache;
  Map<String, String>? _aliasesCache;
  BibleVersionPreference? _versionPreference;

  Future<Database> _databaseForSource(BibleSource source) async {
    if (!source.isBundledRenderable && !source.isDownloadableLocal) {
      throw StateError(
        'Bible source ${source.id} is not a renderable local database.',
      );
    }
    final cached = _databaseCache[source.id];
    if (cached != null) return cached;
    final Database opened;
    if (source.isBundledRenderable) {
      opened = await _openAssetDatabase(source.assetDbName!, readOnly: true);
    } else {
      final documents = await getApplicationDocumentsDirectory();
      final databasePath = path.join(documents.path, source.assetDbName!);
      if (!await File(databasePath).exists()) {
        throw StateError(
          'Bible source ${source.id} has not been downloaded yet.',
        );
      }
      opened = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        await _validateDownloadedDatabase(opened, source);
      } catch (_) {
        try {
          await opened.close();
        } catch (_) {
          // Preserve the validation failure that triggered recovery.
        }
        rethrow;
      }
    }
    _databaseCache[source.id] = opened;
    return opened;
  }

  Future<Database> get _currentBibleDatabase async {
    _versionPreference ??= await BibleVersionPreference.getInstance();
    final failedVersion = _versionPreference!.currentVersion;
    final source = BibleSourceRegistry.instance.requireById(
      failedVersion.dbName,
    );
    try {
      return await _databaseForSource(source);
    } catch (_) {
      if (!source.isDownloadableLocal) rethrow;
      final recoveryVersion = BibleVersionRecoveryPolicy.versionAfterFailure(
        failedVersion: failedVersion,
        currentVersion: _versionPreference!.currentVersion,
      );
      if (_versionPreference!.currentVersion == failedVersion) {
        await _versionPreference!.setVersion(recoveryVersion);
      }
      _booksCache = null;
      _aliasesCache = null;
      return _databaseForSource(
        BibleSourceRegistry.instance.requireById(
          _versionPreference!.currentVersion.dbName,
        ),
      );
    }
  }

  Future<void> _validateDownloadedDatabase(
    Database database,
    BibleSource source,
  ) async {
    const requiredColumns = <String, Set<String>>{
      'books': {'_id', 'text', 'shortname'},
      'verses': {'_id', 'book_id', 'chapter_id', 'verse_id', 'text'},
    };
    for (final entry in requiredColumns.entries) {
      final rows = await database.rawQuery('PRAGMA table_info(${entry.key})');
      final columns = rows
          .map((row) => row['name'])
          .whereType<String>()
          .toSet();
      if (!columns.containsAll(entry.value)) {
        throw StateError(
          'Bible source ${source.id} has an invalid ${entry.key} schema.',
        );
      }
    }

    final counts = await database.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM books) AS book_count,
        (SELECT COUNT(*) FROM verses) AS verse_count
    ''');
    final bookCount = counts.first['book_count'] as int? ?? 0;
    final verseCount = counts.first['verse_count'] as int? ?? 0;
    if (bookCount < minimumDownloadedBookCount ||
        verseCount < minimumDownloadedVerseCount) {
      throw StateError(
        'Bible source ${source.id} does not contain enough Scripture data.',
      );
    }
  }

  @override
  Future<List<DailyReading>> getReadingsForDate(DateTime date) async {
    final readings = await _csvResolver.resolve(date);

    var psalmOrdinal = 0;
    for (var i = 0; i < readings.length; i++) {
      final r = readings[i];
      final position = (r.position ?? '').toLowerCase();
      var updated = r;

      if (position.contains('psalm')) {
        psalmOrdinal += 1;

        // For feast days (reading.feast is set), use the hardcoded response from CSV
        // Do NOT enrich from catalog - feast days have their own proper readings
        if (r.feast != null && r.feast!.isNotEmpty) {
          debugPrint(
            'Feast day psalm: ${r.reading}, feast: ${r.feast}, response: ${r.psalmResponse}',
          );
          // Decode only missing/reference-only responses. Proper feast
          // refrains can include an "(R. ...)" source marker in CSV input,
          // but the displayed response should remain the lectionary text.
          if (!_hasUsableLectionaryResponse(r.psalmResponse) &&
              r.psalmResponse != null) {
            final decodedFromR = await _decodeRefrainFromRNotation(
              r.reading + ' ' + r.psalmResponse!,
            );
            if (decodedFromR != null && decodedFromR.trim().isNotEmpty) {
              updated = updated.copyWith(psalmResponse: decodedFromR);
            }
          }
        } else {
          // Ferial day: enrich from catalog
          // Step 1: enrich the reading's reference with "(R. Xx)" notation
          // when available in the supplementary lectionary_psalms[_weekday].csv.
          final bestEntry = await _psalmCatalog.getBestPsalmEntryForDate(
            date: date,
            psalmReference: updated.reading,
            positionLabel: updated.position,
            psalmSequence: psalmOrdinal,
          );
          String enrichedReference = updated.reading;
          if (bestEntry != null &&
              RegExp(
                r'\(R\.',
                caseSensitive: false,
              ).hasMatch(bestEntry.fullReference)) {
            enrichedReference = _mergeRNotation(
              base: updated.reading,
              enriched: bestEntry.fullReference,
            );
          }
          if (enrichedReference != updated.reading) {
            updated = updated.copyWith(reading: enrichedReference);
          }

          // Step 2: keep proper lectionary refrains when the CSV supplies
          // them. Decode only missing/reference-only responses; many missal
          // refrains are liturgical adaptations rather than verbatim verses.
          if (!_hasUsableLectionaryResponse(r.psalmResponse)) {
            final decodedFromR = await _decodeRefrainFromRNotation(
              enrichedReference,
            );
            if (decodedFromR != null && decodedFromR.trim().isNotEmpty) {
              updated = updated.copyWith(psalmResponse: decodedFromR);
            } else if (r.psalmResponse != null) {
              final decoded = await _decodePsalmResponseRef(
                r.psalmResponse!,
                updated.reading,
              );
              if (decoded != r.psalmResponse) {
                updated = updated.copyWith(psalmResponse: decoded);
              }
            }
          }
        }
      } else if (r.psalmResponse != null) {
        final decoded = await _decodePsalmResponseRef(
          r.psalmResponse!,
          r.reading,
        );
        if (decoded != r.psalmResponse) {
          updated = updated.copyWith(psalmResponse: decoded);
        }
      }

      if (!identical(updated, r)) {
        readings[i] = updated;
      }
    }

    return readings;
  }

  /// Appends the "(R. Xx)" refrain notation from [enriched] onto [base]
  /// when the two references point to the same psalm passage.
  String _mergeRNotation({required String base, required String enriched}) {
    final rMatch = RegExp(
      r'\(R\.[^)]+\)',
      caseSensitive: false,
    ).firstMatch(enriched);
    if (rMatch == null) return base;
    if (RegExp(r'\(R\.', caseSensitive: false).hasMatch(base)) return base;
    return '$base ${rMatch.group(0)!}';
  }

  /// Reads "(R. 7a)" / "(R. see 7)" / "(R. cf. 30)" / "(R. Isa 35.4d)" style notation from a
  /// psalm [reference] and fetches the corresponding verse text from the
  /// currently selected Bible database. Returns null when no notation is
  /// present or the verse cannot be fetched.
  ///
  /// Supports:
  /// - Simple verse numbers: (R. 7), (R. 2a)
  /// - Compound parts: (R. 6cd), (R. 7c+10c)
  /// - Bible references: (R. Isa 35.4d), (R. Lk 21.28)
  /// - With prefixes: (R. see 7), (R. cf. 30), (R. see Jn 8.12)
  Future<String?> _decodeRefrainFromRNotation(String reference) async {
    debugPrint('_decodeRefrainFromRNotation: input=$reference');

    // Extract the R notation from the reference
    final rNotationMatch = RegExp(
      r'\(R\.\s*(?:see\s+|cf\.?\s*)?([^)]+)\)',
      caseSensitive: false,
    ).firstMatch(reference);
    if (rNotationMatch == null) {
      debugPrint('_decodeRefrainFromRNotation: no R notation found');
      return null;
    }

    final rContent = rNotationMatch.group(1)!.trim();
    debugPrint('_decodeRefrainFromRNotation: R content=$rContent');

    // Try to match as a Bible reference (e.g., "Isa 35.4d", "Lk 21.28", "see Jn 8.12")
    final bibleRefMatch = RegExp(
      r'^(?:see\s+|cf\.?\s*)?([A-Za-z]+)\s+(\d+)\.(\d+)([a-d])?$',
      caseSensitive: false,
    ).firstMatch(rContent);

    if (bibleRefMatch != null) {
      debugPrint('_decodeRefrainFromRNotation: Bible reference detected');
      return _fetchBibleVerse(
        bookAbbr: bibleRefMatch.group(1)!,
        chapter: int.parse(bibleRefMatch.group(2)!),
        verse: int.parse(bibleRefMatch.group(3)!),
        partLetter: bibleRefMatch.group(4),
      );
    }

    // Try to match as a simple psalm verse (e.g., "7", "2a", "6cd", "see 7", "cf. 1")
    // Also handle compound parts (e.g., "7c+10c", "1a+3a", "7-8")
    final psalmRefMatch = RegExp(
      r'^(?:see\s+|cf\.?\s*)?(\d+)([a-d]+)?(?:[\+\-]\d+[a-d]*)*$',
      caseSensitive: false,
    ).firstMatch(rContent);

    if (psalmRefMatch == null) {
      debugPrint('_decodeRefrainFromRNotation: cannot parse R content');
      return null;
    }

    // Get the psalm chapter from the reference
    final chapterMatch = RegExp(
      r'(?:Ps|Psalm)\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(reference);
    if (chapterMatch == null) {
      debugPrint(
        '_decodeRefrainFromRNotation: no psalm chapter found in reference',
      );
      return null;
    }

    final chapter = int.parse(chapterMatch.group(1)!);
    final verseNum = int.parse(psalmRefMatch.group(1)!);
    final partLetter = psalmRefMatch.group(2);

    debugPrint(
      '_decodeRefrainFromRNotation: Psalm $chapter:$verseNum${partLetter ?? ''}',
    );

    return _fetchPsalmVerse(chapter, verseNum, partLetter);
  }

  /// Fetch a verse from the Psalms book
  Future<String?> _fetchPsalmVerse(
    int chapter,
    int verse,
    String? partLetter,
  ) async {
    try {
      final db = await _currentBibleDatabase;
      final rows = await db.rawQuery(
        '''
        SELECT v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE b.shortname = 'Ps' AND v.chapter_id = ? AND v.verse_id = ?
      ''',
        [chapter, verse],
      );

      if (rows.isEmpty) {
        debugPrint(
          '_fetchPsalmVerse: no verse found for Psalm $chapter:$verse',
        );
        return null;
      }
      final verseText = rows.first['text'] as String;

      if (partLetter != null) {
        final result = PsalmVerseSplitter.getVersePart(verseText, partLetter);
        debugPrint('_fetchPsalmVerse: extracted part $partLetter');
        return result;
      }
      final result = verseText.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
      debugPrint('_fetchPsalmVerse: full verse');
      return result;
    } catch (e) {
      debugPrint('_fetchPsalmVerse: error - $e');
      return null;
    }
  }

  /// Fetch a verse from any Bible book using abbreviation
  Future<String?> _fetchBibleVerse({
    required String bookAbbr,
    required int chapter,
    required int verse,
    String? partLetter,
  }) async {
    debugPrint(
      '_fetchBibleVerse: $bookAbbr $chapter:$verse${partLetter ?? ''}',
    );

    // Map common abbreviations to full names
    final bookName = _mapBookAbbreviation(bookAbbr);
    if (bookName == null) {
      debugPrint('_fetchBibleVerse: unknown book abbreviation $bookAbbr');
      return null;
    }

    try {
      final db = await _currentBibleDatabase;
      final rows = await db.rawQuery(
        '''
        SELECT v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE (b.text = ? COLLATE NOCASE OR b.shortname = ? COLLATE NOCASE)
          AND v.chapter_id = ? AND v.verse_id = ?
      ''',
        [bookName, bookAbbr, chapter, verse],
      );

      if (rows.isEmpty) {
        debugPrint(
          '_fetchBibleVerse: no verse found for $bookName $chapter:$verse',
        );
        return null;
      }
      final verseText = rows.first['text'] as String;

      if (partLetter != null) {
        final result = PsalmVerseSplitter.getVersePart(verseText, partLetter);
        debugPrint('_fetchBibleVerse: extracted part $partLetter');
        return result;
      }
      final result = verseText.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
      debugPrint('_fetchBibleVerse: full verse');
      return result;
    } catch (e) {
      debugPrint('_fetchBibleVerse: error - $e');
      return null;
    }
  }

  /// Map book abbreviation to full name
  String? _mapBookAbbreviation(String abbr) {
    const mapping = {
      'Gen': 'Genesis',
      'Exod': 'Exodus',
      'Lev': 'Leviticus',
      'Num': 'Numbers',
      'Deut': 'Deuteronomy',
      'Josh': 'Joshua',
      'Judg': 'Judges',
      'Ruth': 'Ruth',
      '1 Sam': '1 Samuel',
      '2 Sam': '2 Samuel',
      '1 Kgs': '1 Kings',
      '2 Kgs': '2 Kings',
      '1 Chr': '1 Chronicles',
      '2 Chr': '2 Chronicles',
      'Ezra': 'Ezra',
      'Neh': 'Nehemiah',
      'Tob': 'Tobit',
      'Jdt': 'Judith',
      'Esth': 'Esther',
      '1 Macc': '1 Maccabees',
      '2 Macc': '2 Maccabees',
      'Job': 'Job',
      'Ps': 'Psalms',
      'Prov': 'Proverbs',
      'Eccles': 'Ecclesiastes',
      'Song': 'Song of Songs',
      'Wis': 'Wisdom',
      'Sir': 'Sirach',
      'Isa': 'Isaiah',
      'Jer': 'Jeremiah',
      'Lam': 'Lamentations',
      'Bar': 'Baruch',
      'Ezek': 'Ezekiel',
      'Dan': 'Daniel',
      'Hos': 'Hosea',
      'Joel': 'Joel',
      'Amos': 'Amos',
      'Obad': 'Obadiah',
      'Jonah': 'Jonah',
      'Mic': 'Micah',
      'Nah': 'Nahum',
      'Hab': 'Habakkuk',
      'Zeph': 'Zephaniah',
      'Hagg': 'Haggai',
      'Zech': 'Zechariah',
      'Mal': 'Malachi',
      'Matt': 'Matthew',
      'Mark': 'Mark',
      'Lk': 'Luke',
      'Jn': 'John',
      'Acts': 'Acts of the Apostles',
      'Rom': 'Romans',
      '1 Cor': '1 Corinthians',
      '2 Cor': '2 Corinthians',
      'Gal': 'Galatians',
      'Eph': 'Ephesians',
      'Phil': 'Philippians',
      'Col': 'Colossians',
      '1 Thess': '1 Thessalonians',
      '2 Thess': '2 Thessalonians',
      '1 Tim': '1 Timothy',
      '2 Tim': '2 Timothy',
      'Titus': 'Titus',
      'Phlm': 'Philemon',
      'Heb': 'Hebrews',
      'James': 'James',
      '1 Pet': '1 Peter',
      '2 Pet': '2 Peter',
      '1 John': '1 John',
      '2 John': '2 John',
      '3 John': '3 John',
      'Jude': 'Jude',
      'Rev': 'Revelation',
    };
    final normalized = abbr.trim();
    final direct = mapping[normalized];
    if (direct != null) return direct;
    final lower = normalized.toLowerCase();
    for (final entry in mapping.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  /// If [response] looks like a verse reference (e.g. "Ps 147:12" or "Ps 145:8a"),
  /// fetch the verse text from the RSVCE database and return it.
  /// Otherwise return the original string unchanged.
  Future<String> _decodePsalmResponseRef(
    String response,
    String reading,
  ) async {
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
      final rows = await db.rawQuery(
        '''
        SELECT v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE b.shortname = 'Ps' AND v.chapter_id = ? AND v.verse_id = ?
      ''',
        [chapter, verseNum],
      );

      if (rows.isEmpty) return response;
      final verseText = rows.first['text'] as String;

      if (partLetter != null) {
        final extracted = PsalmVerseSplitter.getVersePart(
          verseText,
          partLetter,
        );
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
        RegExp(
          r'^(?:Ps|Psalm)\s*\.?\s*\d+:\d+',
          caseSensitive: false,
        ).hasMatch(trimmed);
  }

  bool _hasUsableLectionaryResponse(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return false;
    }
    if (_looksLikePsalmReference(trimmed)) {
      return false;
    }
    if (RegExp(r'^\(?\s*R\.', caseSensitive: false).hasMatch(trimmed)) {
      return false;
    }
    return true;
  }

  @override
  Future<String> getReadingText(
    String reference, {
    String? psalmResponse,
    String? incipit,
    String? readingType,
  }) async {
    // Check if this is a responsorial psalm that needs special formatting
    if (_isResponsorialPsalm(reference)) {
      return await _getResponsorialPsalmText(
        reference,
        psalmResponse: psalmResponse,
      );
    }

    // Strip "see" / "cf." / "cf" prefixes so allusive acclamation references
    // like "cf. Luke 24:32" can still be looked up.
    final cleanReference = reference
        .replaceFirst(
          RegExp(r'^\s*(?:see|cf\.?|confer)\s+', caseSensitive: false),
          '',
        )
        .trim();

    final useReadingIntroReplacements = await IncipitPreferenceService()
        .getUseReadingIntroReplacements();
    if (useReadingIntroReplacements &&
        !SharedServiceUtils.isPsalmLikeReference(reference)) {
      final lectionaryText = await _lectionaryTextOverrides.lookup(
        reference: cleanReference,
        readingType: readingType,
        incipit: incipit,
      );
      if (lectionaryText != null) {
        return lectionaryText;
      }
    }

    final ranges = ReadingReferenceParser.parse(cleanReference);
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
  Future<String> _getResponsorialPsalmText(
    String reference, {
    String? psalmResponse,
  }) async {
    try {
      // Extract psalm chapter number
      final chapterMatch = RegExp(
        r'(?:Ps|Psalm)\s+(\d+)',
        caseSensitive: false,
      ).firstMatch(reference);
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

      // Fetch only the verses that are actually referenced — use IN (…) rather
      // than a >= min AND <= max range, which would over-fetch skipped verses.
      final sortedVerses = versesToFetch.toList()..sort();
      final placeholders = sortedVerses.map((_) => '?').join(', ');

      final rows = await (await _currentBibleDatabase).rawQuery(
        '''
        SELECT v.verse_id, v.text
        FROM verses v
        JOIN books b ON b._id = v.book_id
        WHERE b.shortname = 'Ps' AND v.chapter_id = ? 
          AND v.verse_id IN ($placeholders)
        ORDER BY v.verse_id
      ''',
        [chapter, ...sortedVerses],
      );

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
            final refrainRows = await (await _currentBibleDatabase).rawQuery(
              '''
              SELECT v.verse_id, v.text
              FROM verses v
              JOIN books b ON b._id = v.book_id
              WHERE b.shortname = 'Ps' AND v.chapter_id = ? AND v.verse_id = ?
            ''',
              [refrainChapter, refrainVerseNum],
            );
            if (refrainRows.isNotEmpty) {
              refrainSource = {
                refrainRows.first['verse_id'] as int:
                    refrainRows.first['text'] as String,
              };
            }
          }

          if (refrainSource.containsKey(refrainVerseNum)) {
            final refrainText = refrainSource[refrainVerseNum]!;
            if (refrainPart != null) {
              final extracted = PsalmVerseSplitter.getVersePart(
                refrainText,
                refrainPart,
              );
              if (extracted != null) {
                refrain = extracted;
              }
            } else {
              // Use the full verse text (cleaned) as the refrain
              refrain = refrainText
                  .replaceFirst(RegExp(r'^\d+\.\s*'), '')
                  .trim();
            }
          }
        } else {
          // It's actual text, use it directly
          refrain = psalmResponse;
        }
      } else {
        // Try to extract from (R. N) notation in the reference
        final refrainMatch = RegExp(
          r'\(R\.\s*(\d+)([a-d])?\)',
          caseSensitive: false,
        ).firstMatch(reference);
        if (refrainMatch != null) {
          final rVerseNum = int.parse(refrainMatch.group(1)!);
          final rPart = refrainMatch.group(2);
          refrainVerseLabel = '${refrainMatch.group(1)}${rPart ?? ""}';

          if (verses.containsKey(rVerseNum)) {
            final refrainText = verses[rVerseNum]!;
            if (rPart != null) {
              final extracted = PsalmVerseSplitter.getVersePart(
                refrainText,
                rPart,
              );
              if (extracted != null) {
                refrain = extracted;
              }
            } else {
              refrain = refrainText
                  .replaceFirst(RegExp(r'^\d+\.\s*'), '')
                  .trim();
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

  /// Extract verse numbers from a single segment.
  ///
  /// Handles `+` and `&` as discrete-verse separators (e.g. "2+6", "3&5").
  /// Note: ` and ` is intentionally NOT handled here — [_extractVerseNumbers]
  /// already splits on ` and ` before calling this method.
  Set<int> _extractVerseNumbersFromSegment(String segment) {
    final verses = <int>{};

    // Handle '+' and '&' as discrete-verse separators
    final normalizedSegment = segment.replaceAll('&', '+');
    if (normalizedSegment.contains('+')) {
      for (final part in normalizedSegment.split('+')) {
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
      // Single verse (e.g., "6" or "7bc")
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
    final db = await _currentBibleDatabase;
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
    try {
      for (final db in _databaseCache.values) {
        await db.close();
      }
      _databaseCache.clear();
      _booksCache = null;
      _aliasesCache = null;
    } catch (e) {
      debugPrint('Error closing readings backend: $e');
    }
  }

  @override
  Future<void> reloadForVersionChange() async {
    _booksCache = null;
    _aliasesCache = null;
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
          verseText =
              PsalmVerseSplitter.getVerseParts(
                verseText,
                range.startVerseParts!,
              ) ??
              verseText;
        }

        if (isEndVerse &&
            range.endVerseParts != null &&
            !(isStartVerse && range.startVerseParts == range.endVerseParts)) {
          verseText =
              PsalmVerseSplitter.getVerseParts(
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

  Future<Database> _openAssetDatabase(
    String dbName, {
    bool readOnly = false,
  }) async {
    return await SharedServiceUtils.openValidatedAssetDatabase(
      dbName,
      readOnly: readOnly,
    );
  }
}
