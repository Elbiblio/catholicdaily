import 'package:flutter/services.dart';

import '../models/responsorial_psalm_text_entry.dart';
import 'responsorial_psalm_edition_registry.dart';
import 'responsorial_psalm_text_catalog_service.dart';

class ResponsorialPsalmRequest {
  final String selectedEditionId;
  final String reference;
  final String responseText;
  final DateTime date;
  final String territory;
  final String celebrationId;
  final String readingSetKind;
  final String sundayCycle;
  final String weekdayCycle;
  final String lectionaryNumber;

  const ResponsorialPsalmRequest({
    required this.selectedEditionId,
    required this.reference,
    required this.responseText,
    required this.date,
    required this.territory,
    this.celebrationId = '',
    this.readingSetKind = '',
    this.sundayCycle = '',
    this.weekdayCycle = '',
    this.lectionaryNumber = '',
  });
}

class ResponsorialPsalmSourcePackService {
  final ResponsorialPsalmEditionRegistry? registry;
  final AssetBundle _bundle;
  final Map<String, List<ResponsorialPsalmTextEntry>> _entries;

  ResponsorialPsalmSourcePackService({
    required this.registry,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle,
       _entries = <String, List<ResponsorialPsalmTextEntry>>{};

  ResponsorialPsalmSourcePackService.fromEntries(
    Map<String, List<ResponsorialPsalmTextEntry>> entries,
  ) : registry = null,
      _bundle = rootBundle,
      _entries = entries.map(
        (key, value) => MapEntry(key, List.unmodifiable(value)),
      );

  Future<ResponsorialPsalmTextEntry?> lookup({
    required String editionId,
    required ResponsorialPsalmRequest request,
  }) async {
    final entries = await _loadEdition(editionId);
    final normalizedReference = normalizePackReference(request.reference);
    final candidates = entries.where((entry) {
      if (entry.referenceNormalized != normalizedReference) return false;
      final territory = request.territory.toUpperCase();
      return entry.territory.isEmpty ||
          entry.territory == 'WORLD' ||
          entry.territory == territory;
    }).toList();
    if (candidates.isEmpty) return null;

    int score(ResponsorialPsalmTextEntry entry) {
      var value = 0;
      if (entry.territory == request.territory.toUpperCase()) value += 1000;
      if (request.celebrationId.isNotEmpty &&
          entry.celebrationId == request.celebrationId) {
        value += 800;
      }
      if (request.readingSetKind.isNotEmpty &&
          entry.readingSetKind == request.readingSetKind) {
        value += 400;
      }
      if (request.sundayCycle.isNotEmpty &&
          entry.sundayCycle == request.sundayCycle) {
        value += 200;
      }
      if (request.weekdayCycle.isNotEmpty &&
          entry.weekdayCycle == request.weekdayCycle) {
        value += 200;
      }
      return value - entry.displayPriority;
    }

    candidates.sort((left, right) => score(right).compareTo(score(left)));
    return candidates.first;
  }

  Future<List<ResponsorialPsalmTextEntry>> _loadEdition(
    String editionId,
  ) async {
    if (_entries.containsKey(editionId)) return _entries[editionId]!;
    final edition = registry?.byId(editionId);
    if (edition == null || !edition.isInstalled || edition.packAsset.isEmpty) {
      return const <ResponsorialPsalmTextEntry>[];
    }
    final raw = await _bundle.loadString(edition.packAsset);
    final parsed = parsePackCsv(raw);
    _entries[editionId] = parsed;
    return parsed;
  }

  static String normalizePackReference(String value) {
    final normalized = ResponsorialPsalmTextCatalogService.normalizeReference(
      value,
    );
    const corrections = <String, String>{
      'ps23:13a,3b4,5,6': 'ps23:1-3a,3b-4,5,6',
      'ps114:1-2,3-4,5-6,8-9': 'ps116:1-2,3-4,5-6,8-9',
      'ps122:1-2,3-4,7-8,9-10': 'ps122:1-2,3-4,4-5,6-7,8-9',
      'ps138:12a,1-2a,2bc-3,7c-8': 'ps138:1-2a,2bc-3,7c-8',
      'ps27:1,2,3,13-15': 'ps27:1,2,3,13-14',
    };
    return corrections[normalized] ?? normalized;
  }

  static List<ResponsorialPsalmTextEntry> parsePackCsv(String raw) {
    final table = _parseCsv(raw);
    if (table.isEmpty || table.first.length != 17) {
      throw const FormatException('Invalid responsorial psalm pack header');
    }
    return <ResponsorialPsalmTextEntry>[
      for (var index = 1; index < table.length; index++)
        if (table[index].any((value) => value.isNotEmpty))
          _entryFromColumns(table[index], index + 1),
    ];
  }

  static ResponsorialPsalmTextEntry _entryFromColumns(
    List<String> columns,
    int rowNumber,
  ) {
    if (columns.length != 17) {
      throw FormatException('Invalid psalm pack row $rowNumber');
    }
    return ResponsorialPsalmTextEntry(
      usageId: columns[1],
      territory: columns[2].toUpperCase(),
      celebrationId: columns[3],
      dateRule: columns[4],
      sundayCycle: columns[6],
      weekdayCycle: columns[7],
      lectionaryNumber: columns[8],
      readingSetKind: columns[5],
      referenceNormalized: normalizePackReference(columns[9]),
      responseText: columns[10],
      stanzas: columns[11]
          .split(RegExp(r'\r?\n\r?\n'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      sourceId: columns[0],
      sourceEdition: columns[13],
      sourceUrl: columns[12],
      displayPriority: int.parse(columns[16]),
    );
  }

  static List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < raw.length; index++) {
      final character = raw[index];
      if (quoted) {
        if (character == '"') {
          if (index + 1 < raw.length && raw[index + 1] == '"') {
            field.write('"');
            index++;
          } else {
            quoted = false;
          }
        } else {
          field.write(character);
        }
      } else if (character == '"') {
        quoted = true;
      } else if (character == ',') {
        row.add(field.toString());
        field = StringBuffer();
      } else if (character == '\n') {
        row.add(field.toString().replaceFirst(RegExp(r'\r$'), ''));
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
      } else {
        field.write(character);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
