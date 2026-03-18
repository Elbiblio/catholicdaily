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
  final acclamationRefIndex = header.indexOf('acclamation_ref');
  final acclamationTextIndex = header.indexOf('acclamation_text');

  if (acclamationRefIndex == -1 || acclamationTextIndex == -1) {
    stderr.writeln('Header does not contain expected acclamation_ref/acclamation_text columns.');
    exitCode = 2;
    return;
  }

  // First pass: build best (longest) acclamation text per reference.
  final Map<String, String> bestByRef = {};

  for (var i = 1; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) continue;

    final cols = _parseCsvLine(raw);
    if (acclamationRefIndex >= cols.length || acclamationTextIndex >= cols.length) {
      continue; // structurally bad row; leave to other tools
    }

    final ref = cols[acclamationRefIndex].trim();
    var text = cols[acclamationTextIndex].trim();
    if (ref.isEmpty || text.isEmpty) continue;

    final currentBest = bestByRef[ref];
    if (currentBest == null || text.length > currentBest.length) {
      bestByRef[ref] = text;
    }
  }

  var changed = 0;
  final outLines = <String>[];
  outLines.add(lines.first); // header

  // Second pass: upgrade truncated acclamation texts to the best known for the same ref.
  for (var i = 1; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) {
      outLines.add(raw);
      continue;
    }

    final cols = _parseCsvLine(raw);
    if (acclamationRefIndex >= cols.length || acclamationTextIndex >= cols.length) {
      outLines.add(raw);
      continue; // do not attempt to repair structurally damaged rows here
    }

    final ref = cols[acclamationRefIndex].trim();
    final current = cols[acclamationTextIndex].trim();

    if (ref.isEmpty || current.isEmpty) {
      outLines.add(raw);
      continue;
    }

    final best = bestByRef[ref];
    if (best != null && best.length > current.length) {
      cols[acclamationTextIndex] = best;
      changed++;
      outLines.add(_csvRow(cols));
    } else {
      outLines.add(raw);
    }
  }

  if (changed == 0) {
    stdout.writeln('No acclamation_text upgrades applied.');
    return;
  }

  file.writeAsStringSync(outLines.join('\n'));
  stdout.writeln('Applied $changed acclamation_text upgrades based on longest text per acclamation_ref.');
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
