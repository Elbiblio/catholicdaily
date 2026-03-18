#!/usr/bin/env dart

import 'dart:io';

void main() {
  final path = 'c:/dev/catholicdaily-flutter/memorial_feasts.csv';
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
  stdout.writeln('Header has $expectedCols columns');

  final outLines = <String>[];
  outLines.add(lines.first); // header unchanged

  var padded = 0;
  var untouched = 0;
  var tooMany = 0;

  for (var i = 1; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) {
      outLines.add(raw);
      continue;
    }

    final cols = _parseCsvLine(raw);

    if (cols.length == expectedCols) {
      outLines.add(raw);
      untouched++;
      continue;
    }

    if (cols.length < expectedCols) {
      final originalLen = cols.length;
      while (cols.length < expectedCols) {
        cols.add('');
      }
      outLines.add(_csvRow(cols));
      padded++;
      stdout.writeln('Padded row ${i + 1}: $originalLen -> ${cols.length}');
      continue;
    }

    // cols.length > expectedCols: keep row as-is but log, do not try to be clever.
    outLines.add(raw);
    tooMany++;
    stdout.writeln('Row ${i + 1} has too many columns (${cols.length} > $expectedCols), left unchanged');
  }

  file.writeAsStringSync(outLines.join('\n'));
  stdout.writeln('Done. Untouched=$untouched, padded=$padded, tooMany=$tooMany');
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
