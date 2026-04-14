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
  final String firstReadingIncipit;
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
    required this.firstReadingIncipit,
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
  final String firstReadingIncipit;
  final String alternativeFirstReadingIncipit;
  final String psalmReference;
  final String psalmResponse;
  final String secondReading;
  final String secondReadingIncipit;
  final String gospel;
  final String gospelIncipit;
  final String alternativeGospel;
  final String alternativeGospelIncipit;
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
    required this.firstReadingIncipit,
    required this.alternativeFirstReadingIncipit,
    required this.psalmReference,
    required this.psalmResponse,
    required this.secondReading,
    required this.secondReadingIncipit,
    required this.gospel,
    required this.gospelIncipit,
    required this.alternativeGospel,
    required this.alternativeGospelIncipit,
    required this.gospelAcclamation,
  });
}

class SpecialPeriodEntry {
  final String id;
  final String season;
  final String day;
  final String dayNum;
  final String week;
  final String firstReading;
  final String alternativeFirstReading;
  final String firstReadingIncipit;
  final String alternativeFirstReadingIncipit;
  final String psalmReference;
  final String psalmResponse;
  final String secondReading;
  final String secondReadingIncipit;
  final String gospel;
  final String gospelIncipit;
  final String alternativeGospel;
  final String alternativeGospelIncipit;
  final String sourceFile;

  const SpecialPeriodEntry({
    required this.id,
    required this.season,
    required this.day,
    required this.dayNum,
    required this.week,
    required this.firstReading,
    required this.alternativeFirstReading,
    required this.firstReadingIncipit,
    required this.alternativeFirstReadingIncipit,
    required this.psalmReference,
    required this.psalmResponse,
    required this.secondReading,
    required this.secondReadingIncipit,
    required this.gospel,
    required this.gospelIncipit,
    required this.alternativeGospel,
    required this.alternativeGospelIncipit,
    required this.sourceFile,
  });
}

class ReadingCatalogService extends BaseService<ReadingCatalogService> {
  static ReadingCatalogService get instance =>
      BaseService.init(() => ReadingCatalogService._());

  ReadingCatalogService._();

  List<StandardLectionaryEntry>? _standardEntries;
  List<MemorialFeastEntry>? _memorialEntries;
  Map<String, List<MemorialFeastEntry>>? _memorialEntriesByMonthDay;
  List<SpecialPeriodEntry>? _specialEntries;
  Map<String, List<SpecialPeriodEntry>>? _specialEntriesBySeasonDayNum;

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
          firstReadingIncipit: columns.length > 14 ? columns[14].trim() : '',
          gospelIncipit: columns.length > 15 ? columns[15].trim() : '',
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
      if (columns.length < 22) {
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
          firstReadingIncipit: columns[10].trim(),
          alternativeFirstReadingIncipit: columns[11].trim(),
          psalmReference: columns[12].trim(),
          psalmResponse: columns[13].trim(),
          secondReading: columns[14].trim(),
          secondReadingIncipit: columns[15].trim(),
          gospel: columns[16].trim(),
          gospelIncipit: columns[17].trim(),
          alternativeGospel: columns[18].trim(),
          alternativeGospelIncipit: columns[19].trim(),
          gospelAcclamation: columns[20].trim(),
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

  Future<List<SpecialPeriodEntry>> loadSpecialPeriodEntries() async {
    if (_specialEntries != null) {
      return _specialEntries!;
    }

    final rawCsv = await rootBundle.loadString('special_period_readings.csv');
    final lines = rawCsv
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final parsed = <SpecialPeriodEntry>[];
    for (var i = 1; i < lines.length; i++) {
      final columns = parseCsvLine(lines[i]);
      if (columns.length < 16) {
        continue;
      }
      parsed.add(
        SpecialPeriodEntry(
          id: columns[0].trim(),
          season: columns[1].trim(),
          day: columns[2].trim(),
          dayNum: columns[3].trim(),
          week: columns[4].trim(),
          firstReading: columns[5].trim(),
          alternativeFirstReading: columns[6].trim(),
          firstReadingIncipit: columns[7].trim(),
          alternativeFirstReadingIncipit: columns[8].trim(),
          psalmReference: columns[9].trim(),
          psalmResponse: columns[10].trim(),
          secondReading: columns[11].trim(),
          secondReadingIncipit: columns[12].trim(),
          gospel: columns[13].trim(),
          gospelIncipit: columns[14].trim(),
          alternativeGospel: columns[15].trim(),
          alternativeGospelIncipit: columns[16].trim(),
          sourceFile: columns[17].trim(),
        ),
      );
    }

    _specialEntries = parsed;
    _specialEntriesBySeasonDayNum = <String, List<SpecialPeriodEntry>>{};
    for (final entry in parsed) {
      if (entry.season.isEmpty || entry.day.isEmpty || entry.dayNum.isEmpty) {
        continue;
      }
      final key = '${entry.season.toLowerCase()}-${entry.day.toLowerCase()}-${entry.dayNum}';
      _specialEntriesBySeasonDayNum!
          .putIfAbsent(key, () => <SpecialPeriodEntry>[])
          .add(entry);
    }

    return parsed;
  }

  Future<List<SpecialPeriodEntry>> getSpecialPeriodEntriesForSeasonDayNum(
    String season,
    String day,
    String dayNum,
  ) async {
    await loadSpecialPeriodEntries();
    return _specialEntriesBySeasonDayNum?['${season.toLowerCase()}-${day.toLowerCase()}-$dayNum'] ?? const [];
  }

  Future<List<SpecialPeriodEntry>> getSpecialPeriodEntriesForSeasonDay(
    String season,
    String day,
  ) async {
    await loadSpecialPeriodEntries();
    return _specialEntries?.where((entry) =>
      entry.season.toLowerCase() == season.toLowerCase() &&
      entry.day.toLowerCase() == day.toLowerCase()
    ).toList() ?? const [];
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
