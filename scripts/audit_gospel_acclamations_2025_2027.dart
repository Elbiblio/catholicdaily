import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:catholic_daily/data/models/bible_book.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/gospel_acclamation_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/data/services/reading_reference_parser.dart';
import 'package:catholic_daily/data/services/ultimate_gospel_acclamation_mapper.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gospel acclamation audit 2025-2027', () async {
    final report = await runAudit(startYear: 2025, endYear: 2027);
    expect(report['summary'], isA<Map<String, dynamic>>());
  }, timeout: Timeout.none);
}

Future<Map<String, dynamic>> runAudit({
  required int startYear,
  required int endYear,
}) async {
  if (startYear > endYear) {
    throw StateError('Start year must be <= end year.');
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final cwd = Directory.current.path;
  final readingsDbPath = p.join(cwd, 'assets', 'readings.db');
  final bibleDbPath = p.join(cwd, 'assets', 'rsvce.db');
  final reportDir = Directory(p.join(cwd, 'scripts', 'reports'));
  final reportPath = p.join(
    reportDir.path,
    'gospel_acclamation_audit_${startYear}_$endYear.json',
  );

  if (!File(readingsDbPath).existsSync()) {
    throw StateError('readings.db not found at $readingsDbPath');
  }
  if (!File(bibleDbPath).existsSync()) {
    throw StateError('rsvce.db not found at $bibleDbPath');
  }

  final readingsDb = await openDatabase(readingsDbPath, readOnly: true);
  final bibleDb = await openDatabase(bibleDbPath, readOnly: true);

  try {
    final auditor = _GospelAcclamationAuditor(
      readingsDb: readingsDb,
      bibleDb: bibleDb,
    );
    final report = await auditor.run(startYear: startYear, endYear: endYear);
    reportDir.createSync(recursive: true);
    File(reportPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report),
    );

    stdout.writeln('Gospel acclamation audit complete.');
    stdout.writeln('Report: $reportPath');
    stdout.writeln(jsonEncode(report['summary']));
    return report;
  } finally {
    await readingsDb.close();
    await bibleDb.close();
  }
}

class _GospelAcclamationAuditor {
  _GospelAcclamationAuditor({
    required this.readingsDb,
    required this.bibleDb,
  });

  final Database readingsDb;
  final Database bibleDb;
  final OptionalMemorialService memorialService = OptionalMemorialService.instance;
  final UltimateGospelAcclamationMapper mapper =
      UltimateGospelAcclamationMapper.instance;
  final GospelAcclamationService acclamationService = GospelAcclamationService();

  Map<String, String>? _bookAliases;

  Future<Map<String, dynamic>> run({
    required int startYear,
    required int endYear,
  }) async {
    final aliases = await _getBookAliases();
    final issues = <Map<String, dynamic>>[];
    final issueCounts = <String, int>{};
    var datesScanned = 0;
    var readingSetsScanned = 0;
    var readingsScanned = 0;
    var datesWithReadings = 0;

    for (var year = startYear; year <= endYear; year++) {
      var day = DateTime.utc(year, 1, 1);
      final end = DateTime.utc(year, 12, 31);
      while (!day.isAfter(end)) {
        datesScanned++;
        final ferialReadings = await _loadReadingsForDate(day);
        final readingSets = _buildReadingSets(day, ferialReadings);
        if (readingSets.any((set) => set.readings.isNotEmpty)) {
          datesWithReadings++;
        }
        for (final set in readingSets) {
          if (set.readings.isEmpty) {
            continue;
          }
          readingSetsScanned++;
          final gospelEntries = set.readings
              .where((reading) => _isGospelPosition(reading.position))
              .toList();
          if (gospelEntries.isEmpty) {
            _addIssue(
              issues,
              issueCounts,
              type: 'missing_gospel_reading',
              date: day,
              readingSetLabel: set.label,
              celebrationId: set.celebrationId,
              details: {'reading_count': set.readings.length},
            );
            continue;
          }

          for (final gospelReading in gospelEntries) {
            readingsScanned++;
            final storedAcclamation = gospelReading.gospelAcclamation?.trim();
            final mapped = mapper.getAcclamation(
              date: day,
              gospelReference: gospelReading.reading,
            );
            final resolvedText = mapped.text.trim();
            final decodedStored = await _decodeStoredAcclamation(storedAcclamation);
            final decodedMappedReference = await _decodeReferenceIfNeeded(mapped.reference);

            final issueTypes = <String>{};
            if (storedAcclamation == null || storedAcclamation.isEmpty) {
              issueTypes.add('missing_stored_acclamation');
            }
            if (resolvedText.isEmpty) {
              issueTypes.add('mapped_text_empty');
            }
            if (resolvedText.startsWith('Reading text unavailable')) {
              issueTypes.add('mapped_text_unavailable');
            }
            if (_looksLikeReference(resolvedText)) {
              issueTypes.add('mapped_text_still_reference');
            }
            if (_looksSuspiciouslyLong(resolvedText)) {
              issueTypes.add('mapped_text_suspiciously_long');
            }
            if (storedAcclamation != null &&
                storedAcclamation.isNotEmpty &&
                acclamationService.shouldResolveReference(storedAcclamation) &&
                decodedStored != null &&
                _looksSuspiciouslyLong(decodedStored) &&
                !_looksSuspiciouslyLong(resolvedText)) {
              issueTypes.add('stored_reference_would_leak_long_text');
            }
            if (storedAcclamation != null &&
                storedAcclamation.isNotEmpty &&
                acclamationService.shouldResolveReference(storedAcclamation) &&
                !_sameReference(storedAcclamation, mapped.reference)) {
              issueTypes.add('stored_reference_differs_from_mapped_reference');
            }
            if (decodedMappedReference != null &&
                _looksSuspiciouslyLong(decodedMappedReference) &&
                !_looksSuspiciouslyLong(resolvedText)) {
              issueTypes.add('mapped_reference_decodes_to_longer_full_verse');
            }
            if (_hasProblematicContent(resolvedText)) {
              issueTypes.add('mapped_text_contains_problematic_content');
            }

            for (final type in issueTypes) {
              _addIssue(
                issues,
                issueCounts,
                type: type,
                date: day,
                readingSetLabel: set.label,
                celebrationId: set.celebrationId,
                gospelReference: gospelReading.reading,
                details: {
                  'stored_acclamation': storedAcclamation,
                  'mapped_reference': mapped.reference,
                  'mapped_text': resolvedText,
                  'mapped_source': mapped.source.name,
                  'mapped_season': mapped.season,
                  'mapped_verse_id': mapped.verseId,
                  'decoded_stored_acclamation': decodedStored,
                  'decoded_mapped_reference': decodedMappedReference,
                  'is_optional_memorial_suppressed': memorialService.isSuppressedDate(day),
                },
              );
            }
          }
        }
        day = day.add(const Duration(days: 1));
      }
    }

    final uniqueMappedReferences = <String>{};
    final uniqueStoredReferences = <String>{};
    final rows = await readingsDb.rawQuery(
      'SELECT DISTINCT gospel_acclamation FROM readings WHERE gospel_acclamation IS NOT NULL AND TRIM(gospel_acclamation) <> ""',
    );
    for (final row in rows) {
      final value = (row['gospel_acclamation'] as String?)?.trim();
      if (value != null && value.isNotEmpty) {
        uniqueStoredReferences.add(value);
      }
    }
    for (var year = startYear; year <= endYear; year++) {
      var day = DateTime.utc(year, 1, 1);
      final end = DateTime.utc(year, 12, 31);
      while (!day.isAfter(end)) {
        final ferialReadings = await _loadReadingsForDate(day);
        final readingSets = _buildReadingSets(day, ferialReadings);
        for (final set in readingSets) {
          for (final reading in set.readings.where((r) => _isGospelPosition(r.position))) {
            uniqueMappedReferences.add(
              mapper.getAcclamation(date: day, gospelReference: reading.reading).reference,
            );
          }
        }
        day = day.add(const Duration(days: 1));
      }
    }

    return {
      'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'range_start': '$startYear-01-01',
      'range_end': '$endYear-12-31',
      'summary': {
        'dates_scanned': datesScanned,
        'dates_with_readings': datesWithReadings,
        'reading_sets_scanned': readingSetsScanned,
        'gospel_readings_scanned': readingsScanned,
        'unique_stored_acclamations': uniqueStoredReferences.length,
        'unique_mapped_references_seen': uniqueMappedReferences.length,
        'total_issues': issues.length,
        'issue_counts': issueCounts,
      },
      'issues': issues,
      'heuristics': {
        'suspicious_long_word_threshold': 24,
        'problematic_content_checks': [
          'reading text unavailable',
          'thus says the lord',
          'oracle of the lord',
        ],
      },
      'book_alias_count': aliases.length,
    };
  }

  Future<List<DailyReading>> _loadReadingsForDate(DateTime date) async {
    final rows = await readingsDb.rawQuery(
      'SELECT reading, position, gospel_acclamation FROM readings WHERE timestamp = ? ORDER BY position',
      [_timestampForDate(date)],
    );
    return rows.map((row) {
      final positionValue = row['position'];
      final positionInt = positionValue is int
          ? positionValue
          : int.tryParse('$positionValue');
      return DailyReading(
        reading: row['reading'] as String,
        position: _positionLabel(positionInt, row['reading'] as String, rows.length),
        date: date,
        gospelAcclamation: row['gospel_acclamation'] as String?,
      );
    }).toList();
  }

  List<_ReadingSet> _buildReadingSets(DateTime date, List<DailyReading> ferialReadings) {
    final sets = <_ReadingSet>[
      _ReadingSet(
        label: '${_weekdayName(date.weekday)} — Weekday',
        readings: ferialReadings,
      ),
    ];
    for (final celebration in memorialService.getAllCelebrationsForDate(date)) {
      final proper = memorialService.getProperReadings(celebration.id);
      if (proper == null) {
        sets.add(
          _ReadingSet(
            label: '${celebration.title} (weekday readings)',
            celebrationId: celebration.id,
            readings: ferialReadings,
          ),
        );
        continue;
      }
      final readings = <DailyReading>[
        DailyReading(
          reading: proper.firstReading,
          position: 'First Reading',
          date: date,
          feast: celebration.title,
        ),
        if (proper.alternativeFirstReading != null)
          DailyReading(
            reading: proper.alternativeFirstReading!,
            position: 'First Reading (alternative)',
            date: date,
            feast: celebration.title,
          ),
        DailyReading(
          reading: proper.psalm,
          position: 'Responsorial Psalm',
          date: date,
          feast: celebration.title,
          psalmResponse: proper.psalmResponse,
        ),
        if (proper.secondReading != null)
          DailyReading(
            reading: proper.secondReading!,
            position: 'Second Reading',
            date: date,
            feast: celebration.title,
          ),
        DailyReading(
          reading: proper.gospel,
          position: 'Gospel',
          date: date,
          feast: celebration.title,
          gospelAcclamation: proper.gospelAcclamation,
        ),
        if (proper.alternativeGospel != null)
          DailyReading(
            reading: proper.alternativeGospel!,
            position: 'Gospel (alternative)',
            date: date,
            feast: celebration.title,
            gospelAcclamation: proper.gospelAcclamation,
          ),
      ];
      sets.add(
        _ReadingSet(
          label: celebration.title,
          celebrationId: celebration.id,
          readings: readings,
        ),
      );
    }
    return sets;
  }

  Future<String?> _decodeStoredAcclamation(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (!acclamationService.shouldResolveReference(trimmed)) {
      return trimmed;
    }
    return _decodeReferenceIfNeeded(trimmed);
  }

  Future<String?> _decodeReferenceIfNeeded(String? reference) async {
    if (reference == null || reference.trim().isEmpty) return null;
    final cleaned = reference
        .replaceFirst(RegExp(r'^(See|Cf\.?)+\s+', caseSensitive: false), '')
        .replaceAll('+', ',')
        .trim();
    final ranges = ReadingReferenceParser.parse(cleaned);
    if (ranges.isEmpty) {
      return cleaned;
    }
    final aliases = await _getBookAliases();
    final parts = <String>[];
    for (final range in ranges) {
      final shortName = ReadingReferenceParser.resolveBookShortName(
        range.book,
        aliases,
      );
      if (shortName == null) {
        return cleaned;
      }
      final rows = await _fetchRange(shortName: shortName, range: range);
      if (rows.isEmpty) {
        return cleaned;
      }
      parts.addAll(rows);
    }
    final text = parts
        .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? cleaned : text;
  }

  Future<List<String>> _fetchRange({
    required String shortName,
    required ScriptureRange range,
  }) async {
    final lines = <String>[];
    for (var chapter = range.startChapter; chapter <= range.endChapter; chapter++) {
      final startVerse = chapter == range.startChapter ? range.startVerse : 1;
      final endVerse = chapter == range.endChapter ? range.endVerse : null;
      final args = <Object?>[shortName, chapter, startVerse];
      final where = StringBuffer(
        'b.shortname = ? AND v.chapter_id = ? AND v.verse_id >= ?',
      );
      if (endVerse != null) {
        where.write(' AND v.verse_id <= ?');
        args.add(endVerse);
      }
      final rows = await bibleDb.rawQuery(
        'SELECT v.verse_id, v.text FROM verses v JOIN books b ON b._id = v.book_id WHERE ${where.toString()} ORDER BY v._id',
        args,
      );
      for (final row in rows) {
        lines.add('${row['verse_id']}. ${row['text']}');
      }
    }
    return lines;
  }

  Future<Map<String, String>> _getBookAliases() async {
    if (_bookAliases != null) return _bookAliases!;
    final rows = await bibleDb.rawQuery(
      'SELECT b._id AS id, b.text AS name, b.shortname AS shortname, MAX(v.chapter_id) AS chapter_count FROM books b LEFT JOIN verses v ON v.book_id = b._id GROUP BY b._id, b.text, b.shortname ORDER BY b._id',
    );
    final books = rows
        .map(
          (row) => Book(
            id: row['id'] as int,
            name: row['name'] as String,
            shortName: row['shortname'] as String,
            chapterCount: row['chapter_count'] as int? ?? 0,
          ),
        )
        .toList();
    _bookAliases = ReadingReferenceParser.buildBookAliasMap(books);
    return _bookAliases!;
  }

  void _addIssue(
    List<Map<String, dynamic>> issues,
    Map<String, int> issueCounts, {
    required String type,
    required DateTime date,
    required String readingSetLabel,
    required Map<String, dynamic> details,
    String? celebrationId,
    String? gospelReference,
  }) {
    issueCounts.update(type, (value) => value + 1, ifAbsent: () => 1);
    issues.add({
      'type': type,
      'date': date.toIso8601String().split('T').first,
      'reading_set_label': readingSetLabel,
      'celebration_id': celebrationId,
      'gospel_reference': gospelReference,
      'details': details,
    });
  }

  bool _looksSuspiciouslyLong(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;
    final wordCount = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return wordCount >= 24 || normalized.length >= 180;
  }

  bool _looksLikeReference(String text) {
    return RegExp(
      r'^(?:See\s+|Cf\.?\s+)?(?:(?:[1-3]\s)?[A-Za-z]+(?:\s+[A-Za-z]+)*)\s+\d+:\d+',
      caseSensitive: false,
    ).hasMatch(text.trim());
  }

  bool _sameReference(String left, String right) {
    String normalize(String value) {
      return value
          .trim()
          .toLowerCase()
          .replaceFirst(RegExp(r'^(see\s+|cf\.?\s+)', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^mt\s+'), 'matthew ')
          .replaceFirst(RegExp(r'^mk\s+'), 'mark ')
          .replaceFirst(RegExp(r'^lk\s+'), 'luke ')
          .replaceFirst(RegExp(r'^jn\s+'), 'john ')
          .replaceFirst(RegExp(r'^ps\s+'), 'psalm ')
          .replaceAll(RegExp(r'\s+'), ' ');
    }

    return normalize(left) == normalize(right);
  }

  bool _hasProblematicContent(String text) {
    final lower = text.toLowerCase();
    return lower.contains('reading text unavailable') ||
        lower.contains('thus says the lord') ||
        lower.contains('oracle of the lord');
  }

  bool _isGospelPosition(String? position) {
    final normalized = position?.toLowerCase() ?? '';
    return normalized.contains('gospel');
  }

  int _timestampForDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day, 8)
            .millisecondsSinceEpoch ~/
        1000;
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _positionLabel(int? position, String reading, int totalRows) {
    if (position == null) {
      return 'Reading';
    }
    final normalized = reading.trim().toLowerCase();
    final isGospel = normalized.startsWith('matt ') ||
        normalized.startsWith('mark ') ||
        normalized.startsWith('luke ') ||
        normalized.startsWith('john ');
    if (isGospel) {
      return 'Gospel';
    }
    final isPsalmLike = normalized.startsWith('ps ') ||
        normalized.startsWith('psalm ') ||
        normalized.startsWith('isa 12') ||
        normalized.startsWith('exod 15') ||
        normalized.startsWith('1 sam 2') ||
        normalized.startsWith('luke 1:');
    if (isPsalmLike) {
      return 'Responsorial Psalm';
    }
    switch (position) {
      case 1:
        return 'First Reading';
      case 2:
        return 'Responsorial Psalm';
      case 3:
        return totalRows >= 4 ? 'Second Reading' : 'Verse Before the Gospel';
      case 4:
        return 'Gospel';
      default:
        return 'Reading';
    }
  }
}

class _ReadingSet {
  const _ReadingSet({
    required this.label,
    required this.readings,
    this.celebrationId,
  });

  final String label;
  final String? celebrationId;
  final List<DailyReading> readings;
}
