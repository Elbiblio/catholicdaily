#!/usr/bin/env dart

import 'dart:io';

class _Suspect {
  final String sourceFile;
  final int rowIndex; // 1-indexed line number in file
  final String dayLabel;
  final String type;
  final String reference;
  final String field;
  final String value;
  final String issue;
  final String suggestedFix;
  final String notes;

  _Suspect({
    required this.sourceFile,
    required this.rowIndex,
    required this.dayLabel,
    required this.type,
    required this.reference,
    required this.field,
    required this.value,
    required this.issue,
    required this.suggestedFix,
    required this.notes,
  });
}

void main() {
  final outFile = File('c:/dev/catholicdaily-flutter/scripts/active/grammar_suspects.csv');

  final suspects = <_Suspect>[];

  _scanStandardLectionary(suspects);
  _scanMemorialFeasts(suspects);
  _scanCandidateFile(suspects);

  suspects.sort((a, b) {
    final k1 = '${a.sourceFile}|${a.dayLabel}|${a.type}|${a.reference}|${a.field}|${a.issue}|${a.rowIndex}';
    final k2 = '${b.sourceFile}|${b.dayLabel}|${b.type}|${b.reference}|${b.field}|${b.issue}|${b.rowIndex}';
    return k1.compareTo(k2);
  });

  final rows = <List<String>>[
    [
      'source_file',
      'row_index',
      'day_label',
      'type',
      'reference',
      'field',
      'value',
      'issue',
      'suggested_fix',
      'notes',
    ],
    ...suspects.map((s) => [
          s.sourceFile,
          s.rowIndex.toString(),
          s.dayLabel,
          s.type,
          s.reference,
          s.field,
          s.value,
          s.issue,
          s.suggestedFix,
          s.notes,
        ]),
  ];

  outFile.writeAsStringSync(rows.map(_csvRow).join('\n'));

  stdout.writeln('Wrote ${suspects.length} suspects to ${outFile.path}');
}

void _scanStandardLectionary(List<_Suspect> out) {
  final file = File('c:/dev/catholicdaily-flutter/standard_lectionary_complete.csv');
  if (!file.existsSync()) return;

  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return;

  final header = _parseCsvLine(lines.first);
  final expectedCols = header.length;

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;

    final cols = _parseCsvLine(line);
    if (cols.length != expectedCols) {
      out.add(_Suspect(
        sourceFile: 'standard_lectionary_complete.csv',
        rowIndex: i + 1,
        dayLabel: _safeDayLabelFromBrokenRow(cols),
        type: '',
        reference: '',
        field: '(row)',
        value: _truncate(line, 380),
        issue: 'csv_column_count_mismatch:${cols.length}!=${expectedCols}',
        suggestedFix: '',
        notes: 'Row does not parse to expected column count; likely unquoted commas or broken quoting.',
      ));
      continue;
    }

    final season = cols[0];
    final week = cols[1];
    final day = cols[2];
    final weekdayCycle = cols[3];
    final dayLabel = _formatDayLabel(season, week, day, weekdayCycle);

    final firstReadingRef = cols[6];
    final gospelRef = cols[10];

    final firstReadingIncipit = cols[14];
    final gospelIncipit = cols[15];

    final acclamationText = cols[12];

    _flagText(
      out,
      sourceFile: 'standard_lectionary_complete.csv',
      rowIndex: i + 1,
      dayLabel: dayLabel,
      type: 'acclamation',
      reference: gospelRef,
      field: 'acclamation_text',
      value: acclamationText,
    );

    _flagIncipit(
      out,
      sourceFile: 'standard_lectionary_complete.csv',
      rowIndex: i + 1,
      dayLabel: dayLabel,
      type: 'first_reading',
      reference: firstReadingRef,
      field: 'first_reading_incipit',
      incipit: firstReadingIncipit,
    );

    _flagIncipit(
      out,
      sourceFile: 'standard_lectionary_complete.csv',
      rowIndex: i + 1,
      dayLabel: dayLabel,
      type: 'gospel',
      reference: gospelRef,
      field: 'gospel_incipit',
      incipit: gospelIncipit,
    );
  }
}

void _scanMemorialFeasts(List<_Suspect> out) {
  final file = File('c:/dev/catholicdaily-flutter/memorial_feasts.csv');
  if (!file.existsSync()) return;

  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return;

  final header = _parseCsvLine(lines.first);
  final expectedCols = header.length;

  int idx(String name) => header.indexOf(name);
  final iTitle = idx('title');
  final iRank = idx('rank');
  final iFirstReading = idx('firstReading');
  final iFirstReadingIncipit = idx('firstReadingIncipit');
  final iGospel = idx('gospel');
  final iGospelIncipit = idx('gospelIncipit');

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;

    final cols = _parseCsvLine(line);
    // Rows in memorial_feasts.csv are allowed to be "short" (omit trailing optional
    // columns). Only flag rows that have MORE columns than the header, which
    // usually indicates an unquoted comma or broken quoting.
    if (cols.length > expectedCols) {
      out.add(_Suspect(
        sourceFile: 'memorial_feasts.csv',
        rowIndex: i + 1,
        dayLabel: (iTitle >= 0 && iTitle < cols.length) ? cols[iTitle] : '',
        type: '',
        reference: '',
        field: '(row)',
        value: _truncate(line, 380),
        issue: 'csv_column_count_mismatch:${cols.length}!=${expectedCols}',
        suggestedFix: '',
        notes: 'Row has more columns than header; likely unquoted comma or broken quoting.',
      ));
      continue;
    }

    final dayLabel = iTitle >= 0 ? cols[iTitle] : '';
    final rank = iRank >= 0 ? cols[iRank] : '';

    if (iFirstReadingIncipit >= 0 && iFirstReading >= 0) {
      _flagIncipit(
        out,
        sourceFile: 'memorial_feasts.csv',
        rowIndex: i + 1,
        dayLabel: dayLabel,
        type: 'first_reading',
        reference: cols[iFirstReading],
        field: 'firstReadingIncipit',
        incipit: cols[iFirstReadingIncipit],
        extraNotes: rank.isEmpty ? '' : 'rank=$rank',
      );
    }

    if (iGospelIncipit >= 0 && iGospel >= 0) {
      _flagIncipit(
        out,
        sourceFile: 'memorial_feasts.csv',
        rowIndex: i + 1,
        dayLabel: dayLabel,
        type: 'gospel',
        reference: cols[iGospel],
        field: 'gospelIncipit',
        incipit: cols[iGospelIncipit],
        extraNotes: rank.isEmpty ? '' : 'rank=$rank',
      );
    }
  }
}

void _scanCandidateFile(List<_Suspect> out) {
  final file = File('c:/dev/catholicdaily-flutter/scripts/active/lectionary_first_line_candidates.csv');
  if (!file.existsSync()) return;

  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return;

  final header = _parseCsvLine(lines.first);
  final expectedCols = header.length;

  int idx(String name) => header.indexOf(name);
  final iDayLabel = idx('day_label');
  final iType = idx('type');
  final iReference = idx('reference');
  final iCandidate = idx('candidate_first_line');

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;

    final cols = _parseCsvLine(line);
    if (cols.length != expectedCols) {
      out.add(_Suspect(
        sourceFile: 'lectionary_first_line_candidates.csv',
        rowIndex: i + 1,
        dayLabel: '',
        type: '',
        reference: '',
        field: '(row)',
        value: _truncate(line, 380),
        issue: 'csv_column_count_mismatch:${cols.length}!=${expectedCols}',
        suggestedFix: '',
        notes: 'Candidate row does not parse to expected column count.',
      ));
      continue;
    }

    final dayLabel = iDayLabel >= 0 ? cols[iDayLabel] : '';
    final type = iType >= 0 ? cols[iType] : '';
    final ref = iReference >= 0 ? cols[iReference] : '';
    final candidate = iCandidate >= 0 ? cols[iCandidate] : '';

    if (candidate.trim().isEmpty) continue;

    final issues = _grammarSmells(candidate);
    for (final issue in issues) {
      out.add(_Suspect(
        sourceFile: 'lectionary_first_line_candidates.csv',
        rowIndex: i + 1,
        dayLabel: dayLabel,
        type: type,
        reference: ref,
        field: 'candidate_first_line',
        value: candidate,
        issue: issue,
        suggestedFix: '',
        notes: 'Auto-flagged from curated extraction candidates.',
      ));
    }
  }
}

void _flagIncipit(
  List<_Suspect> out, {
  required String sourceFile,
  required int rowIndex,
  required String dayLabel,
  required String type,
  required String reference,
  required String field,
  required String incipit,
  String extraNotes = '',
}) {
  if (incipit.trim().isEmpty) return;

  final issues = <String>[..._grammarSmells(incipit)];

  // Highly targeted “missing speaker” checks.
  final normRef = reference.trim().toLowerCase();
  final lowerIncipit = incipit.toLowerCase();

  // Magnificat: lectionary has explicit speaker lead-in.
  if (normRef.startsWith('luke 1:46') || normRef.startsWith('luke 1:46-')) {
    if (lowerIncipit.contains('my soul magnifies') && !lowerIncipit.contains('mary')) {
      issues.add('missing_speaker_context:magnificat');
    }
    if (lowerIncipit.trim() == 'in those days: mary said,') {
      issues.add('speaker_context_too_short:magnificat');
    }
  }

  for (final issue in issues) {
    out.add(_Suspect(
      sourceFile: sourceFile,
      rowIndex: rowIndex,
      dayLabel: dayLabel,
      type: type,
      reference: reference,
      field: field,
      value: incipit,
      issue: issue,
      suggestedFix: _suggestFix(reference: reference, incipit: incipit, issue: issue),
      notes: extraNotes,
    ));
  }
}

void _flagText(
  List<_Suspect> out, {
  required String sourceFile,
  required int rowIndex,
  required String dayLabel,
  required String type,
  required String reference,
  required String field,
  required String value,
}) {
  if (value.trim().isEmpty) return;

  final issues = <String>[];
  if (_looksCorrupted(value)) {
    issues.add('text_corruption');
  }
  if (_looksTruncated(value)) {
    issues.add('text_truncated');
  }

  for (final issue in issues) {
    out.add(_Suspect(
      sourceFile: sourceFile,
      rowIndex: rowIndex,
      dayLabel: dayLabel,
      type: type,
      reference: reference,
      field: field,
      value: value,
      issue: issue,
      suggestedFix: '',
      notes: '',
    ));
  }
}

List<String> _grammarSmells(String text) {
  final t = text.trim();
  final lower = t.toLowerCase();

  final issues = <String>[];

  if (_looksCorrupted(t)) {
    issues.add('text_corruption');
  }

  if (_looksTruncated(t)) {
    issues.add('text_truncated');
  }

  // Boilerplate that should never become an incipit.
  const boilerNeedles = [
    'r. alleluia',
    'the word of the lord',
    'the gospel of the lord',
    'a reading from',
    'a period of silence',
  ];
  if (boilerNeedles.any(lower.contains)) {
    issues.add('boilerplate');
  }

  // Starts with conjunction/pronoun without context.
  if (RegExp(r'^(and|but|then|so|for|now|therefore|moreover)\b', caseSensitive: false)
      .hasMatch(t)) {
    issues.add('starts_with_conjunction');
  }

  if (RegExp(r'^(he|she|they|it|this|that|these|those|we|i|my|our|who|whom|whose)\b', caseSensitive: false)
      .hasMatch(t)) {
    issues.add('starts_with_pronoun_or_relative');
  }

  // OCR artifacts / odd punctuation.
  if (t.contains('@@') || t.contains('�') || t.contains('â')) {
    issues.add('encoding_or_ocr_artifacts');
  }

  return issues.toSet().toList()..sort();
}

String _suggestFix({
  required String reference,
  required String incipit,
  required String issue,
}) {
  final normRef = reference.trim().toLowerCase();

  if (issue == 'speaker_context_too_short:magnificat' ||
      issue == 'missing_speaker_context:magnificat') {
    // Grounded in weekday_a_full.txt lines 2394-2396.
    return 'In those days: After hearing her greeting, Mary said,';
  }

  if (normRef.startsWith('2 sam 7:4-5a') && incipit.trim().isEmpty) {
    return 'The word of the Lord came to Nathan:';
  }

  return '';
}

bool _looksCorrupted(String text) {
  // Common corruption patterns seen in this repo.
  if (text.contains('" We praise yo"')) return true;
  if (text.contains(' We praise yo')) return true;
  if (text.contains('â')) return true;
  if (text.contains('�')) return true;
  return false;
}

bool _looksTruncated(String text) {
  final t = text.trim();
  return t.endsWith('yo') || t.endsWith(' We praise yo') || t == 'We praise yo';
}

String _truncate(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

String _formatDayLabel(String season, String week, String day, String weekdayCycle) {
  final base = '$season/$week/$day';
  final cycle = weekdayCycle.trim().isEmpty ? '' : '/$weekdayCycle';
  return '$base$cycle';
}

String _safeDayLabelFromBrokenRow(List<String> cols) {
  if (cols.length >= 3) {
    return '${cols[0]}/${cols[1]}/${cols[2]}';
  }
  return '';
}

List<String> _parseCsvLine(String line) {
  final values = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char == ',' && !inQuotes) {
      values.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  values.add(buffer.toString());
  return values;
}

String _csvRow(List<String> cols) => cols.map(_csvEscape).join(',');

String _csvEscape(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}
