import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'improved_liturgical_calendar_service.dart';
import 'missal_rites_service.dart';

class PrayerOfFaithfulEntry {
  final String season;
  final String week;
  final String day;
  final String occasion1967;
  final String seasonMapped;
  final String weekMapped;
  final String dayMapped;
  final String cycleApplicability;
  final String notes;
  final List<String> petitions;
  final String pageNumber;

  PrayerOfFaithfulEntry({
    required this.season,
    required this.week,
    required this.day,
    required this.occasion1967,
    required this.seasonMapped,
    required this.weekMapped,
    required this.dayMapped,
    required this.cycleApplicability,
    required this.notes,
    required this.petitions,
    required this.pageNumber,
  });

  factory PrayerOfFaithfulEntry.fromCsvRow(List<String> row) {
    final petitions = row[9].split('|').map((p) => p.trim()).toList();
    return PrayerOfFaithfulEntry(
      season: row[0],
      week: row[1],
      day: row[2],
      occasion1967: row[3],
      seasonMapped: row[4],
      weekMapped: row[5],
      dayMapped: row[6],
      cycleApplicability: row[7],
      notes: row[8],
      petitions: petitions,
      pageNumber: row[10],
    );
  }

  bool isObsolete() => seasonMapped == 'Obsolete';
  bool isSpecial() => seasonMapped == 'Special';
  bool isLiturgical() => !isObsolete() && !isSpecial();

  String getFullContent() {
    final response = 'Lord, graciously hear us.';
    final petitionLines = petitions.map((p) => '$response $p').join('\n');
    return petitionLines;
  }
}

class PrayerOfFaithfulLoaderService {
  static final PrayerOfFaithfulLoaderService _instance = PrayerOfFaithfulLoaderService._internal();
  factory PrayerOfFaithfulLoaderService() => _instance;
  PrayerOfFaithfulLoaderService._internal();

  final ImprovedLiturgicalCalendarService _calendarService = ImprovedLiturgicalCalendarService.instance;
  final MissalRitesService _missalRitesService = MissalRitesService.instance;

  List<PrayerOfFaithfulEntry>? _cachedEntries;

  Future<List<PrayerOfFaithfulEntry>> loadFromCsv() async {
    if (_cachedEntries != null) {
      return _cachedEntries!;
    }

    try {
      final raw = await rootBundle.loadString('scripts/prayer_of_faithful_mapped.csv');
      final lines = raw.split('\n');
      
      // Skip header row
      final entries = <PrayerOfFaithfulEntry>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        // Parse CSV (simple split by comma, handling quoted fields)
        final row = _parseCsvLine(line);
        if (row.length >= 11) {
          entries.add(PrayerOfFaithfulEntry.fromCsvRow(row));
        }
      }

      _cachedEntries = entries;
      return entries;
    } catch (e) {
      debugPrint('Error loading prayer of faithful CSV: $e');
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

  Future<void> populateDatabase({
    int year = 2025,
    String languageCode = 'en',
  }) async {
    final entries = await loadFromCsv();
    final liturgicalEntries = entries.where((e) => e.isLiturgical()).toList();

    // Iterate through all dates in the year and match to CSV entries
    for (var month = 1; month <= 12; month++) {
      for (var day = 1; day <= 31; day++) {
        try {
          final date = DateTime(year, month, day);
          final liturgicalDay = await _calendarService.getLiturgicalDay(date);
          
          // Find matching entry for this date
          final matchingEntry = _findEntryForLiturgicalDay(liturgicalEntries, liturgicalDay);
          
          if (matchingEntry != null) {
            final dateStr = date.toIso8601String().split('T').first;
            final content = matchingEntry.getFullContent();
            
            await _missalRitesService.saveRite(
              dateStr,
              languageCode,
              'prayers_of_faithful',
              content,
              'PrayerOfTheFaithful1967',
            );
          }
        } catch (e) {
          // Invalid date, skip
        }
      }
    }
  }

  PrayerOfFaithfulEntry? _findEntryForLiturgicalDay(
    List<PrayerOfFaithfulEntry> entries,
    LiturgicalDay liturgicalDay,
  ) {
    for (final entry in entries) {
      final season = _parseSeason(entry.seasonMapped);
      if (season == null) continue;
      
      // Match season
      if (season != liturgicalDay.season) continue;
      
      // Match week number
      final week = int.tryParse(entry.weekMapped);
      if (week != null && week != liturgicalDay.weekNumber) continue;
      
      // Match day type (Sunday vs weekday)
      if (entry.dayMapped.toLowerCase() == 'sunday' && 
          liturgicalDay.dayOfWeek != DayOfWeek.sunday) continue;
      
      // If it's a special occasion (Christmas, Epiphany, etc.), check the notes
      if (entry.notes.isNotEmpty) {
        final titleLower = liturgicalDay.title.toLowerCase();
        final notesLower = entry.notes.toLowerCase();
        if (titleLower.contains(notesLower) || notesLower.contains(titleLower)) {
          return entry;
        }
      }
      
      // If all criteria match, return this entry
      return entry;
    }
    
    return null;
  }

  LiturgicalSeason? _parseSeason(String seasonStr) {
    switch (seasonStr.toLowerCase()) {
      case 'advent':
        return LiturgicalSeason.advent;
      case 'christmas':
        return LiturgicalSeason.christmas;
      case 'lent':
        return LiturgicalSeason.lent;
      case 'easter':
        return LiturgicalSeason.easter;
      case 'ordinary':
        return LiturgicalSeason.ordinaryTime;
      default:
        return null;
    }
  }

  Future<void> clearCache() async {
    _cachedEntries = null;
  }
}
