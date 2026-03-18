import 'dart:io';

void main() {
  final repoRoot = _repoRoot();

  final renderedProblemsFile = _pickFirstExisting([
    File('${repoRoot}\\scripts\\rendered_problems.csv'),
    File('${repoRoot}\\scripts\\active\\rendered_problems.csv'),
  ]);

  if (renderedProblemsFile == null) {
    stderr.writeln('Could not find rendered_problems.csv in scripts/ or scripts/active/.');
    exitCode = 2;
    return;
  }

  final indexFile = File('${repoRoot}\\scripts\\archive\\incipit_project\\lectionary_first_lines.csv');
  if (!indexFile.existsSync()) {
    stderr.writeln('Missing index file: ${indexFile.path}');
    exitCode = 2;
    return;
  }

  final weekdayA = File('${repoRoot}\\scripts\\weekday_a_full.txt');
  final weekdayB = File('${repoRoot}\\scripts\\weekday_b_full.txt');
  final sunday = File('${repoRoot}\\scripts\\sunday_readings_full.txt');

  final weekdayAText = weekdayA.existsSync() ? weekdayA.readAsLinesSync() : const <String>[];
  final weekdayBText = weekdayB.existsSync() ? weekdayB.readAsLinesSync() : const <String>[];
  final sundayText = sunday.existsSync() ? sunday.readAsLinesSync() : const <String>[];

  final index = _loadLectionaryIndex(indexFile);
  final problems = _loadRenderedProblems(renderedProblemsFile);

  // Focus only on the "real" remaining categories where a manual override is useful.
  const wantedPrefixes = [
    'raw_verse_conjunction',
    'raw_verse_pronoun',
    'raw_verse_lowercase',
    'no_incipit_problematic_verse',
    'pronoun_after_incipit',
    'conjunction_after_incipit',
  ];

  final outRows = <List<String>>[
    [
      'source',
      'day_label',
      'type',
      'reference',
      'problems',
      'db_first_verse',
      'csv_incipit',
      'index_source_file',
      'index_raw_header_ref',
      'candidate_first_line',
      'candidate_source',
      'quality_notes',
    ]
  ];

  for (final p in problems) {
    final problemsStr = p.problems;
    if (!_anyWanted(problemsStr, wantedPrefixes)) continue;

    final norm = _normalizeRef(p.reference);
    final idx = index['$norm|${p.type}'];

    String candidate = '';
    String candidateSource = '';
    String qualityNotes = '';

    if (idx != null) {
      final extracted = _extractFirstVerseLine(
        sourceFile: idx.sourceFile,
        rawHeaderRef: idx.rawHeaderRef,
        readingType: idx.readingType,
        weekdayAText: weekdayAText,
        weekdayBText: weekdayBText,
        sundayText: sundayText,
      );

      if (extracted.line.isNotEmpty) {
        candidate = extracted.line;
        candidateSource = extracted.source;
        qualityNotes = extracted.notes;
      } else {
        qualityNotes = extracted.notes.isNotEmpty
            ? extracted.notes
            : 'index match but failed to extract verse line from source txt';
      }

      // If the extracted candidate still looks bad, drop it.
      final bad = _qualityRejectReason(candidate);
      if (bad != null) {
        qualityNotes = qualityNotes.isEmpty ? 'reject:$bad' : '$qualityNotes; reject:$bad';
        candidate = '';
        candidateSource = '';
      }
    } else {
      qualityNotes = 'no index match';
    }

    outRows.add([
      p.source,
      p.dayLabel,
      p.type,
      p.reference,
      p.problems,
      p.dbFirstVerse,
      p.csvIncipit,
      idx?.sourceFile ?? '',
      idx?.rawHeaderRef ?? '',
      candidate,
      candidateSource,
      qualityNotes,
    ]);
  }

  final outFile = File('${repoRoot}\\scripts\\active\\lectionary_first_line_candidates.csv');
  outFile.writeAsStringSync(outRows.map(_csvRow).join('\n'));

  print('Rendered problems: ${renderedProblemsFile.path}');
  print('Index rows loaded: ${index.length}');
  print('Wrote: ${outFile.path}');
  print('Candidate rows: ${outRows.length - 1}');
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _ProblemRow {
  final String source;
  final String dayLabel;
  final String type;
  final String reference;
  final String csvIncipit;
  final String dbFirstVerse;
  final String problems;

  const _ProblemRow({
    required this.source,
    required this.dayLabel,
    required this.type,
    required this.reference,
    required this.csvIncipit,
    required this.dbFirstVerse,
    required this.problems,
  });
}

class _IndexRow {
  final String normalizedRef;
  final String sourceFile;
  final String readingType;
  final String rawHeaderRef;

  const _IndexRow({
    required this.normalizedRef,
    required this.sourceFile,
    required this.readingType,
    required this.rawHeaderRef,
  });
}

class _ExtractionResult {
  final String line;
  final String source;
  final String notes;

  const _ExtractionResult({
    required this.line,
    required this.source,
    required this.notes,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Loaders
// ─────────────────────────────────────────────────────────────────────────────

List<_ProblemRow> _loadRenderedProblems(File f) {
  final lines = f.readAsLinesSync();
  if (lines.isEmpty) return const [];

  final rows = <_ProblemRow>[];
  for (var i = 1; i < lines.length; i++) {
    final c = _parseCsvLine(lines[i]);
    if (c.length < 10) continue;
    rows.add(_ProblemRow(
      source: c[0].trim(),
      dayLabel: c[1].trim(),
      type: c[3].trim(),
      reference: c[4].trim(),
      csvIncipit: c[5].trim(),
      dbFirstVerse: c[7].trim(),
      problems: c[9].trim(),
    ));
  }
  return rows;
}

Map<String, _IndexRow> _loadLectionaryIndex(File f) {
  final lines = f.readAsLinesSync();
  final map = <String, _IndexRow>{};
  for (var i = 1; i < lines.length; i++) {
    final c = _parseCsvLine(lines[i]);
    if (c.length < 6) continue;
    final norm = c[0].trim();
    final sourceFile = c[1].trim();
    final readingType = c[2].trim();
    final rawHeaderRef = c[5].trim();

    if (norm.isEmpty || sourceFile.isEmpty || readingType.isEmpty || rawHeaderRef.isEmpty) {
      continue;
    }

    final key = '${norm}|${readingType}';
    map.putIfAbsent(
      key,
      () => _IndexRow(
        normalizedRef: norm,
        sourceFile: sourceFile,
        readingType: readingType,
        rawHeaderRef: rawHeaderRef,
      ),
    );
  }
  return map;
}

// ─────────────────────────────────────────────────────────────────────────────
// Extraction
// ─────────────────────────────────────────────────────────────────────────────

_ExtractionResult _extractFirstVerseLine({
  required String sourceFile,
  required String rawHeaderRef,
  required String readingType,
  required List<String> weekdayAText,
  required List<String> weekdayBText,
  required List<String> sundayText,
}) {
  final lines = switch (sourceFile) {
    'weekday_a' => weekdayAText,
    'weekday_b' => weekdayBText,
    'sunday' => sundayText,
    _ => const <String>[],
  };

  if (lines.isEmpty) {
    return _ExtractionResult(
      line: '',
      source: '',
      notes: 'missing source txt for $sourceFile',
    );
  }

  final headerNeedles = <String>[];
  if (readingType == 'gospel') {
    headerNeedles.addAll([
      'GOSPEL $rawHeaderRef',
      'GO S P E L $rawHeaderRef',
    ]);
  } else {
    headerNeedles.add('FIRST READING $rawHeaderRef');
  }

  String normalizeHeaderLine(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
  String escapeForRegex(String input) => input.replaceAllMapped(
        RegExp(r'[\\.^$|?*+()\[\]{}]'),
        (m) => '\\${m.group(0)}',
      );

  var headerIdx = -1;
  for (var i = 0; i < lines.length; i++) {
    final normalized = normalizeHeaderLine(lines[i]);
    if (headerNeedles.any((needle) => normalized == needle)) {
      headerIdx = i;
      break;
    }
  }

  if (headerIdx < 0) {
    // Fallback: substring match (sometimes extra spaces or ++)
    for (var i = 0; i < lines.length; i++) {
      final t = normalizeHeaderLine(lines[i]);
      final isPrefixMatch = readingType == 'gospel'
          ? (t.startsWith('GOSPEL ') || t.startsWith('GO S P E L '))
          : t.startsWith('FIRST READING ');
      if (isPrefixMatch && t.contains(rawHeaderRef)) {
        headerIdx = i;
        break;
      }
    }
  }

  if (headerIdx < 0) {
    // More permissive fallback: allow variable spacing in "GO S P E L".
    if (readingType == 'gospel') {
      final refRx = escapeForRegex(rawHeaderRef);
      final rx = RegExp(r'^G\s*O\s*S\s*P\s*E\s*L\s+' + refRx + r'$');
      for (var i = 0; i < lines.length; i++) {
        if (rx.hasMatch(lines[i].trim())) {
          headerIdx = i;
          break;
        }
      }
    }
  }

  if (headerIdx < 0) {
    return _ExtractionResult(
      line: '',
      source: '',
      notes: 'header not found in $sourceFile: ${headerNeedles.join(" | ")}',
    );
  }

  // Find the preamble line "A reading from ..." then extract the first
  // proclaimed line(s) that follow. In the weekday txts, this often appears
  // BEFORE the numbered verse lines and may span multiple lines.
  var preambleIdx = -1;
  for (var i = headerIdx + 1; i < lines.length && i < headerIdx + 120; i++) {
    final t = lines[i].trim();
    if (t.toLowerCase().startsWith('a reading from')) {
      preambleIdx = i;
      break;
    }
    if (t.toLowerCase().startsWith('responsorial psalm')) {
      break;
    }
  }

  if (preambleIdx < 0) {
    return _ExtractionResult(
      line: '',
      source: '',
      notes: 'found header but no preamble (A reading from...) found within scan window',
    );
  }

  final parts = <String>[];
  for (var i = preambleIdx + 1; i < lines.length && i < preambleIdx + 40; i++) {
    final t = lines[i].trim();
    if (t.isEmpty) continue;

    final lower = t.toLowerCase();
    if (t == '@') continue;
    if (lower.startsWith('responsorial psalm')) break;
    if (lower.startsWith('the word of the lord')) break;
    if (lower.startsWith('the gospel of the lord')) break;
    if (lower.startsWith('a period of silence')) break;

    // If this is a verse-numbered line, take the verse text as the first
    // line (only if we haven't already captured unnumbered lines).
    final m = RegExp(r'^(\d+)[a-z]?\s+(.*)$').firstMatch(t);
    if (m != null) {
      if (parts.isEmpty) {
        final after = (m.group(2) ?? '').trim();
        parts.add(after);
      }
      break;
    }

    // Otherwise, this is part of the incipit text (unnumbered).
    parts.add(t);

    // Heuristic stop: if we have a full sentence, stop early.
    if (t.endsWith('.') || t.endsWith(':') || t.endsWith('!') || t.endsWith('?')) {
      break;
    }

    // Or if we already have a couple of lines and it's getting long.
    final combinedLen = parts.fold<int>(0, (sum, s) => sum + s.length + 1);
    if (parts.length >= 3 || combinedLen > 220) {
      break;
    }
  }

  final combined = _cleanExtractedLine(parts.join(' '));
  if (combined.isEmpty) {
    return _ExtractionResult(
      line: '',
      source: '',
      notes: 'preamble found but no usable incipit/verse line extracted',
    );
  }

  return _ExtractionResult(
    line: combined,
    source: sourceFile,
    notes: 'from $sourceFile',
  );
}

String _cleanExtractedLine(String s) {
  var r = s.trim();
  // Normalize curly quotes and stray OCR bytes.
  r = r.replaceAll('â', "'");
  r = r.replaceAll('â', '—');
  r = r.replaceAll('\uFFFD', '');
  r = r.replaceAll(RegExp(r'\s{2,}'), ' ');
  return r;
}

String? _qualityRejectReason(String line) {
  final t = line.trim();
  if (t.isEmpty) return 'empty';
  if (t.contains('â') || t.contains('\uFFFD')) return 'encoding_artifact';
  final lower = t.toLowerCase();
  if (lower.startsWith('a reading from')) return 'boilerplate_reading_from';
  if (lower.contains('the gospel of the lord')) return 'boilerplate_gospel_of_the_lord';
  if (lower.trim() == 'the word of the lord.' || lower.trim() == 'the word of the lord') {
    return 'boilerplate_word_of_the_lord';
  }
  if (lower.startsWith('[ shorter form') || lower.startsWith('[')) return 'bracket_note';
  if (t.startsWith('+')) return 'leading_plus';
  if (t.length < 6) return 'too_short';
  if (t.length > 240) return 'too_long';
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

bool _anyWanted(String problems, List<String> wantedPrefixes) {
  final parts = problems.split(';').map((p) => p.trim());
  for (final p in parts) {
    for (final w in wantedPrefixes) {
      if (p == w || p.startsWith('$w:')) return true;
    }
  }
  return false;
}

String _normalizeRef(String ref) {
  // Mirrors the ad-hoc normalization used by earlier scripts:
  // - lower
  // - trim
  // - drop trailing punctuation
  // - convert "Book 7.4" -> "Book 7:4" when dot separates chapter/verse
  var r = ref.trim().replaceAll(RegExp(r'[.;,]+$'), '').replaceAll('++', '');
  r = r.replaceAllMapped(
    RegExp(r'^([A-Za-z0-9 ]+\s\d+)\.(\d)'),
    (m) => '${m.group(1)}:${m.group(2)}',
  );
  return r.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

List<String> _parseCsvLine(String line) {
  final out = <String>[];
  final b = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        b.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (ch == ',' && !inQuotes) {
      out.add(b.toString());
      b.clear();
      continue;
    }
    b.write(ch);
  }
  out.add(b.toString());
  return out;
}

String _csvRow(List<String> cols) {
  return cols.map((c) {
    final needsQuotes = c.contains(',') || c.contains('"') || c.contains('\n');
    final escaped = c.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }).join(',');
}

String _repoRoot() {
  // This script is intended to be executed from repo root.
  return Directory.current.path;
}

File? _pickFirstExisting(List<File> files) {
  for (final f in files) {
    if (f.existsSync()) return f;
  }
  return null;
}
