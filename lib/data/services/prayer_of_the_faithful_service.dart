import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ordo_resolver_service.dart';
import 'improved_liturgical_calendar_service.dart';

/// Service for loading and serving Prayer of the Faithful (Universal Prayer) content
/// Following GIRM §70-71 and current Roman Missal (3rd Edition) standards
class PrayerOfTheFaithfulService {
  static final PrayerOfTheFaithfulService instance = PrayerOfTheFaithfulService._internal();
  factory PrayerOfTheFaithfulService() => instance;
  PrayerOfTheFaithfulService._internal();

  List<Map<String, dynamic>>? _cachedPrayers;
  List<Map<String, dynamic>>? _cachedSpanishPrayers;
  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;

  /// Standard response following current Roman Missal
  static const String _standardResponse = 'Lord, hear our prayer.';

  /// Standard GIRM petition categories for fallback
  static const List<String> _standardCategories = [
    'For the Church',
    'For the Nations and Leaders',
    'For Those in Need',
    'For the Local Community',
    'For the Faithful Departed',
  ];

  /// Load modern English prayers from CSV (Roman Missal 3rd Edition format)
  Future<List<Map<String, dynamic>>> _loadPrayers() async {
    if (_cachedPrayers != null) return _cachedPrayers!;

    try {
      // Try modern CSV first, fall back to legacy if not found
      String csvContent;
      try {
        csvContent = await rootBundle.loadString('assets/data/prayer_of_faithful_modern.csv');
      } catch (_) {
        // Fall back to legacy format
        csvContent = await rootBundle.loadString('assets/data/prayer_of_faithful_mapped.csv');
      }
      
      final lines = csvContent.split('\n');
      if (lines.isEmpty) {
        _cachedPrayers = [];
        return _cachedPrayers!;
      }
      
      final headers = lines[0].split(',');

      _cachedPrayers = [];
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        
        final values = _parseCSVLine(lines[i]);
        if (values.length == headers.length) {
          final prayer = <String, dynamic>{};
          for (var j = 0; j < headers.length; j++) {
            prayer[headers[j].trim()] = values[j].trim();
          }
          _cachedPrayers!.add(prayer);
        }
      }
    } catch (e) {
      debugPrint('Error loading prayers: $e');
      _cachedPrayers = [];
    }

    return _cachedPrayers!;
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
      debugPrint('Error loading Spanish prayers: $e');
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
  /// Returns null if no specific prayer is available (normal for weekdays)
  Future<String?> getPrayerOfTheFaithful(
    DateTime date,
    String languageCode,
  ) async {
    // Try Spanish first if language is Spanish
    if (languageCode == 'es') {
      final spanishPrayer = await _getSpanishPrayer(date);
      if (spanishPrayer != null) return spanishPrayer;
    }

    // Try to find specific prayer for date
    final specificPrayer = await _getSpecificPrayer(date);
    if (specificPrayer != null) return specificPrayer;

    // If no specific prayer and it's a Sunday/solemnity, generate from template
    final liturgicalDay = await _ordoResolver.resolveDay(date);
    if (_isSundayOrSolemnity(liturgicalDay)) {
      return _generateFromTemplate(liturgicalDay);
    }

    // Weekdays typically don't have specific prayers
    return null;
  }

  /// Check if date is Sunday or solemnity
  bool _isSundayOrSolemnity(LiturgicalDay liturgicalDay) {
    // Check for Sunday using DayOfWeek enum
    if (liturgicalDay.dayOfWeek == DayOfWeek.sunday) return true;
    // Check if it's a solemnity by rank
    if (liturgicalDay.rank?.toLowerCase() == 'solemnity') return true;
    // Check if title indicates a Sunday or major feast
    final title = liturgicalDay.title.toLowerCase();
    if (title.contains('sunday') || title.contains('saturday vigil')) return true;
    return false;
  }

  /// Get specific prayer by mapping to liturgical calendar
  Future<String?> _getSpecificPrayer(DateTime date) async {
    final prayers = await _loadPrayers();
    
    // Use OrdoResolverService for accurate liturgical calendar detection
    final liturgicalDay = await _ordoResolver.resolveDay(date);
    final seasonName = _getSeasonName(liturgicalDay.season);
    final season = _mapSeason(seasonName);
    final week = _mapWeek(liturgicalDay.weekNumber, seasonName);
    
    debugPrint('PrayerOfTheFaithful: Searching for prayer - Season: $season, Week: $week, Day: ${liturgicalDay.dayOfWeek}');
    
    // First try to find exact match by title/feast day
    final title = liturgicalDay.title;
    if (title.isNotEmpty) {
      for (final prayer in prayers) {
        final prayerOccasion = prayer['occasion'] as String?;
        if (prayerOccasion != null && 
            prayerOccasion.toLowerCase().contains(title.toLowerCase())) {
          debugPrint('PrayerOfTheFaithful: Found occasion match for $title');
          return _formatPrayerModern(prayer);
        }
      }
    }
    
    // Fall back to season/week matching
    for (final prayer in prayers) {
      final prayerSeason = prayer['season'] as String? ?? prayer['season_mapped'] as String?;
      final prayerWeek = prayer['week'] as String? ?? prayer['week_mapped'] as String?;
      final prayerDay = prayer['day'] as String?;
      
      // Skip obsolete/special entries
      if (prayerSeason == 'Obsolete' || prayerSeason == 'Special' || prayerSeason == 'Appendix') continue;
      
      // Match by season and week
      if (prayerSeason == season && prayerWeek == week) {
        // If day specified, match day too
        if (prayerDay != null && prayerDay.isNotEmpty) {
          final dayName = liturgicalDay.dayName;
          if (prayerDay.toLowerCase() != dayName.toLowerCase()) continue;
        }
        debugPrint('PrayerOfTheFaithful: Found matching prayer for $season week $week');
        return _formatPrayerModern(prayer);
      }
    }
    
    debugPrint('PrayerOfTheFaithful: No specific prayer found for $season week $week');
    return null;
  }

  /// Get season name from LiturgicalSeason enum
  String _getSeasonName(LiturgicalSeason season) {
    switch (season) {
      case LiturgicalSeason.advent: return 'advent';
      case LiturgicalSeason.christmas: return 'christmas';
      case LiturgicalSeason.lent: return 'lent';
      case LiturgicalSeason.easter: return 'easter';
      case LiturgicalSeason.ordinaryTime: return 'ordinary time';
    }
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

  /// Format prayer with modern Roman Missal structure
  /// Following GIRM §70-71 format with proper response
  String _formatPrayerModern(Map<String, dynamic> prayer) {
    final occasion = prayer['occasion'] as String? ?? prayer['occasion_1967'] as String?;
    final response = prayer['response'] as String? ?? _standardResponse;
    
    // Parse petitions with their categories
    final petitions = <Map<String, String>>[];
    
    // Try structured petition fields first (petition_1, petition_2, etc.)
    for (var i = 1; i <= 5; i++) {
      final petitionText = prayer['petition_$i'] as String?;
      if (petitionText != null && petitionText.isNotEmpty) {
        petitions.add({
          'text': petitionText,
          'category': prayer['category_$i'] as String? ?? _standardCategories[i - 1],
        });
      }
    }
    
    // Fall back to legacy 'petitions' field with separator
    if (petitions.isEmpty) {
      final legacyPetitions = prayer['petitions'] as String?;
      if (legacyPetitions != null && legacyPetitions.isNotEmpty) {
        final petitionList = legacyPetitions.split(' | ');
        for (var i = 0; i < petitionList.length && i < _standardCategories.length; i++) {
          petitions.add({
            'text': petitionList[i].trim(),
            'category': _standardCategories[i],
          });
        }
      }
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Prayer of the Faithful');
    buffer.writeln('(Universal Prayer)');
    if (occasion != null && occasion.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(occasion);
    }
    buffer.writeln('');
    buffer.writeln('Response: $response');
    buffer.writeln('');
    
    // Format petitions with GIRM structure
    for (var i = 0; i < petitions.length; i++) {
      final petition = petitions[i];
      buffer.writeln('${i + 1}. ${petition['text']}');
      buffer.writeln('   R. $response');
      if (i < petitions.length - 1) buffer.writeln('');
    }
    
    return buffer.toString();
  }

  /// Generate a GIRM-compliant prayer from template when no specific prayer exists
  String _generateFromTemplate(LiturgicalDay liturgicalDay) {
    final season = _getSeasonName(liturgicalDay.season);
    final occasion = liturgicalDay.title;
    
    final buffer = StringBuffer();
    buffer.writeln('Prayer of the Faithful');
    buffer.writeln('(Universal Prayer)');
    if (occasion.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(occasion);
    }
    buffer.writeln('');
    buffer.writeln('Response: $_standardResponse');
    buffer.writeln('');
    
    // Generate season-appropriate petitions following GIRM categories
    final petitions = _getSeasonalPetitions(season, occasion);
    for (var i = 0; i < petitions.length; i++) {
      buffer.writeln('${i + 1}. ${petitions[i]}');
      buffer.writeln('   R. $_standardResponse');
      if (i < petitions.length - 1) buffer.writeln('');
    }
    
    return buffer.toString();
  }

  /// Get season-appropriate petition templates
  List<String> _getSeasonalPetitions(String season, String? occasion) {
    final lowerSeason = season.toLowerCase();
    
    if (lowerSeason.contains('advent')) {
      return [
        'For the Church as we await the coming of Christ, that we may be prepared to welcome him with joy, we pray to the Lord.',
        'For peace among nations and for those who govern, that they may work for justice and the common good, we pray to the Lord.',
        'For those who are sick, poor, or suffering in any way, that they may find comfort and hope in Christ\'s coming, we pray to the Lord.',
        'For our parish community and our families, that this season of preparation may deepen our faith, we pray to the Lord.',
        'For our beloved dead, and for all who have died in hope of the Resurrection, we pray to the Lord.',
      ];
    }
    
    if (lowerSeason.contains('christmas')) {
      return [
        'For the Church throughout the world, that the light of Christ may shine brightly in our hearts, we pray to the Lord.',
        'For peace on earth and goodwill among all peoples, especially in areas of conflict, we pray to the Lord.',
        'For those who are lonely, sick, or in need during this holy season, that they may experience Christ\'s love, we pray to the Lord.',
        'For our families and this worshipping community, that we may celebrate this feast with grateful hearts, we pray to the Lord.',
        'For our departed loved ones, that they may rejoice in the eternal light of Christ, we pray to the Lord.',
      ];
    }
    
    if (lowerSeason.contains('lent')) {
      return [
        'For the Church in this holy season of renewal, that we may be faithful to our baptismal commitment, we pray to the Lord.',
        'For the grace to overcome evil and to work for justice in our world, we pray to the Lord.',
        'For those preparing to receive the sacraments of initiation, and for all seeking reconciliation, we pray to the Lord.',
        'For those who suffer and for sinners, that they may find mercy and healing, we pray to the Lord.',
        'For our own intentions and for the faithful departed, we pray to the Lord.',
      ];
    }
    
    if (lowerSeason.contains('easter')) {
      return [
        'For the Church rejoicing in the Resurrection of Christ, that we may bear witness to the Risen Lord, we pray to the Lord.',
        'For peace among nations and for those who work for justice and human dignity, we pray to the Lord.',
        'For those recently baptized and for all who have returned to the Church this Easter, we pray to the Lord.',
        'For those who are sick, troubled, or in need, that they may share in the hope of the Resurrection, we pray to the Lord.',
        'For our beloved dead, that they may rise with Christ to everlasting life, we pray to the Lord.',
      ];
    }
    
    // Ordinary Time (default)
    return [
      'For the Church throughout the world, that we may faithfully proclaim the Gospel, we pray to the Lord.',
      'For our nation and all in authority, that they may serve the common good and protect the dignity of every person, we pray to the Lord.',
      'For those who suffer from illness, poverty, or any affliction, and for all in need of our prayers, we pray to the Lord.',
      'For our parish community, that we may grow in faith, hope, and love, we pray to the Lord.',
      'For our deceased relatives and friends, and for all who have died in the peace of Christ, we pray to the Lord.',
    ];
  }

  /// Format Spanish prayer with modern structure
  String _formatSpanishPrayer(Map<String, dynamic> prayer) {
    final liturgicalRef = prayer['liturgical_reference'] as String?;
    final response = prayer['response'] as String? ?? 'Señor, escucha nuestra oración.';
    final petitions = prayer['petitions'] as String?;
    final concluding = prayer['concluding_prayer'] as String?;
    
    final buffer = StringBuffer();
    buffer.writeln('Oración de los Fieles');
    buffer.writeln('(Oración Universal)');
    if (liturgicalRef != null && liturgicalRef.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(liturgicalRef);
    }
    buffer.writeln('');
    buffer.writeln('R/. $response');
    buffer.writeln('');
    
    if (petitions != null && petitions.isNotEmpty) {
      final petitionList = petitions.split(' | ');
      for (var i = 0; i < petitionList.length; i++) {
        buffer.writeln('${i + 1}. ${petitionList[i].trim()}');
        buffer.writeln('   R/. $response');
        if (i < petitionList.length - 1) buffer.writeln('');
      }
    }
    
    if (concluding != null && concluding.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(concluding);
    }
    
    return buffer.toString();
  }

  /// Get special occasion prayer (e.g., weddings, funerals, baptisms)
  Future<String?> getSpecialOccasionPrayer(String occasion, String languageCode) async {
    final prayers = await _loadPrayers();
    
    for (final prayer in prayers) {
      final prayerSeason = prayer['season'] as String? ?? prayer['season_mapped'] as String?;
      final prayerNotes = prayer['notes'] as String?;
      
      if (prayerSeason == 'Special') {
        final occasionLower = occasion.toLowerCase();
        final notesLower = prayerNotes?.toLowerCase() ?? '';
        
        if (notesLower.contains(occasionLower)) {
          return _formatPrayerModern(prayer);
        }
      }
    }
    
    return null;
  }

  /// Get appendix petition templates as fallback
  Future<String?> getAppendixPetitions() async {
    final prayers = await _loadPrayers();
    
    for (final prayer in prayers) {
      final prayerSeason = prayer['season'] as String? ?? prayer['season_mapped'] as String?;
      if (prayerSeason == 'Appendix' || prayerSeason == 'Template') {
        return _formatPrayerModern(prayer);
      }
    }
    
    // Return generic template if no appendix found
    return _generateFromTemplate(await _ordoResolver.resolveDay(DateTime.now()));
  }

  /// Get generic template for any occasion (useful for special masses)
  String getGenericTemplate() {
    final buffer = StringBuffer();
    buffer.writeln('Prayer of the Faithful');
    buffer.writeln('(Universal Prayer)');
    buffer.writeln('');
    buffer.writeln('Response: $_standardResponse');
    buffer.writeln('');
    
    final petitions = [
      'For the holy Church of God, that the Lord may guide and protect her, we pray to the Lord.',
      'For our nation and all in authority, that they may govern with wisdom and justice, we pray to the Lord.',
      'For those who are sick, suffering, or in any need, that they may find comfort and aid, we pray to the Lord.',
      'For our community gathered here and for all our families, that we may grow in faith and love, we pray to the Lord.',
      'For our beloved dead, that they may rest in the peace of Christ, we pray to the Lord.',
    ];
    
    for (var i = 0; i < petitions.length; i++) {
      buffer.writeln('${i + 1}. ${petitions[i]}');
      buffer.writeln('   R. $_standardResponse');
      if (i < petitions.length - 1) buffer.writeln('');
    }
    
    return buffer.toString();
  }
}
