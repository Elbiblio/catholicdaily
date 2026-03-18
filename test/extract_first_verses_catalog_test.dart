import 'dart:io';

import 'package:catholic_daily/data/services/reading_reference_parser.dart';
import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:catholic_daily/data/services/reading_catalog_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

/// Extracts the first verse text for every first_reading and gospel in
/// standard_lectionary_complete.csv using the RSVCE database.
///
/// Outputs:
///   scripts/first_verse_catalog.csv   – full catalog of all first verses
///   scripts/problematic_incipits.csv  – only the entries flagged as needing
///                                       a custom incipit
void main() {
  setupFlutterTestEnvironment();

  late Directory tempDocsDir;
  late void Function() cleanupMocks;

  setUpAll(() async {
    tempDocsDir = await createTempTestDir('catholic_daily_first_verses_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  test('extract first verse catalog and flag problematic incipits', () async {
    final backend = ReadingsBackendIo();
    final books = await backend.getBooks();
    final aliases = ReadingReferenceParser.buildBookAliasMap(books);

    // ── Load CSV ──────────────────────────────────────────────────────────
    final rawCsv =
        await rootBundle.loadString('standard_lectionary_complete.csv');
    final lines = rawCsv
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final header = ReadingCatalogService.instance.parseCsvLine(lines[0]);

    // Column indices
    final colSeason = 0;
    final colWeek = 1;
    final colDay = 2;
    final colWeekdayCycle = 3;
    final colSundayCycle = 4;
    final colFirstReading = 6;
    final colGospel = 10;
    final colLectNum = 13;
    final colFirstReadingIncipit = header.length > 14 ? 14 : -1;
    final colGospelIncipit = header.length > 15 ? 15 : -1;

    // ── Output buffers ────────────────────────────────────────────────────
    final catalogRows = <String>[
      'row,season,week,day,weekday_cycle,sunday_cycle,lectionary_number,'
          'type,reference,first_verse_text,current_incipit,flag_reason',
    ];
    final problematicRows = <String>[catalogRows.first];

    var processed = 0;
    var flagged = 0;

    for (var i = 1; i < lines.length; i++) {
      final cols = ReadingCatalogService.instance.parseCsvLine(lines[i]);
      if (cols.length < 11) continue;

      final season = cols[colSeason].trim();
      final week = cols[colWeek].trim();
      final day = cols[colDay].trim();
      final weekdayCycle = cols[colWeekdayCycle].trim();
      final sundayCycle = cols[colSundayCycle].trim();
      final lectNum = cols.length > colLectNum ? cols[colLectNum].trim() : '';

      // Process both first_reading and gospel
      final refs = <({String type, String ref, String currentIncipit})>[
        if (cols[colFirstReading].trim().isNotEmpty)
          (
            type: 'first_reading',
            ref: cols[colFirstReading].trim(),
            currentIncipit: colFirstReadingIncipit >= 0 &&
                    cols.length > colFirstReadingIncipit
                ? cols[colFirstReadingIncipit].trim()
                : '',
          ),
        if (cols[colGospel].trim().isNotEmpty)
          (
            type: 'gospel',
            ref: cols[colGospel].trim(),
            currentIncipit:
                colGospelIncipit >= 0 && cols.length > colGospelIncipit
                    ? cols[colGospelIncipit].trim()
                    : '',
          ),
      ];

      for (final entry in refs) {
        final firstVerse = await _fetchFirstVerse(
          reference: entry.ref,
          aliases: aliases,
          backend: backend,
        );

        final reasons = _flagReasons(firstVerse, entry.ref, entry.type);

        final row = _csvRow([
          '$i',
          season,
          week,
          day,
          weekdayCycle,
          sundayCycle,
          lectNum,
          entry.type,
          entry.ref,
          firstVerse,
          entry.currentIncipit,
          reasons.join('; '),
        ]);

        catalogRows.add(row);
        processed++;

        if (reasons.isNotEmpty) {
          problematicRows.add(row);
          flagged++;
        }
      }
    }

    // ── Write outputs ─────────────────────────────────────────────────────
    final catalogFile =
        File(r'c:\dev\catholicdaily-flutter\scripts\first_verse_catalog.csv');
    await catalogFile.writeAsString(catalogRows.join('\n'));

    final problematicFile = File(
        r'c:\dev\catholicdaily-flutter\scripts\problematic_incipits.csv');
    await problematicFile.writeAsString(problematicRows.join('\n'));

    print('Processed: $processed readings');
    print('Flagged:   $flagged problematic');
    print('Wrote:     ${catalogFile.path}');
    print('Wrote:     ${problematicFile.path}');

    expect(processed, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 10)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// Clean a CSV reference before parsing.
String _cleanReference(String ref) {
  var r = ref.trim();
  // Remove parenthetical annotations: (proper), (Vigil Mass), (shorter form), etc.
  r = r.replaceAll(RegExp(r'\s*\(proper\)', caseSensitive: false), '');
  r = r.replaceAll(RegExp(r'\s*\(shorter[^)]*\)', caseSensitive: false), '');
  r = r.replaceFirst(RegExp(r'^\(Vigil Mass\)\s*', caseSensitive: false), '');
  // Normalize en-dash / em-dash to hyphen
  r = r.replaceAll('\u2013', '-').replaceAll('\u2014', '-');
  // Normalize " – " (space-en-dash-space) used as range separator to semicolon
  // e.g., "Heb 7:25 - 8.6" → "Heb 7:25; 8.6"  (cross-chapter)
  r = r.replaceAllMapped(
    RegExp(r'(\d)\s+-\s+(\d)'),
    (m) => '${m.group(1)}; ${m.group(2)}',
  );
  // Convert period notation chapter.verse to colon
  // e.g., "8.6" → "8:6"  but only for standalone chapter.verse tokens
  r = r.replaceAllMapped(
    RegExp(r'(\d+)\.(\d+)'),
    (m) => '${m.group(1)}:${m.group(2)}',
  );
  return r;
}

/// Fetch the raw first verse text from the RSVCE database for [reference].
Future<String> _fetchFirstVerse({
  required String reference,
  required Map<String, String> aliases,
  required ReadingsBackendIo backend,
}) async {
  try {
    final cleaned = _cleanReference(reference);
    final ranges = ReadingReferenceParser.parse(cleaned);
    if (ranges.isEmpty) return '[PARSE_ERROR: $cleaned]';

    final first = ranges.first;
    final shortName =
        ReadingReferenceParser.resolveBookShortName(first.book, aliases);
    if (shortName == null) return '[BOOK_NOT_FOUND: ${first.book}]';

    // Use getChapterText to get all verses, then pick the target verse
    final chapterText = await backend.getChapterText(
      bookShortName: shortName,
      chapter: first.startChapter,
    );

    if (chapterText.startsWith('Chapter text unavailable')) {
      return '[NO_CHAPTER: $shortName ${first.startChapter}]';
    }

    // Parse the chapter text to find the specific verse
    final verseLines = chapterText.split('\n');
    final targetVerse = first.startVerse;

    for (final line in verseLines) {
      final match = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(line);
      if (match != null && int.parse(match.group(1)!) == targetVerse) {
        return match.group(2)!.trim();
      }
    }

    return '[VERSE_NOT_FOUND: $shortName ${first.startChapter}:$targetVerse]';
  } catch (e) {
    return '[ERROR: $e]';
  }
}

/// Returns a list of flag reasons for the first verse text.
/// Empty list means no problems detected.
List<String> _flagReasons(String verseText, String reference, String type) {
  final reasons = <String>[];

  if (verseText.startsWith('[')) {
    reasons.add('extraction_failed');
    return reasons;
  }

  final trimmed = verseText.trim();
  if (trimmed.isEmpty) {
    reasons.add('empty_verse');
    return reasons;
  }

  final lower = trimmed.toLowerCase();
  final firstWord = lower.split(RegExp(r'[\s,]+')).first;

  // ── Rule 1: Starts with conjunction ────────────────────────────────────
  const conjunctions = {
    'and', 'but', 'or', 'nor', 'for', 'yet', 'so', 'then', 'thus',
    'therefore', 'moreover', 'however', 'nevertheless', 'meanwhile',
    'afterwards', 'afterward', 'also', 'besides', 'furthermore',
    'consequently', 'accordingly', 'hence', 'likewise', 'similarly',
    'nonetheless', 'otherwise', 'still', 'instead', 'rather',
    'since', 'while', 'when', 'now', 'again',
  };
  if (conjunctions.contains(firstWord)) {
    reasons.add('starts_with_conjunction:$firstWord');
  }

  // ── Rule 2: Starts with pronoun ────────────────────────────────────────
  const pronouns = {
    'he', 'she', 'it', 'they', 'we', 'his', 'her', 'its', 'their', 'our',
    'him', 'them', 'us', 'himself', 'herself', 'itself', 'themselves',
    'this', 'that', 'these', 'those', 'who', 'whom', 'whose', 'which',
  };
  if (pronouns.contains(firstWord)) {
    reasons.add('starts_with_pronoun:$firstWord');
  }

  // ── Rule 3: Continuation markers ──────────────────────────────────────
  // Sentences that seem to continue from a missing context
  if (lower.startsWith('the same') ||
      lower.startsWith('at the same') ||
      lower.startsWith('on that') ||
      lower.startsWith('in the same') ||
      lower.startsWith('after this') ||
      lower.startsWith('after that') ||
      lower.startsWith('at once') ||
      lower.startsWith('immediately') ||
      lower.startsWith('as soon as')) {
    if (!reasons.any((r) => r.startsWith('starts_with_'))) {
      reasons.add('continuation_marker');
    }
  }

  // ── Rule 4: Ambiguous subject references ──────────────────────────────
  // Mid-sentence constructions that lack antecedent
  if (RegExp(r'^(the|a)\s+(man|woman|boy|girl|servant|centurion|pharisee)',
          caseSensitive: false)
      .hasMatch(trimmed)) {
    // These are usually fine — proper starts
  } else if (RegExp(r'^(the|a)\s+\w+\s+(said|answered|replied|asked|went|came)',
          caseSensitive: false)
      .hasMatch(trimmed)) {
    // Could be continuation — check if "the" refers to previously-named person
    // Flag conservatively
  }

  // ── Rule 5: Verse starts mid-sentence (lowercase after stripping number) ─
  // If the original verse text in the DB starts lowercase, it's likely
  // mid-sentence in the original
  if (trimmed.isNotEmpty &&
      trimmed[0] == trimmed[0].toLowerCase() &&
      RegExp(r'^[a-z]').hasMatch(trimmed)) {
    reasons.add('starts_lowercase');
  }

  // ── Rule 6: Check for "those who" / "the one who" at start ─────────────
  if (lower.startsWith('those who') || lower.startsWith('the one who')) {
    reasons.add('relative_clause_start');
  }

  return reasons;
}

/// Escape a value for CSV and join columns.
String _csvRow(List<String> cols) {
  return cols.map(_csvEscape).join(',');
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
