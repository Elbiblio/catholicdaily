import 'package:flutter/services.dart' show rootBundle;

import 'base_service.dart';

class StandardLectionaryEntry {
  final String season;
  final String week;
  final String day;
  final String weekdayCycle;
  final String sundayCycle;
  final String readingCycle;
  final String firstReading;
  final String secondReading;
  final String psalmReference;
  final String psalmResponse;
  final String gospel;
  final String acclamationRef;
  final String acclamationText;
  final String lectionaryNumber;
  final String gospelIncipit;

  const StandardLectionaryEntry({
    required this.season,
    required this.week,
    required this.day,
    required this.weekdayCycle,
    required this.sundayCycle,
    required this.readingCycle,
    required this.firstReading,
    required this.secondReading,
    required this.psalmReference,
    required this.psalmResponse,
    required this.gospel,
    required this.acclamationRef,
    required this.acclamationText,
    required this.lectionaryNumber,
    required this.gospelIncipit,
  });
}

class MemorialFeastEntry {
  final String id;
  final String title;
  final String rank;
  final String color;
  final String month;
  final String day;
  final String dateRule;
  final String commonType;
  final String firstReading;
  final String alternativeFirstReading;
  final String psalmReference;
  final String psalmResponse;
  final String secondReading;
  final String gospel;
  final String alternativeGospel;
  final String gospelAcclamation;

  const MemorialFeastEntry({
    required this.id,
    required this.title,
    required this.rank,
    required this.color,
    required this.month,
    required this.day,
    required this.dateRule,
    required this.commonType,
    required this.firstReading,
    required this.alternativeFirstReading,
    required this.psalmReference,
    required this.psalmResponse,
    required this.secondReading,
    required this.gospel,
    required this.alternativeGospel,
    required this.gospelAcclamation,
  });
}

class ReadingCatalogService extends BaseService<ReadingCatalogService> {
  static ReadingCatalogService get instance =>
      BaseService.init(() => ReadingCatalogService._());

  ReadingCatalogService._();

  List<StandardLectionaryEntry>? _standardEntries;
  List<MemorialFeastEntry>? _memorialEntries;
  Map<String, List<MemorialFeastEntry>>? _memorialEntriesByMonthDay;

  Future<List<StandardLectionaryEntry>> loadStandardEntries() async {
    if (_standardEntries != null) {
      return _standardEntries!;
    }

    final rawCsv = await rootBundle.loadString('standard_lectionary_complete.csv');
    final lines = rawCsv
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final parsed = <StandardLectionaryEntry>[];
    for (var i = 1; i < lines.length; i++) {
      final columns = parseCsvLine(lines[i]);
      if (columns.length < 14) {
        continue;
      }
      parsed.add(
        StandardLectionaryEntry(
          season: columns[0].trim(),
          week: columns[1].trim(),
          day: columns[2].trim(),
          weekdayCycle: columns[3].trim(),
          sundayCycle: columns[4].trim(),
          readingCycle: columns[5].trim(),
          firstReading: columns[6].trim(),
          secondReading: columns[7].trim(),
          psalmReference: columns[8].trim(),
          psalmResponse: columns[9].trim(),
          gospel: columns[10].trim(),
          acclamationRef: columns[11].trim(),
          acclamationText: columns[12].trim(),
          lectionaryNumber: columns[13].trim(),
          gospelIncipit: columns.length > 14 ? columns[14].trim() : '',
        ),
      );
    }

    _standardEntries = parsed;
    return parsed;
  }

  Future<List<MemorialFeastEntry>> loadMemorialEntries() async {
    if (_memorialEntries != null) {
      return _memorialEntries!;
    }

    final rawCsv = await rootBundle.loadString('memorial_feasts.csv');
    final lines = rawCsv
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final parsed = <MemorialFeastEntry>[];
    for (var i = 1; i < lines.length; i++) {
      final columns = parseCsvLine(lines[i]);
      if (columns.length < 16) {
        continue;
      }
      parsed.add(
        MemorialFeastEntry(
          id: columns[0].trim(),
          title: columns[1].trim(),
          rank: columns[2].trim(),
          color: columns[3].trim(),
          month: columns[4].trim(),
          day: columns[5].trim(),
          dateRule: columns[6].trim(),
          commonType: columns[7].trim(),
          firstReading: columns[8].trim(),
          alternativeFirstReading: columns[9].trim(),
          psalmReference: columns[10].trim(),
          psalmResponse: columns[11].trim(),
          secondReading: columns[12].trim(),
          gospel: columns[13].trim(),
          alternativeGospel: columns[14].trim(),
          gospelAcclamation: columns[15].trim(),
        ),
      );
    }

    _memorialEntries = parsed;
    _memorialEntriesByMonthDay = <String, List<MemorialFeastEntry>>{};
    for (final entry in parsed) {
      if (entry.month.isEmpty || entry.day.isEmpty) {
        continue;
      }
      final key = '${entry.month}-${entry.day}';
      _memorialEntriesByMonthDay!
          .putIfAbsent(key, () => <MemorialFeastEntry>[])
          .add(entry);
    }

    return parsed;
  }

  Future<List<MemorialFeastEntry>> getMemorialEntriesForMonthDay(
    int month,
    int day,
  ) async {
    await loadMemorialEntries();
    return _memorialEntriesByMonthDay?['$month-$day'] ?? const [];
  }

  List<String> parseCsvLine(String line) {
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
}
