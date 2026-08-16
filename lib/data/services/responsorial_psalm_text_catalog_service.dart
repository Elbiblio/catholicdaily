import 'package:flutter/services.dart' show rootBundle;

import '../models/responsorial_psalm_text_entry.dart';
import 'base_service.dart';
import 'reading_catalog_service.dart';

class ResponsorialPsalmTextCatalogService
    extends BaseService<ResponsorialPsalmTextCatalogService> {
  static ResponsorialPsalmTextCatalogService get instance =>
      BaseService.init(() => ResponsorialPsalmTextCatalogService._());

  ResponsorialPsalmTextCatalogService._();

  List<ResponsorialPsalmTextEntry>? _entries;

  Future<ResponsorialPsalmTextEntry?> lookup({
    required DateTime date,
    required String territory,
    required String reference,
    String response = '',
    String celebrationId = '',
    String readingSetKind = '',
    String lectionaryNumber = '',
  }) async {
    final entries = await _load();
    return lookupFromEntries(
      entries,
      date: date,
      territory: territory,
      reference: reference,
      response: response,
      celebrationId: celebrationId,
      readingSetKind: readingSetKind,
      lectionaryNumber: lectionaryNumber,
    );
  }

  Future<List<ResponsorialPsalmTextEntry>> _load() async {
    if (_entries != null) return _entries!;
    final raw = await rootBundle.loadString(
      'assets/data/responsorial_psalm_texts.csv',
    );
    _entries = List.unmodifiable(parseCsv(raw));
    return _entries!;
  }

  static List<ResponsorialPsalmTextEntry> parseCsv(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw const FormatException('Responsorial psalm catalog is empty');
    }
    final parser = ReadingCatalogService.instance;
    final header = parser.parseCsvLine(lines.first);
    if (header.length != 15 || header.first != 'usage_id') {
      throw const FormatException('Invalid responsorial psalm catalog header');
    }
    final entries = <ResponsorialPsalmTextEntry>[];
    for (var index = 1; index < lines.length; index++) {
      final columns = parser.parseCsvLine(lines[index]);
      if (columns.length != 15) {
        throw FormatException(
          'Invalid responsorial psalm row ${index + 1}: '
          '${columns.length} columns',
        );
      }
      final stanzaText = columns[10].replaceAll(r'\n', '\n');
      entries.add(
        ResponsorialPsalmTextEntry(
          usageId: columns[0].trim(),
          territory: columns[1].trim().toUpperCase(),
          celebrationId: columns[2].trim(),
          dateRule: columns[3].trim(),
          sundayCycle: columns[4].trim(),
          weekdayCycle: columns[5].trim(),
          lectionaryNumber: columns[6].trim(),
          readingSetKind: columns[7].trim(),
          referenceNormalized: normalizeReference(columns[8]),
          responseText: columns[9].trim(),
          stanzas: stanzaText
              .split('\n\n')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
          sourceId: columns[11].trim(),
          sourceEdition: columns[12].trim(),
          sourceUrl: columns[13].trim(),
          displayPriority: int.parse(columns[14].trim()),
        ),
      );
    }
    return entries;
  }

  static ResponsorialPsalmTextEntry? lookupFromEntries(
    List<ResponsorialPsalmTextEntry> entries, {
    required DateTime date,
    required String territory,
    required String reference,
    String response = '',
    String celebrationId = '',
    String readingSetKind = '',
    String lectionaryNumber = '',
  }) {
    final region = territory.trim().toUpperCase();
    final normalizedReference = normalizeReference(reference);
    final normalizedResponse = normalizeWords(response);
    final candidates = entries.where((entry) {
      if (entry.referenceNormalized != normalizedReference) return false;
      if (entry.territory.isNotEmpty &&
          entry.territory != 'WORLD' &&
          entry.territory != region) {
        return false;
      }
      return _matchesDateRule(entry.dateRule, date);
    }).toList();

    int score(ResponsorialPsalmTextEntry entry) {
      var value = 0;
      if (entry.territory == region) value += 1000;
      if (celebrationId.isNotEmpty && entry.celebrationId == celebrationId) {
        value += 800;
      }
      if (readingSetKind.isNotEmpty && entry.readingSetKind == readingSetKind) {
        value += 400;
      }
      if (lectionaryNumber.isNotEmpty &&
          entry.lectionaryNumber == lectionaryNumber) {
        value += 200;
      }
      if (normalizedResponse.isNotEmpty &&
          normalizeWords(entry.responseText) == normalizedResponse) {
        value += 100;
      }
      return value - entry.displayPriority;
    }

    candidates.sort((left, right) {
      final byScore = score(right).compareTo(score(left));
      if (byScore != 0) return byScore;
      return left.usageId.compareTo(right.usageId);
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  static String normalizeReference(String value) => value
      .toLowerCase()
      .replaceFirst(RegExp(r'^(?:psalm|ps)\s*'), 'ps')
      .replaceAll(' and ', ',')
      .replaceAll(RegExp(r'\(r\.[^)]*\)', caseSensitive: false), '')
      .replaceAllMapped(RegExp(r'(?<=[0-9a-z])[.;](?=\d)'), (_) => ',')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r',+'), ',')
      .replaceAll(RegExp(r',$'), '')
      .trim();

  static String normalizeWords(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  static bool _matchesDateRule(String rule, DateTime date) {
    if (rule.isEmpty || rule == '*') return true;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(rule)) {
      return rule == '$month-$day';
    }
    return rule == '${date.year}-$month-$day';
  }
}
