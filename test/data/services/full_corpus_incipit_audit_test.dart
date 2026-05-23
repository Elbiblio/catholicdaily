import 'dart:io';

import 'package:catholic_daily/data/services/incipit_preference_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

class _ReadingCase {
  final String source;
  final String reference;
  final String readingType;
  final String? incipit;

  const _ReadingCase({
    required this.source,
    required this.reference,
    required this.readingType,
    this.incipit,
  });

  String get key => '$reference|$readingType|${incipit ?? ''}';
}

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test(
    'Full local lectionary corpus has safe incipit openings',
    timeout: const Timeout(Duration(minutes: 10)),
    () async {
      final pref = IncipitPreferenceService();
      await pref.setShowIncipit(true);
      await pref.setLocale('en');
      pref.resetCache();

      final cases = <String, _ReadingCase>{};
      for (final c in await _standardCases()) {
        cases[c.key] = c;
      }
      for (final c in await _memorialCases()) {
        cases[c.key] = c;
      }
      for (final c in await _specialPeriodCases()) {
        cases[c.key] = c;
      }

      final service = ReadingsService.instance;
      final issues = <String>[];
      var rendered = 0;
      var unavailable = 0;

      for (final c in cases.values) {
        final text = await service.getReadingText(
          c.reference,
          incipit: c.incipit,
          readingType: c.readingType,
        );
        if (text.startsWith('Reading text unavailable')) {
          unavailable++;
          continue;
        }
        rendered++;
        issues.addAll(_auditRenderedCase(c, text));
      }

      // ignore: avoid_print
      print('\nFull incipit corpus audit');
      // ignore: avoid_print
      print('  Unique cases: ${cases.length}');
      // ignore: avoid_print
      print('  Rendered:     $rendered');
      // ignore: avoid_print
      print('  Unavailable:  $unavailable');
      // ignore: avoid_print
      print('  Issues:       ${issues.length}');
      for (final issue in issues.take(30)) {
        // ignore: avoid_print
        print(issue);
      }

      expect(cases.length, greaterThan(900));
      expect(rendered, greaterThan(850));
      expect(
        issues,
        isEmpty,
        reason: 'Unsafe liturgical incipit output found in full corpus scan.',
      );
    },
  );
}

List<String> _auditRenderedCase(_ReadingCase c, String text) {
  final head = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (head.isEmpty) return const [];

  final normalizedHead = _normalize(head);
  final issues = <String>[];
  void flag(String code) {
    issues.add(
      '[$code] ${c.source} ${c.readingType} ${c.reference}\n'
      '  incipit: ${c.incipit ?? ''}\n'
      '  output:  ${head.length > 180 ? '${head.substring(0, 180)}...' : head}',
    );
  }

  final isGospel = c.readingType == 'gospel';
  if (!isGospel && normalizedHead.startsWith('at that time')) {
    flag('gospel_formula_on_non_gospel');
  }
  if (isGospel &&
      (normalizedHead.startsWith('brethren') ||
          normalizedHead.startsWith('brothers and sisters') ||
          normalizedHead.startsWith('beloved'))) {
    flag('letter_formula_on_gospel');
  }
  if (RegExp(
    r'^(?:at that time|in those days|on that day)\s*(?::|,)?\s*(?:he|she|they|it|him|her|them)\b',
  ).hasMatch(normalizedHead)) {
    flag('unresolved_pronoun_after_formula');
  }
  if (RegExp(
    r'^(?:at that time|in those days|beloved|brethren|brothers and sisters|thus says the lord)\s*[:;,]?\s*\d+[a-z]?\b',
  ).hasMatch(normalizedHead)) {
    flag('verse_number_leakage_after_formula');
  }
  if (_containsBoilerplate(normalizedHead)) {
    flag('boilerplate_contamination');
  }
  if (_hasDoubledFormula(normalizedHead)) {
    flag('doubled_formula');
  }
  if (_hasDoubledSpeaker(normalizedHead)) {
    flag('doubled_speaker');
  }
  if (normalizedHead.contains('nicodemus') &&
      !_normalize(c.reference).startsWith('john')) {
    flag('unrelated_book_wording');
  }
  if (_normalize(c.reference).startsWith('acts 9') &&
      normalizedHead.startsWith('jesus')) {
    flag('wrong_speaker_acts9');
  }

  return issues;
}

Future<List<_ReadingCase>> _standardCases() async {
  final rows = await _readCsv('standard_lectionary_complete.csv');
  return [
    for (final row in rows)
      ...[
        _case(
          row,
          source: 'standard',
          refField: 'first_reading',
          incipitField: 'first_reading_incipit',
          readingType: 'first_reading',
        ),
        _case(
          row,
          source: 'standard',
          refField: 'second_reading',
          incipitField: 'second_reading_incipit',
          readingType: 'second_reading',
        ),
        _case(
          row,
          source: 'standard',
          refField: 'gospel',
          incipitField: 'gospel_incipit',
          readingType: 'gospel',
        ),
      ].whereType<_ReadingCase>(),
  ];
}

Future<List<_ReadingCase>> _memorialCases() async {
  final rows = await _readCsv('memorial_feasts.csv');
  return [
    for (final row in rows)
      ...[
        _case(
          row,
          source: 'memorial',
          refField: 'firstReading',
          incipitField: 'firstReadingIncipit',
          readingType: 'first_reading',
        ),
        _case(
          row,
          source: 'memorial',
          refField: 'alternativeFirstReading',
          incipitField: 'alternativeFirstReadingIncipit',
          readingType: 'first_reading',
        ),
        _case(
          row,
          source: 'memorial',
          refField: 'secondReading',
          incipitField: 'secondReadingIncipit',
          readingType: 'second_reading',
        ),
        _case(
          row,
          source: 'memorial',
          refField: 'gospel',
          incipitField: 'gospelIncipit',
          readingType: 'gospel',
        ),
        _case(
          row,
          source: 'memorial',
          refField: 'alternativeGospel',
          incipitField: 'alternativeGospelIncipit',
          readingType: 'gospel',
        ),
      ].whereType<_ReadingCase>(),
  ];
}

Future<List<_ReadingCase>> _specialPeriodCases() async {
  final rows = await _readCsv('special_period_readings.csv');
  return [
    for (final row in rows)
      ...[
        _case(
          row,
          source: 'special',
          refField: 'firstReading',
          incipitField: 'firstReadingIncipit',
          readingType: 'first_reading',
        ),
        _case(
          row,
          source: 'special',
          refField: 'alternativeFirstReading',
          incipitField: 'alternativeFirstReadingIncipit',
          readingType: 'first_reading',
        ),
        _case(
          row,
          source: 'special',
          refField: 'secondReading',
          incipitField: 'secondReadingIncipit',
          readingType: 'second_reading',
        ),
        _case(
          row,
          source: 'special',
          refField: 'gospel',
          incipitField: 'gospelIncipit',
          readingType: 'gospel',
        ),
        _case(
          row,
          source: 'special',
          refField: 'alternativeGospel',
          incipitField: 'alternativeGospelIncipit',
          readingType: 'gospel',
        ),
      ].whereType<_ReadingCase>(),
  ];
}

_ReadingCase? _case(
  Map<String, String> row, {
  required String source,
  required String refField,
  required String incipitField,
  required String readingType,
}) {
  final rawRef = (row[refField] ?? '').trim();
  if (rawRef.isEmpty || _isPsalm(rawRef)) return null;
  final reference = _normalizeReference(rawRef);
  if (reference.isEmpty) return null;
  final incipit = (row[incipitField] ?? '').trim();
  return _ReadingCase(
    source: source,
    reference: reference,
    readingType: readingType,
    incipit: incipit.isEmpty ? null : incipit,
  );
}

Future<List<Map<String, String>>> _readCsv(String path) async {
  final raw = await File(path).readAsString();
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];
  final header = _parseCsvLine(lines.first);
  return [for (final line in lines.skip(1)) _rowFromCsvLine(header, line)];
}

Map<String, String> _rowFromCsvLine(List<String> header, String line) {
  final cols = _parseCsvLine(line);
  return {
    for (var i = 0; i < header.length; i++)
      header[i]: i < cols.length ? cols[i] : '',
  };
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

String _normalizeReference(String value) {
  var ref = value.trim();
  ref = ref.replaceFirst(
    RegExp(r'^\s*(?:see|cf\.?|confer)\s+', caseSensitive: false),
    '',
  );
  ref = ref.replaceAllMapped(
    RegExp(r'(\d)\.(\d)'),
    (m) => '${m.group(1)}:${m.group(2)}',
  );
  return ref.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isPsalm(String value) {
  final normalized = value.toLowerCase().trim();
  return normalized.startsWith('ps ') || normalized.startsWith('psalm ');
}

bool _containsBoilerplate(String normalized) {
  const rejected = [
    'a reading from',
    'thanks be to god',
    'the gospel of the lord',
    'praise to you lord jesus christ',
    'gospel acclamation',
    'responsorial psalm',
  ];
  return rejected.any(normalized.contains);
}

bool _hasDoubledFormula(String normalized) {
  const formulas = [
    'at that time',
    'in those days',
    'on that day',
    'thus says the lord',
    'brethren',
    'brothers and sisters',
  ];
  for (final formula in formulas) {
    if (!normalized.startsWith(formula)) continue;
    final count = RegExp(
      '\\b${RegExp.escape(formula)}\\b',
    ).allMatches(normalized).length;
    if (count > 1) return true;
  }
  return false;
}

bool _hasDoubledSpeaker(String normalized) {
  return RegExp(
    r'^(?:at that time\s*)?(?:jesus|peter|paul|moses)\s+(?:said|spoke|told)[^a-z0-9]+(?:jesus|peter|paul|moses)\s+(?:said|spoke|told)\b',
  ).hasMatch(normalized);
}
