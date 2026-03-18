#!/usr/bin/env dart

import 'dart:io';

void main() {
  final path = 'c:/dev/catholicdaily-flutter/standard_lectionary_complete.csv';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exitCode = 2;
    return;
  }

  final lines = file.readAsLinesSync();
  if (lines.isEmpty) {
    stderr.writeln('Empty file: $path');
    exitCode = 2;
    return;
  }

  final header = _parseCsvLine(lines.first);
  final expectedCols = header.length;
  final acclamationRefIndex = header.indexOf('acclamation_ref');
  final acclamationTextIndex = header.indexOf('acclamation_text');

  if (expectedCols != 16 || acclamationRefIndex == -1 || acclamationTextIndex == -1) {
    stderr.writeln('Unexpected header for standard_lectionary_complete.csv');
    stderr.writeln('columns=${header.length}, acclamation_ref=$acclamationRefIndex, acclamation_text=$acclamationTextIndex');
    exitCode = 2;
    return;
  }

  var shrunk = 0;
  final outLines = <String>[];
  outLines.add(lines.first);

  for (var i = 1; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) {
      outLines.add(raw);
      continue;
    }

    final cols = _parseCsvLine(raw);
    if (cols.length <= expectedCols) {
      outLines.add(raw);
      continue;
    }

    // Only try to repair rows that look like overwide because of acclamation_text duplication/junk.
    if (acclamationRefIndex >= cols.length || acclamationTextIndex >= cols.length) {
      outLines.add(raw);
      continue;
    }

    final ref = cols[acclamationRefIndex].trim();
    final acclam = cols[acclamationTextIndex].trim();
    if (ref.isEmpty || acclam.isEmpty) {
      outLines.add(raw);
      continue;
    }

    // Build a clean row: keep first 13 columns (through acclamation_text), then reconstruct trailing fields conservatively.
    final newCols = <String>[];
    for (var c = 0; c <= acclamationTextIndex; c++) {
      newCols.add(c < cols.length ? cols[c] : '');
    }

    // Heuristic: try to preserve a numeric lectionary_number if it exists anywhere in the tail.
    String lectionary = '';
    for (var t = acclamationTextIndex + 1; t < cols.length; t++) {
      final v = cols[t].trim();
      if (RegExp(r'^\d{1,4}\$').hasMatch(v)) {
        lectionary = v;
        break;
      }
    }

    // Append lectionary_number and leave incipits empty (safer than misaligned text).
    newCols.add(lectionary); // index 13
    newCols.add(''); // first_reading_incipit (14)
    newCols.add(''); // gospel_incipit (15)

    if (newCols.length != expectedCols) {
      // Sanity check; do not write a malformed row.
      outLines.add(raw);
      continue;
    }

    outLines.add(_csvRow(newCols));
    shrunk++;
  }

  if (shrunk == 0) {
    stdout.writeln('No overwide rows were modified.');
    return;
  }

  file.writeAsStringSync(outLines.join('\n'));
  stdout.writeln('Shrunk $shrunk overwide rows to $expectedCols columns in $path');
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
