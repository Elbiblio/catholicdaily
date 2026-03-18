import 'dart:io';

import 'package:catholic_daily/data/services/official_lectionary_incipit_service.dart';
import 'package:catholic_daily/data/services/reading_catalog_service.dart';
import 'package:catholic_daily/data/services/reading_reference_parser.dart';
import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

/// Comprehensive audit of what the app ACTUALLY renders as the first line
/// for every first_reading and gospel in standard_lectionary_complete.csv
/// AND memorial_feasts.csv.
///
/// For each reading, this simulates the full rendering pipeline:
///   1. Fetch raw DB text
///   2. Apply OfficialLectionaryIncipitService (pronoun correction + incipit derivation)
///   3. Apply CSV incipit override if present
///   4. Extract the displayed first line
///   5. Flag quality issues
///
/// Outputs:
///   scripts/rendered_audit.csv          — full audit of all readings
///   scripts/rendered_problems.csv       — only entries with quality issues
///   scripts/rendered_audit_summary.txt  — counts and categories
void main() {
  setupFlutterTestEnvironment();

  late Directory tempDocsDir;
  late void Function() cleanupMocks;

  setUpAll(() async {
    tempDocsDir = await createTempTestDir('catholic_daily_rendered_audit_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  test('comprehensive rendered incipit audit', () async {
    final backend = ReadingsBackendIo();
    final incipitService = OfficialLectionaryIncipitService();
    final books = await backend.getBooks();
    final aliases = ReadingReferenceParser.buildBookAliasMap(books);

    final allRows = <_AuditRow>[];

    // ── Part 1: standard_lectionary_complete.csv ──────────────────────────
    final rawCsv =
        await rootBundle.loadString('standard_lectionary_complete.csv');
    final csvLines = rawCsv
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    for (var i = 1; i < csvLines.length; i++) {
      final cols = ReadingCatalogService.instance.parseCsvLine(csvLines[i]);
      if (cols.length < 14) continue;

      final season = cols[0].trim();
      final week = cols[1].trim();
      final day = cols[2].trim();
      final cycle = cols[3].trim().isNotEmpty ? cols[3].trim() : cols[4].trim();
      final lectNum = cols[13].trim();
      final firstReading = cols[6].trim();
      final gospel = cols[10].trim();
      final csvFrIncipit = cols.length > 14 ? cols[14].trim() : '';
      final csvGospelIncipit = cols.length > 15 ? cols[15].trim() : '';

      final dayLabel = '$season/$week/$day/$cycle';

      if (firstReading.isNotEmpty) {
        final row = await _auditReading(
          source: 'standard',
          dayLabel: dayLabel,
          lectNum: lectNum,
          type: 'first_reading',
          reference: firstReading,
          csvIncipit: csvFrIncipit,
          backend: backend,
          incipitService: incipitService,
          aliases: aliases,
        );
        allRows.add(row);
      }

      if (gospel.isNotEmpty) {
        final row = await _auditReading(
          source: 'standard',
          dayLabel: dayLabel,
          lectNum: lectNum,
          type: 'gospel',
          reference: gospel,
          csvIncipit: csvGospelIncipit,
          backend: backend,
          incipitService: incipitService,
          aliases: aliases,
        );
        allRows.add(row);
      }
    }

    // ── Part 2: memorial_feasts.csv ──────────────────────────────────────
    final memCsv = await rootBundle.loadString('memorial_feasts.csv');
    final memLines = memCsv
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    for (var i = 1; i < memLines.length; i++) {
      final cols = ReadingCatalogService.instance.parseCsvLine(memLines[i]);
      if (cols.length < 21) continue;

      final title = cols[1].trim();
      final firstReading = cols[8].trim();
      final altFirstReading = cols[9].trim();
      final firstReadingIncipit = cols[10].trim();
      final altFirstReadingIncipit = cols[11].trim();
      final gospel = cols[16].trim();
      final altGospel = cols[18].trim();
      final gospelIncipit = cols[17].trim();
      final altGospelIncipit = cols[19].trim();

      for (final entry in [
        if (firstReading.isNotEmpty) 
          ('first_reading', firstReading, firstReadingIncipit),
        if (altFirstReading.isNotEmpty) 
          ('first_reading_alt', altFirstReading, altFirstReadingIncipit),
        if (gospel.isNotEmpty) 
          ('gospel', gospel, gospelIncipit),
        if (altGospel.isNotEmpty) 
          ('gospel_alt', altGospel, altGospelIncipit),
      ]) {
        final row = await _auditReading(
          source: 'memorial',
          dayLabel: title,
          lectNum: '',
          type: entry.$1,
          reference: entry.$2,
          csvIncipit: entry.$3, // Use the actual incipit from CSV
          backend: backend,
          incipitService: incipitService,
          aliases: aliases,
        );
        allRows.add(row);
      }
    }

    // ── Write outputs ────────────────────────────────────────────────────
    final header =
        'source,day_label,lect_num,type,reference,csv_incipit,derived_incipit,'
        'db_first_verse,rendered_first_line,problems';

    final fullRows = <String>[header];
    final problemRows = <String>[header];
    final problemCounts = <String, int>{};

    for (final row in allRows) {
      final line = _csvRow([
        row.source,
        row.dayLabel,
        row.lectNum,
        row.type,
        row.reference,
        row.csvIncipit,
        row.derivedIncipit,
        row.dbFirstVerse,
        row.renderedFirstLine,
        row.problems.join('; '),
      ]);
      fullRows.add(line);

      if (row.problems.isNotEmpty) {
        problemRows.add(line);
        for (final p in row.problems) {
          final key = p.split(':').first;
          problemCounts[key] = (problemCounts[key] ?? 0) + 1;
        }
      }
    }

    File(r'c:\dev\catholicdaily-flutter\scripts\rendered_audit.csv')
        .writeAsStringSync(fullRows.join('\n'));
    File(r'c:\dev\catholicdaily-flutter\scripts\rendered_problems.csv')
        .writeAsStringSync(problemRows.join('\n'));

    // Summary
    final summary = StringBuffer();
    summary.writeln('Rendered Incipit Audit Summary');
    summary.writeln('=' * 50);
    summary.writeln('Total readings audited: ${allRows.length}');
    summary.writeln('  Standard CSV: ${allRows.where((r) => r.source == 'standard').length}');
    summary.writeln('  Memorial feasts: ${allRows.where((r) => r.source == 'memorial').length}');
    summary.writeln('');
    summary.writeln('Readings with problems: ${problemRows.length - 1}');
    summary.writeln('Readings without problems: ${allRows.length - (problemRows.length - 1)}');
    summary.writeln('');
    summary.writeln('Problem distribution:');
    final sorted = problemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      summary.writeln('  ${e.value.toString().padLeft(5)}  ${e.key}');
    }

    File(r'c:\dev\catholicdaily-flutter\scripts\rendered_audit_summary.txt')
        .writeAsStringSync(summary.toString());

    print(summary.toString());
    expect(allRows.length, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 15)));
}

// ═══════════════════════════════════════════════════════════════════════════════

class _AuditRow {
  final String source;
  final String dayLabel;
  final String lectNum;
  final String type;
  final String reference;
  final String csvIncipit;
  final String derivedIncipit;
  final String dbFirstVerse;
  final String renderedFirstLine;
  final List<String> problems;

  const _AuditRow({
    required this.source,
    required this.dayLabel,
    required this.lectNum,
    required this.type,
    required this.reference,
    required this.csvIncipit,
    required this.derivedIncipit,
    required this.dbFirstVerse,
    required this.renderedFirstLine,
    required this.problems,
  });
}

Future<_AuditRow> _auditReading({
  required String source,
  required String dayLabel,
  required String lectNum,
  required String type,
  required String reference,
  required String csvIncipit,
  required ReadingsBackendIo backend,
  required OfficialLectionaryIncipitService incipitService,
  required Map<String, String> aliases,
}) async {
  // 1. Get raw DB first verse
  final dbFirstVerse = await _fetchFirstVerse(reference, aliases, backend);

  // 2. Get full rendered text (simulates getReadingText)
  String renderedFirstLine = '';
  String derivedIncipit = '';
  try {
    final fullRendered = await backend.getReadingText(
      reference,
      incipit: csvIncipit.isNotEmpty ? csvIncipit : null,
    );
    // Extract first non-empty line
    renderedFirstLine = fullRendered
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');

    // Also get the derived incipit (what the service would generate)
    final candidate = incipitService.getOfficialIncipit(reference);
    derivedIncipit = candidate ?? '';
  } catch (e) {
    renderedFirstLine = '[RENDER_ERROR: $e]';
  }

  // 3. Flag quality issues
  final problems = _detectProblems(
    reference: reference,
    type: type,
    csvIncipit: csvIncipit,
    derivedIncipit: derivedIncipit,
    dbFirstVerse: dbFirstVerse,
    renderedFirstLine: renderedFirstLine,
  );

  return _AuditRow(
    source: source,
    dayLabel: dayLabel,
    lectNum: lectNum,
    type: type,
    reference: reference,
    csvIncipit: csvIncipit,
    derivedIncipit: derivedIncipit,
    dbFirstVerse: dbFirstVerse,
    renderedFirstLine: renderedFirstLine,
    problems: problems,
  );
}

Future<String> _fetchFirstVerse(
  String reference,
  Map<String, String> aliases,
  ReadingsBackendIo backend,
) async {
  try {
    // Clean reference
    var ref = reference.trim();
    ref = ref.replaceAll(RegExp(r'\s*\(proper\)', caseSensitive: false), '');
    ref = ref.replaceFirst(RegExp(r'^\(Vigil Mass\)\s*', caseSensitive: false), '');
    ref = ref.replaceAll('\u2013', '-').replaceAll('\u2014', '-');
    ref = ref.replaceAllMapped(
      RegExp(r'(\d)\s+-\s+(\d)'), (m) => '${m.group(1)}; ${m.group(2)}');
    ref = ref.replaceAllMapped(
      RegExp(r'(\d+)\.(\d+)'), (m) => '${m.group(1)}:${m.group(2)}');

    final ranges = ReadingReferenceParser.parse(ref);
    if (ranges.isEmpty) return '[PARSE_ERROR]';

    final first = ranges.first;
    final shortName =
        ReadingReferenceParser.resolveBookShortName(first.book, aliases);
    if (shortName == null) return '[BOOK_NOT_FOUND: ${first.book}]';

    final chapterText = await backend.getChapterText(
      bookShortName: shortName,
      chapter: first.startChapter,
    );
    if (chapterText.startsWith('Chapter text unavailable')) {
      return '[NO_CHAPTER: $shortName ${first.startChapter}]';
    }

    for (final line in chapterText.split('\n')) {
      final match = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(line);
      if (match != null && int.parse(match.group(1)!) == first.startVerse) {
        return match.group(2)!.trim();
      }
    }
    return '[VERSE_NOT_FOUND]';
  } catch (e) {
    return '[ERROR: $e]';
  }
}

List<String> _detectProblems({
  required String reference,
  required String type,
  required String csvIncipit,
  required String derivedIncipit,
  required String dbFirstVerse,
  required String renderedFirstLine,
}) {
  final problems = <String>[];
  final rendered = renderedFirstLine.trim();

  if (rendered.isEmpty || rendered.startsWith('[')) {
    problems.add('render_failed');
    return problems;
  }

  if (rendered.startsWith('Reading text unavailable')) {
    problems.add('text_unavailable');
    return problems;
  }

  // ── P1: Verse number visible in rendered text ──────────────────────────
  if (RegExp(r'^\d+[a-z]?\.\s').hasMatch(rendered)) {
    // This is the raw DB format — verse number showing means no incipit was applied
    // Check if the verse text after the number is problematic
    final afterNum = rendered.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    final firstWord = afterNum.toLowerCase().split(RegExp(r'[\s,]+')).first;
    if (_conjunctions.contains(firstWord)) {
      problems.add('raw_verse_conjunction:$firstWord');
    }
    if (_pronouns.contains(firstWord)) {
      problems.add('raw_verse_pronoun:$firstWord');
    }
    if (afterNum.isNotEmpty && afterNum[0] == afterNum[0].toLowerCase() &&
        RegExp(r'^[a-z]').hasMatch(afterNum)) {
      problems.add('raw_verse_lowercase');
    }
  }

  // ── P2: Embedded verse number visible in RENDERED output ────────────────
  // Check the actual rendered first line for leftover "NN. " patterns
  if (RegExp(r'^\d+[a-z]?\.\s').hasMatch(rendered) &&
      !rendered.startsWith('1.') && // verse 1 at start is common/acceptable
      rendered.length > 5) {
    problems.add('verse_number_in_rendered');
  }

  // ── P3: Tautological incipit + verse text ──────────────────────────────
  // "At that time: One day, while Jesus..."
  // "In those days: Now..."
  // "At that time: At that time..."
  final incipitUsed = csvIncipit.isNotEmpty ? csvIncipit : derivedIncipit;
  if (incipitUsed.isNotEmpty) {
    final afterColon = _textAfterIncipit(rendered, incipitUsed);
    if (afterColon.isNotEmpty) {
      final lower = afterColon.toLowerCase().trim();
      // Check for temporal tautology
      if (incipitUsed.toLowerCase().contains('at that time') &&
          (lower.startsWith('one day') ||
           lower.startsWith('once') ||
           lower.startsWith('on that day') ||
           lower.startsWith('at that time') ||
           lower.startsWith('on one occasion'))) {
        problems.add('tautology_temporal');
      }
      if (incipitUsed.toLowerCase().contains('in those days') &&
          (lower.startsWith('now') ||
           lower.startsWith('in those days') ||
           lower.startsWith('at that time'))) {
        problems.add('tautology_temporal');
      }
      // Check for conjunction after incipit
      final firstAfterWord = lower.split(RegExp(r'[\s,]+')).first;
      if (_conjunctions.contains(firstAfterWord)) {
        problems.add('conjunction_after_incipit:$firstAfterWord');
      }
      if (_pronouns.contains(firstAfterWord)) {
        problems.add('pronoun_after_incipit:$firstAfterWord');
      }
    }
  }

  // ── P4: Wrong incipit for the passage ──────────────────────────────────
  // e.g., "The LORD said to Moses:" for Num 24 (Balaam's oracle)
  if (csvIncipit.isEmpty && derivedIncipit.isNotEmpty && dbFirstVerse.isNotEmpty &&
      !dbFirstVerse.startsWith('[')) {
    final dbLower = dbFirstVerse.toLowerCase();
    // Moses incipit but verse doesn't involve Moses
    if (derivedIncipit.contains('Moses') &&
        !dbLower.contains('moses') &&
        !dbLower.contains('the lord said') &&
        !dbLower.contains('the lord spoke')) {
      problems.add('wrong_speaker_incipit');
    }
  }

  // ── P5: No incipit at all and DB verse is problematic ──────────────────
  if (csvIncipit.isEmpty && derivedIncipit.isEmpty) {
    if (dbFirstVerse.isNotEmpty && !dbFirstVerse.startsWith('[')) {
      final firstWord = dbFirstVerse.toLowerCase().split(RegExp(r'[\s,]+')).first;
      if (_conjunctions.contains(firstWord) || _pronouns.contains(firstWord)) {
        problems.add('no_incipit_problematic_verse:$firstWord');
      }
    }
  }

  return problems;
}

/// Extract the text that comes after the incipit prefix in the rendered line.
String _textAfterIncipit(String rendered, String incipit) {
  final lower = rendered.toLowerCase();
  final incipitLower = incipit.toLowerCase()
      .replaceAll(RegExp(r'[,:;]\s*$'), '').trim();

  if (lower.startsWith(incipitLower)) {
    var after = rendered.substring(incipitLower.length).trim();
    // Strip leading punctuation/whitespace
    after = after.replaceFirst(RegExp(r'^[,:;]\s*'), '').trim();
    // Strip verse number if present
    after = after.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '').trim();
    return after;
  }

  // Try to find the incipit pattern in the rendered text
  final colonIdx = rendered.indexOf(':');
  if (colonIdx > 0 && colonIdx < 40) {
    var after = rendered.substring(colonIdx + 1).trim();
    after = after.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '').trim();
    return after;
  }

  return '';
}

const _conjunctions = {
  'and', 'but', 'or', 'nor', 'for', 'yet', 'so', 'then', 'thus',
  'therefore', 'moreover', 'however', 'nevertheless', 'meanwhile',
  'afterwards', 'afterward', 'also', 'besides', 'furthermore',
  'consequently', 'accordingly', 'hence', 'likewise', 'similarly',
  'nonetheless', 'otherwise', 'still', 'instead', 'rather',
  'since', 'while', 'now', 'again',
};

const _pronouns = {
  'he', 'she', 'it', 'they', 'we', 'his', 'her', 'its', 'their', 'our',
  'him', 'them', 'us', 'himself', 'herself', 'itself', 'themselves',
  'this', 'that', 'these', 'those', 'who', 'whom', 'whose', 'which',
};

String _csvRow(List<String> cols) => cols.map(_csvEscape).join(',');
String _csvEscape(String v) =>
    (v.contains(',') || v.contains('"') || v.contains('\n'))
        ? '"${v.replaceAll('"', '""')}"'
        : v;
