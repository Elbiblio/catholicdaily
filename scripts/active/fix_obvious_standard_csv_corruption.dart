#!/usr/bin/env dart

import 'dart:io';

void main() {
  final standardPath = 'c:/dev/catholicdaily-flutter/standard_lectionary_complete.csv';
  final bakPath = 'c:/dev/catholicdaily-flutter/standard_lectionary_complete.csv.bak_reextract';

  final standardFile = File(standardPath);
  if (!standardFile.existsSync()) {
    stderr.writeln('Missing $standardPath');
    exitCode = 2;
    return;
  }

  final standardLines = standardFile.readAsLinesSync();
  if (standardLines.isEmpty) {
    stderr.writeln('Empty $standardPath');
    exitCode = 2;
    return;
  }

  // Load known-good rows from the backup (used to repair CSV-corrupted rows).
  final bakFile = File(bakPath);
  final bakLines = bakFile.existsSync() ? bakFile.readAsLinesSync() : const <String>[];
  final bakByKey = <String, String>{};
  for (final line in bakLines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final cols = _parseCsvLine(line);
    if (cols.length != 16) continue;
    bakByKey[_rowKey(cols)] = line;
  }

  String? bakRow(String startsWith) {
    for (final line in bakLines.skip(1)) {
      if (line.startsWith(startsWith)) return line;
    }
    return null;
  }

  final header = _parseCsvLine(standardLines.first);
  final expectedCols = header.length;
  if (expectedCols != 16) {
    stderr.writeln('Unexpected header column count: $expectedCols (expected 16).');
    exitCode = 2;
    return;
  }

  var changed = 0;

  // ---- Fix 1: Dec 22 gospel incipit (Luke 1:46-56) missing full speaker lead-in.
  for (var i = 1; i < standardLines.length; i++) {
    final line = standardLines[i];
    if (!line.startsWith('Advent,Dec 17-24,December 22,')) continue;

    final cols = _parseCsvLine(line);
    if (cols.length != expectedCols) {
      stderr.writeln('Dec 22 row is structurally broken (cols=${cols.length}). Not modifying it here.');
      continue;
    }

    // gospel_incipit is last column
    final old = cols[15].trim();
    if (old == 'In those days: Mary said,' || old.isEmpty) {
      cols[15] = 'In those days: After hearing her greeting, Mary said,';
      standardLines[i] = _csvRow(cols);
      changed++;
    }
  }

  // ---- Fix 2: Dec 27/28 rows have corrupted quoting in acclamation_text causing column shift.
  // Replace them with known-good backup rows.
  final bakDec27 = bakRow('Christmas,Octave,December 27,');
  final bakDec28 = bakRow('Christmas,Octave,December 28,');

  for (var i = 1; i < standardLines.length; i++) {
    final line = standardLines[i];

    if (line.startsWith('Christmas,Octave,December 27,')) {
      if (bakDec27 != null) {
        standardLines[i] = bakDec27;
        changed++;
      }
      continue;
    }

    if (line.startsWith('Christmas,Octave,December 28,')) {
      if (bakDec28 != null) {
        standardLines[i] = bakDec28;
        changed++;
      }
      continue;
    }
  }

  // ---- Fix 2b: Restore a small set of still-parseable but clearly corrupted rows.
  const explicitRestorePrefixes = [
    'Christmas,After Epiphany,January 7,I/II,,ALL,1 John 5:5-13,,"Ps 72:1-2, 3-4ab, 7-8",',
    'Christmas,After Epiphany,January 7,I/II,,ALL,1 John 5:5-13,,"Ps 72:1-2, 14-15bc, 17",',
    'Ordinary Time,1,Saturday,I,,,Heb 4:12-16,',
    'Easter,2,Thursday,I/II,,ALL,Acts 5:27-33,',
    'Ordinary Time,17,Wednesday,I,,ALL,Exod 34:29-35,',
    'Ordinary Time,21,Sunday,,B,B,Num 11:25-29,',
    'Ordinary Time,21,Monday,I,,,1 Thess 4:13-18,',
    'Ordinary Time,21,Monday,II,,,"Ezek 1:2-5, 24-28c",',
    'Ordinary Time,29,Friday,I,,ALL,Rom 7:18-25a,',
    'Ordinary Time,29,Friday,II,,ALL,Ephesians 4:1-6,',
    'Ordinary Time,29,Saturday,II,,,Gal 3:22-29,',
    'Ordinary Time,30,Tuesday,I,,ALL,Rom 8:18-25,',
    'Ordinary Time,30,Tuesday,II,,ALL,Ephesians 5:21-33,',
    'Ordinary Time,31,Wednesday,I,,ALL,Rom 13:8-10,',
    'Ordinary Time,31,Wednesday,II,,ALL,Phil 2:12-18,',
    'Ordinary Time,31,Friday,II,,ALL,Phil 3:17-21; 4.1,',
  ];

  for (final prefix in explicitRestorePrefixes) {
    final backup = bakRow(prefix);
    if (backup == null) {
      continue;
    }

    for (var i = 1; i < standardLines.length; i++) {
      if (!standardLines[i].startsWith(prefix)) {
        continue;
      }
      if (standardLines[i] != backup) {
        standardLines[i] = backup;
        changed++;
      }
      break;
    }
  }

  // ---- Fix 3: Any row that is currently structurally malformed should be restored
  // from the matching well-formed backup row for the same identity key.
  for (var i = 1; i < standardLines.length; i++) {
    final line = standardLines[i];
    if (line.trim().isEmpty) continue;

    final cols = _parseCsvLine(line);
    if (cols.length == expectedCols) {
      continue;
    }

    final key = _rowKey(cols);
    final backup = bakByKey[key];
    if (backup == null) {
      stderr.writeln('No backup row found for malformed row ${i + 1}: $key (cols=${cols.length})');
      continue;
    }

    final backupCols = _parseCsvLine(backup);
    if (backupCols.length != expectedCols) {
      stderr.writeln('Backup row for ${i + 1} is not well formed: $key (cols=${backupCols.length})');
      continue;
    }

    if (standardLines[i] != backup) {
      standardLines[i] = backup;
      changed++;
    }
  }

  if (changed == 0) {
    stdout.writeln('No changes needed.');
    return;
  }

  // Write back.
  standardFile.writeAsStringSync(standardLines.join('\n'));
  stdout.writeln('Applied $changed fixes to $standardPath');
}

String _rowKey(List<String> cols) {
  final padded = List<String>.from(cols);
  while (padded.length < 6) {
    padded.add('');
  }
  return padded.take(6).join('|');
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
