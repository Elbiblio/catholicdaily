import 'package:flutter/services.dart';
import 'ordo_resolver_service.dart';

/// Service for loading and serving Prayer of the Faithful (Universal Prayer) content
class PrayerOfTheFaithfulService {
  static final PrayerOfTheFaithfulService instance = PrayerOfTheFaithfulService._internal();
  factory PrayerOfTheFaithfulService() => instance;
  PrayerOfTheFaithfulService._internal();

  List<Map<String, dynamic>>? _cached1967Prayers;
  List<Map<String, dynamic>>? _cachedSpanishPrayers;
  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;

  /// Load 1967 English prayers from CSV
  Future<List<Map<String, dynamic>>> _load1967Prayers() async {
    if (_cached1967Prayers != null) return _cached1967Prayers!;

    try {
      final csvContent = await rootBundle.loadString('assets/data/prayer_of_faithful_mapped.csv');
      final lines = csvContent.split('\n');
      final headers = lines[0].split(',');

      _cached1967Prayers = [];
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        
        final values = _parseCSVLine(lines[i]);
        if (values.length == headers.length) {
          final prayer = <String, dynamic>{};
          for (var j = 0; j < headers.length; j++) {
            prayer[headers[j].trim()] = values[j].trim();
          }
          _cached1967Prayers!.add(prayer);
        }
      }
    } catch (e) {
      print('Error loading 1967 prayers: $e');
      _cached1967Prayers = [];
    }

    return _cached1967Prayers!;
  }

  /// Load Spanish CPL prayers from CSV
  Future<List<Map<String, dynamic>>> _loadSpanishPrayers() async {
    if (_cachedSpanishPrayers != null) return _cachedSpanishPrayers!;

    try {
      final csvContent = await rootBundle.loadString('assets/data/cpl_prayer_faithful_spanish.csv');
      final lines = csvContent.split('\n');
      final headers = lines[0].split(',');

      _cachedSpanishPrayers = [];
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        
        final values = _parseCSVLine(lines[i]);
        if (values.length == headers.length) {
          final prayer = <String, dynamic>{};
          for (var j = 0; j < headers.length; j++) {
            prayer[headers[j].trim()] = values[j].trim();
          }
          _cachedSpanishPrayers!.add(prayer);
        }
      }
    } catch (e) {
      print('Error loading Spanish prayers: $e');
      _cachedSpanishPrayers = [];
    }

    return _cachedSpanishPrayers!;
  }

  /// Parse CSV line handling quoted fields
  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
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

  /// Get Prayer of the Faithful for a specific date and language
  Future<String?> getPrayerOfTheFaithful(
    DateTime date,
    String languageCode,
  ) async {
    // Try Spanish first if language is Spanish
    if (languageCode == 'es') {
      final spanishPrayer = await _getSpanishPrayer(date);
      if (spanishPrayer != null) return spanishPrayer;
    }

    // Fall back to 1967 English prayers
    return await _get1967Prayer(date);
  }

  /// Get 1967 prayer by mapping to liturgical calendar
  Future<String?> _get1967Prayer(DateTime date) async {
    final prayers = await _load1967Prayers();
    
    // Use OrdoResolverService for accurate liturgical calendar detection
    final liturgicalDay = await _ordoResolver.resolveDay(date);
    final season = _mapSeason(liturgicalDay.seasonName);
    final week = _mapWeek(liturgicalDay.weekNumber, liturgicalDay.seasonName);
    
    // Find matching prayer
    for (final prayer in prayers) {
      final prayerSeason = prayer['season_mapped'] as String?;
      final prayerWeek = prayer['week_mapped'] as String?;
      
      // Skip obsolete entries
      if (prayerSeason == 'Obsolete') continue;
      if (prayerSeason == 'Special' || prayerSeason == 'Appendix') continue;
      
      // Match by season and week
      if (prayerSeason == season && prayerWeek == week) {
        return _formatPrayer(prayer);
      }
    }
    
    // If no exact match, try to find a special occasion prayer
    // For now, return null if not found
    return null;
  }

  /// Map OrdoResolverService season to prayer season
  String _mapSeason(String ordoSeason) {
    switch (ordoSeason.toLowerCase()) {
      case 'advent':
        return 'Advent';
      case 'christmas':
        return 'Christmas';
      case 'lent':
        return 'Lent';
      case 'easter':
        return 'Easter';
      case 'ordinary':
      case 'ordinary time':
        return 'Ordinary Time';
      default:
        return 'Ordinary Time';
    }
  }

  /// Map OrdoResolverService week to prayer week
  String _mapWeek(int? ordoWeek, String ordoSeason) {
    if (ordoWeek == null) return '1';
    
    // Handle special cases based on season
    switch (ordoSeason.toLowerCase()) {
      case 'christmas':
        // Map Christmas weeks to specific feast names
        if (ordoWeek == 1) return 'Christmas';
        if (ordoWeek == 2) return 'Holy Family';
        if (ordoWeek == 3) return 'Epiphany';
        return ordoWeek.toString();
      case 'easter':
        // Map Easter weeks (Easter is week 1, Divine Mercy is week 2, etc.)
        if (ordoWeek == 1) return 'Easter';
        if (ordoWeek == 2) return '2';
        return ordoWeek.toString();
      case 'ordinary':
      case 'ordinary time':
        // Ordinary time weeks need offset for Trinity, Corpus Christi, Sacred Heart
        // These are typically weeks 1-3 after Pentecost
        if (ordoWeek >= 1 && ordoWeek <= 3) {
          return (ordoWeek + 3).toString(); // Offset for Trinity, Corpus Christi, Sacred Heart
        }
        return ordoWeek.toString();
      default:
        return ordoWeek.toString();
    }
  }

  /// Get Spanish prayer by date
  Future<String?> _getSpanishPrayer(DateTime date) async {
    final prayers = await _loadSpanishPrayers();
    
    // Spanish prayers have specific dates in the CSV
    // Format: "12 DE ABRIL DE 2026"
    for (final prayer in prayers) {
      final dateStr = prayer['date'] as String?;
      if (dateStr != null && _matchSpanishDate(dateStr, date)) {
        return _formatSpanishPrayer(prayer);
      }
    }
    
    return null;
  }

  /// Match Spanish date string to DateTime
  bool _matchSpanishDate(String spanishDate, DateTime date) {
    // Parse "12 DE ABRIL DE 2026" format
    final parts = spanishDate.split(' ');
    if (parts.length < 5) return false;
    
    final day = int.tryParse(parts[0]);
    final monthStr = parts[2].toUpperCase();
    final year = int.tryParse(parts[4]);
    
    if (day == null || year == null) return false;
    
    final monthMap = {
      'ENERO': 1,
      'FEBRERO': 2,
      'MARZO': 3,
      'ABRIL': 4,
      'MAYO': 5,
      'JUNIO': 6,
      'JULIO': 7,
      'AGOSTO': 8,
      'SEPTIEMBRE': 9,
      'OCTUBRE': 10,
      'NOVIEMBRE': 11,
      'DICIEMBRE': 12,
    };
    
    final month = monthMap[monthStr];
    if (month == null) return false;
    
    return date.day == day && date.month == month && date.year == year;
  }

  /// Format 1967 prayer for display
  String _formatPrayer(Map<String, dynamic> prayer) {
    final occasion = prayer['occasion_1967'] as String?;
    final petitions = prayer['petitions'] as String?;
    
    final buffer = StringBuffer();
    buffer.writeln('Prayer of the Faithful');
    if (occasion != null) {
      buffer.writeln(occasion);
    }
    buffer.writeln('');
    
    if (petitions != null) {
      final petitionList = petitions.split(' | ');
      for (var i = 0; i < petitionList.length; i++) {
        buffer.writeln('${i + 1}. ${petitionList[i].trim()}');
      }
    }
    
    buffer.writeln('');
    buffer.writeln('Lord, hear us.');
    buffer.writeln('Lord, graciously hear us.');
    
    return buffer.toString();
  }

  /// Format Spanish prayer for display
  String _formatSpanishPrayer(Map<String, dynamic> prayer) {
    final liturgicalRef = prayer['liturgical_reference'] as String?;
    final response = prayer['response'] as String?;
    final petitions = prayer['petitions'] as String?;
    final concluding = prayer['concluding_prayer'] as String?;
    
    final buffer = StringBuffer();
    buffer.writeln('Oración de los Fieles');
    if (liturgicalRef != null) {
      buffer.writeln(liturgicalRef);
    }
    buffer.writeln('');
    
    if (response != null) {
      buffer.writeln('Response: $response');
      buffer.writeln('');
    }
    
    if (petitions != null) {
      final petitionList = petitions.split(' | ');
      for (var i = 0; i < petitionList.length; i++) {
        buffer.writeln('${i + 1}. ${petitionList[i].trim()}');
      }
    }
    
    if (concluding != null) {
      buffer.writeln('');
      buffer.writeln(concluding);
    }
    
    return buffer.toString();
  }

  /// Get special occasion prayer (e.g., weddings, funerals, baptisms)
  Future<String?> getSpecialOccasionPrayer(String occasion, String languageCode) async {
    final prayers = await _load1967Prayers();
    
    for (final prayer in prayers) {
      final prayerSeason = prayer['season_mapped'] as String?;
      final prayerNotes = prayer['notes'] as String?;
      
      if (prayerSeason == 'Special') {
        final occasionLower = occasion.toLowerCase();
        final notesLower = prayerNotes?.toLowerCase() ?? '';
        
        if (notesLower.contains(occasionLower)) {
          return _formatPrayer(prayer);
        }
      }
    }
    
    return null;
  }

  /// Get appendix petition templates
  Future<String?> getAppendixPetitions() async {
    final prayers = await _load1967Prayers();
    
    for (final prayer in prayers) {
      final prayerSeason = prayer['season_mapped'] as String?;
      if (prayerSeason == 'Appendix') {
        return _formatPrayer(prayer);
      }
    }
    
    return null;
  }
}
