import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'improved_liturgical_calendar_service.dart';

class DivinumOfficiumEntry {
  final String season;
  final String week;
  final String day;
  final String feast;
  final String rank;
  final String color;
  final String month;
  final String dayOfMonth;
  final String title;
  final String collect;
  final String secret;
  final String communion;
  final String postcommunion;
  final String sourceFile;

  DivinumOfficiumEntry({
    required this.season,
    required this.week,
    required this.day,
    required this.feast,
    required this.rank,
    required this.color,
    required this.month,
    required this.dayOfMonth,
    required this.title,
    required this.collect,
    required this.secret,
    required this.communion,
    required this.postcommunion,
    required this.sourceFile,
  });

  factory DivinumOfficiumEntry.fromCsvRow(List<String> row) {
    return DivinumOfficiumEntry(
      season: row[0],
      week: row[1],
      day: row[2],
      feast: row[3],
      rank: row[4],
      color: row[5],
      month: row[6],
      dayOfMonth: row[7],
      title: row[8],
      collect: row[9],
      secret: row[10],
      communion: row[11],
      postcommunion: row[12],
      sourceFile: row[13],
    );
  }

  bool hasCollect() => collect.isNotEmpty;
  bool hasSecret() => secret.isNotEmpty;
  bool hasCommunion() => communion.isNotEmpty;
  bool hasPostcommunion() => postcommunion.isNotEmpty;
}

class DivinumOfficiumLoaderService {
  static final DivinumOfficiumLoaderService _instance = DivinumOfficiumLoaderService._internal();
  factory DivinumOfficiumLoaderService() => _instance;
  DivinumOfficiumLoaderService._internal();

  final ImprovedLiturgicalCalendarService _calendarService = ImprovedLiturgicalCalendarService.instance;

  List<DivinumOfficiumEntry>? _cachedEntries;

  Future<List<DivinumOfficiumEntry>> loadFromCsv() async {
    if (_cachedEntries != null) {
      return _cachedEntries!;
    }

    try {
      final raw = await rootBundle.loadString('scripts/divinum_officium_propers_english.csv');
      final lines = raw.split('\n');
      
      // Skip header row
      final entries = <DivinumOfficiumEntry>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        // Parse CSV (simple split by comma, handling quoted fields)
        final row = _parseCsvLine(line);
        if (row.length >= 14) {
          entries.add(DivinumOfficiumEntry.fromCsvRow(row));
        }
      }

      _cachedEntries = entries;
      return entries;
    } catch (e) {
      debugPrint('Error loading Divinum Officium CSV: $e');
      return [];
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current += '"';
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }
    
    result.add(current);
    return result;
  }

  Future<String?> getRite(DateTime date, String riteType, String languageCode) async {
    if (languageCode != 'en') return null; // Only English available for now
    
    final entries = await loadFromCsv();
    final liturgicalDay = await _calendarService.getLiturgicalDay(date);
    
    final matchingEntry = _findEntryForLiturgicalDay(entries, liturgicalDay, date);
    
    if (matchingEntry == null) return null;
    
    switch (riteType) {
      case 'collect':
        return matchingEntry.hasCollect() ? matchingEntry.collect : null;
      case 'prayer_over_offerings':
        return matchingEntry.hasSecret() ? matchingEntry.secret : null;
      case 'communion_antiphon':
        return matchingEntry.hasCommunion() ? matchingEntry.communion : null;
      case 'prayer_after_communion':
        return matchingEntry.hasPostcommunion() ? matchingEntry.postcommunion : null;
      default:
        return null;
    }
  }

  DivinumOfficiumEntry? _findEntryForLiturgicalDay(
    List<DivinumOfficiumEntry> entries,
    LiturgicalDay liturgicalDay,
    DateTime date,
  ) {
    for (final entry in entries) {
      // Check if it's a Sancti entry (feast day by month/day)
      if (entry.season == 'Sancti' && entry.month.isNotEmpty && entry.dayOfMonth.isNotEmpty) {
        final entryMonth = int.tryParse(entry.month);
        final entryDay = int.tryParse(entry.dayOfMonth);
        if (entryMonth != null && entryDay != null) {
          if (date.month == entryMonth && date.day == entryDay) {
            return entry;
          }
        }
        continue;
      }

      // For Tempora entries, match by season/week/day
      final season = _parseSeason(entry.season);
      if (season == null) continue;
      
      // Match season
      if (season != liturgicalDay.season) continue;
      
      // Match week number
      if (entry.week.isNotEmpty) {
        final week = int.tryParse(entry.week);
        if (week != null && week != liturgicalDay.weekNumber) continue;
      }
      
      // Match day type (Sunday vs weekday)
      if (entry.day.toLowerCase() == 'sunday' && 
          liturgicalDay.dayOfWeek != DayOfWeek.sunday) continue;
      
      // If all criteria match, return this entry
      return entry;
    }
    
    return null;
  }

  LiturgicalSeason? _parseSeason(String seasonStr) {
    switch (seasonStr.toLowerCase()) {
      case 'advent':
        return LiturgicalSeason.advent;
      case 'epiphany':
        return LiturgicalSeason.christmas; // Epiphany is part of Christmas season
      case 'christmas':
        return LiturgicalSeason.christmas;
      case 'lent':
      case 'lent (pre-lent)':
        return LiturgicalSeason.lent;
      case 'easter':
        return LiturgicalSeason.easter;
      case 'ordinary time':
        return LiturgicalSeason.ordinaryTime;
      case 'sancti':
        return null; // Handle separately by month/day
      default:
        return null;
    }
  }

  Future<void> clearCache() async {
    _cachedEntries = null;
  }
}
