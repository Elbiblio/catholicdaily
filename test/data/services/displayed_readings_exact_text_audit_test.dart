import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

const _runExactTextAudit = bool.fromEnvironment('RUN_EXACT_TEXT_AUDIT');
const _fixturePath =
    'verification/exact-reading-fixtures/local_extract_exact_text_samples.json';
const _reportPath =
    'verification/comprehensive-readings-audit/exact-text-local-extract-report.json';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test(
    'displayed readings match local extract text exactly',
    skip: _runExactTextAudit
        ? null
        : 'Set RUN_EXACT_TEXT_AUDIT=true to run exact source-text comparison.',
    timeout: const Timeout(Duration(minutes: 4)),
    () async {
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      try {
        final fixtureFile = File(_fixturePath);
        expect(fixtureFile.existsSync(), isTrue, reason: _fixturePath);

        final rawFixtures = jsonDecode(await fixtureFile.readAsString());
        final fixtures = (rawFixtures as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(_ExactTextFixture.fromJson)
            .toList();

        final failures = <_ExactTextMismatch>[];
        final hydratedByKey = <String, Map<String, String>>{};

        for (final fixture in fixtures) {
          var hydratedTexts = hydratedByKey[fixture.sampleKey];
          if (hydratedTexts == null) {
            hydratedTexts = await _hydrateTextsFor(fixture);
            hydratedByKey[fixture.sampleKey] = hydratedTexts;
          }

          final appText = hydratedTexts[fixture.reference];
          final sourceText = _extractSourceText(fixture);
          if (appText == null) {
            failures.add(
              _ExactTextMismatch(
                fixture: fixture,
                reason: 'reference-not-rendered',
                classification: 'reference',
                appSnippet: '',
                sourceSnippet: _snippet(sourceText),
              ),
            );
            continue;
          }

          final normalizedApp = _canonicalWordSequence(appText);
          final normalizedSource = _canonicalWordSequence(sourceText);
          if (normalizedApp != normalizedSource) {
            failures.add(
              _ExactTextMismatch(
                fixture: fixture,
                reason: 'text-mismatch',
                classification: _classifyMismatch(fixture),
                appSnippet: _mismatchSnippet(normalizedApp, normalizedSource),
                sourceSnippet: _mismatchSnippet(
                  normalizedSource,
                  normalizedApp,
                ),
              ),
            );
          }
        }

        await _writeReport(fixtures, failures);

        expect(
          failures,
          isEmpty,
          reason:
              'Exact text mismatches found. Report written to $_reportPath.',
        );
      } finally {
        debugPrint = previousDebugPrint;
      }
    },
  );
}

Future<Map<String, String>> _hydrateTextsFor(_ExactTextFixture fixture) async {
  final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
  await regionPrefs.setRegion(LiturgicalRegion.fromCode(fixture.regionCode));

  final versionPrefs = await BibleVersionPreference.getInstance();
  await versionPrefs.setVersion(
    BibleVersionType.fromDbName(fixture.bibleVersionId),
  );
  await ReadingsService.instance.reloadForVersionChange();

  final readings = await CsvReadingsResolverService.instance.resolve(
    fixture.date,
  );
  final hydrated = await ReadingFlowService.instance.hydrateReadingSet(
    date: fixture.date,
    readings: readings,
  );
  return hydrated.readingTexts;
}

String _extractSourceText(_ExactTextFixture fixture) {
  final file = File(fixture.sourcePath);
  if (!file.existsSync()) {
    throw StateError('Source file not found: ${fixture.sourcePath}');
  }
  final lines = file.readAsLinesSync();
  final start = lines.indexWhere((line) => line.contains(fixture.startMarker));
  if (start < 0) {
    throw StateError('${fixture.id}: start marker not found');
  }
  final contentStart = lines.indexWhere(
    (line) => line.contains(fixture.contentStartMarker),
    start,
  );
  if (contentStart < 0) {
    throw StateError('${fixture.id}: content start marker not found');
  }
  final end = lines.indexWhere(
    (line) => line.contains(fixture.endMarker),
    contentStart,
  );
  if (end < 0) {
    throw StateError('${fixture.id}: end marker not found');
  }

  return lines
      .sublist(contentStart, end)
      .where((line) => !_isPaginationLine(line))
      .join('\n');
}

bool _isPaginationLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return true;
  if (RegExp(r'^=+$').hasMatch(trimmed)) return true;
  if (RegExp(r'^PAGE\s+\d+$', caseSensitive: false).hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(
    r'^\d+\s+[A-Z][A-Z\s]+(?:[-–]\s+YEAR\s+[IVX]+)?$',
  ).hasMatch(trimmed)) {
    return true;
  }
  if (RegExp(r'^[A-Z]+\s+\d+$').hasMatch(trimmed)) return true;
  return trimmed == '@' || trimmed == 'ª' || trimmed == 'Âª';
}

String _canonicalText(String value) {
  var text = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = _repairCommonMojibake(text);
  text = text.replaceAll('\u00a0', ' ');
  text = text.replaceAll(RegExp(r'[“”]'), '"');
  text = text.replaceAll(RegExp(r'[‘’]'), "'");
  text = text.replaceAll(RegExp(r'[—–]'), '-');
  text = text.replaceAllMapped(
    RegExp(r'^\s*(\d+)[.)]?\s+', multiLine: true),
    (match) => '${match.group(1)} ',
  );
  text = text.replaceAll(RegExp(r'\s+'), ' ');
  return text.trim();
}

String _canonicalWordSequence(String value) {
  final text = _canonicalText(value).toLowerCase();
  return RegExp(
    r"[a-z0-9]+(?:'[a-z0-9]+)?",
  ).allMatches(text).map((match) => match.group(0)!).join(' ');
}

String _repairCommonMojibake(String value) {
  return value
      .replaceAll('â€™', "'")
      .replaceAll('â€˜', "'")
      .replaceAll('â€œ', '"')
      .replaceAll('â€', '"')
      .replaceAll('â€�', '"')
      .replaceAll('â€”', '-')
      .replaceAll('â€“', '-')
      .replaceAll('Âª', '')
      .replaceAll('Â', '');
}

String _mismatchSnippet(String left, String right) {
  final max = left.length < right.length ? left.length : right.length;
  var index = 0;
  while (index < max && left.codeUnitAt(index) == right.codeUnitAt(index)) {
    index++;
  }
  final start = (index - 80).clamp(0, left.length);
  final end = (index + 160).clamp(0, left.length);
  return left.substring(start, end);
}

String _classifyMismatch(_ExactTextFixture fixture) {
  if (fixture.bibleVersionId == 'rsvce' &&
      fixture.sourceLabel.toLowerCase().contains('local')) {
    return 'text-version';
  }
  return 'text';
}

String _snippet(String text) {
  final normalized = _canonicalText(text);
  return normalized.length <= 240 ? normalized : normalized.substring(0, 240);
}

Future<void> _writeReport(
  List<_ExactTextFixture> fixtures,
  List<_ExactTextMismatch> failures,
) async {
  final reportFile = File(_reportPath);
  reportFile.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await reportFile.writeAsString(
    encoder.convert({
      'generatedAt': DateTime.now().toIso8601String(),
      'fixturePath': _fixturePath,
      'fixtureCount': fixtures.length,
      'failureCount': failures.length,
      'failures': failures.map((failure) => failure.toJson()).toList(),
    }),
  );
}

class _ExactTextFixture {
  final String id;
  final DateTime date;
  final String regionCode;
  final String bibleVersionId;
  final String reference;
  final String position;
  final String sourceLabel;
  final String sourcePath;
  final String startMarker;
  final String contentStartMarker;
  final String endMarker;

  const _ExactTextFixture({
    required this.id,
    required this.date,
    required this.regionCode,
    required this.bibleVersionId,
    required this.reference,
    required this.position,
    required this.sourceLabel,
    required this.sourcePath,
    required this.startMarker,
    required this.contentStartMarker,
    required this.endMarker,
  });

  factory _ExactTextFixture.fromJson(Map<String, dynamic> json) {
    return _ExactTextFixture(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      regionCode: json['region'] as String,
      bibleVersionId: json['bibleVersion'] as String,
      reference: json['reference'] as String,
      position: json['position'] as String,
      sourceLabel: json['sourceLabel'] as String,
      sourcePath: json['sourcePath'] as String,
      startMarker: json['startMarker'] as String,
      contentStartMarker: json['contentStartMarker'] as String,
      endMarker: json['endMarker'] as String,
    );
  }

  String get sampleKey =>
      '${date.toIso8601String().split('T').first}|$regionCode|$bibleVersionId';
}

class _ExactTextMismatch {
  final _ExactTextFixture fixture;
  final String reason;
  final String classification;
  final String appSnippet;
  final String sourceSnippet;

  const _ExactTextMismatch({
    required this.fixture,
    required this.reason,
    required this.classification,
    required this.appSnippet,
    required this.sourceSnippet,
  });

  Map<String, dynamic> toJson() => {
    'id': fixture.id,
    'date': fixture.date.toIso8601String().split('T').first,
    'region': fixture.regionCode,
    'bibleVersion': fixture.bibleVersionId,
    'reference': fixture.reference,
    'position': fixture.position,
    'sourceLabel': fixture.sourceLabel,
    'sourcePath': fixture.sourcePath,
    'reason': reason,
    'classification': classification,
    'appSnippet': appSnippet,
    'sourceSnippet': sourceSnippet,
  };
}
