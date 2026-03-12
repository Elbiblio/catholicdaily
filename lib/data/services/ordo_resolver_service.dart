import 'dart:convert';

import 'package:http/http.dart' as http;

import 'improved_liturgical_calendar_service.dart';
import 'offline_ordo_lookup_service.dart';

class OrdoResolverService {
  static final OrdoResolverService instance = OrdoResolverService._();
  OrdoResolverService._();

  static const _baseUrl = 'https://calapi.inadiutorium.cz/api/v0/en';
  String _calendarId = 'default';
  bool _preferOffline = true;

  final Map<String, LiturgicalDay> _dayCache = {};
  final Map<int, OrdoYearVariables> _yearVarCache = {};
  final OfflineOrdoLookupService _offline = OfflineOrdoLookupService.instance;

  void setCalendarId(String calendarId) {
    final cleaned = calendarId.trim();
    if (cleaned.isEmpty || cleaned == _calendarId) return;
    _calendarId = cleaned;
    _dayCache.clear();
  }

  void setPreferOffline(bool preferOffline) {
    if (_preferOffline == preferOffline) return;
    _preferOffline = preferOffline;
    _dayCache.clear();
  }

  Future<LiturgicalDay> resolveDay(DateTime date) async {
    final key =
        '${_preferOffline ? 'offline' : 'api'}_${_calendarId}_${date.year}-${date.month}-${date.day}';
    if (_dayCache.containsKey(key)) return _dayCache[key]!;

    try {
      if (_preferOffline) {
        final offlineDay = _offline.resolve(date);
        _dayCache[key] = offlineDay;
        return offlineDay;
      }

      final resolved = await _resolveViaCalendarApi(date);
      _dayCache[key] = resolved;
      return resolved;
    } catch (_) {
      try {
        final offlineDay = _offline.resolve(date);
        _dayCache[key] = offlineDay;
        return offlineDay;
      } catch (_) {
        final fallback = ImprovedLiturgicalCalendarService.instance
            .getLiturgicalDay(date);
        _dayCache[key] = fallback;
        return fallback;
      }
    }
  }

  Future<OrdoYearVariables> resolveYearVariables(DateTime date) async {
    final liturgicalYear = _liturgicalYearForDate(date);
    if (_yearVarCache.containsKey(liturgicalYear)) {
      return _yearVarCache[liturgicalYear]!;
    }

    String? sundayCycle;
    String? weekdayCycle;
    try {
      final setup = await _fetchYearSetup(liturgicalYear - 1);
      sundayCycle = setup['lectionary'] as String?;
      weekdayCycle = _toRoman(setup['ferial_lectionary'] as int?);
    } catch (_) {
      // Keep computed fallback values below.
    }

    final vars = OrdoYearVariables(
      year: liturgicalYear,
      goldenNumber: ((liturgicalYear - 1) % 19) + 1,
      epact: _epactRoman(liturgicalYear),
      solarCycle: ((liturgicalYear + 8) % 28) + 1,
      indiction: ((liturgicalYear + 2) % 15) + 1,
      julianPeriodYear: liturgicalYear + 4713,
      yearsSinceIgnatius: liturgicalYear - 1556,
      sundayCycle: sundayCycle ?? _fallbackSundayCycle(liturgicalYear),
      weekdayCycle: weekdayCycle ?? _fallbackWeekdayCycle(liturgicalYear),
    );

    _yearVarCache[liturgicalYear] = vars;
    return vars;
  }

  Future<LiturgicalDay> _resolveViaCalendarApi(DateTime date) async {
    final url = Uri.parse(
      '$_baseUrl/calendars/$_calendarId/${date.year}/${date.month}/${date.day}',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Calendar API status ${response.statusCode}');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final season = _seasonFromApi(map['season'] as String?);
    final weekNumber = (map['season_week'] as num?)?.toInt() ?? 0;
    final dayOfWeek = _dayFromApi(map['weekday'] as String?);

    final celebrationsRaw = (map['celebrations'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => entry.map((k, v) => MapEntry('$k', v)))
        .toList();
    final selected = _selectPrimaryCelebration(celebrationsRaw);

    final color = _colorFromApi(selected?['colour'] as String?);
    final rank = selected?['rank'] as String?;
    final title = _deriveTitle(
      selected?['title'] as String?,
      season: season,
      weekNumber: weekNumber,
      dayOfWeek: dayOfWeek,
    );

    return LiturgicalDay(
      date: date,
      title: title,
      rank: rank,
      color: color,
      season: season,
      weekNumber: weekNumber,
      dayOfWeek: dayOfWeek,
    );
  }

  Future<Map<String, dynamic>> _fetchYearSetup(int liturgicalStartYear) async {
    final url = Uri.parse('$_baseUrl/$liturgicalStartYear');
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Year setup status ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic>? _selectPrimaryCelebration(
    List<Map<String, dynamic>> celebrations,
  ) {
    if (celebrations.isEmpty) return null;

    Map<String, dynamic> current = celebrations.first;
    double currentRank = (current['rank_num'] as num?)?.toDouble() ?? 999;

    for (final candidate in celebrations.skip(1)) {
      final rank = (candidate['rank_num'] as num?)?.toDouble() ?? 999;
      final title = (candidate['title'] as String? ?? '').trim();
      final currentTitle = (current['title'] as String? ?? '').trim();

      if (rank < currentRank) {
        current = candidate;
        currentRank = rank;
      } else if (rank == currentRank &&
          title.isNotEmpty &&
          currentTitle.isEmpty) {
        current = candidate;
      }
    }

    return current;
  }

  String _deriveTitle(
    String? title, {
    required LiturgicalSeason season,
    required int weekNumber,
    required DayOfWeek dayOfWeek,
  }) {
    final cleaned = (title ?? '').trim();
    if (cleaned.isNotEmpty) return cleaned;
    final day = _dayName(dayOfWeek);
    if (weekNumber <= 0) return '$day in ${_seasonName(season)}';
    final ordinalWeek = _ordinal(weekNumber);
    switch (season) {
      case LiturgicalSeason.advent:
        return '$day of the $ordinalWeek week of Advent';
      case LiturgicalSeason.christmas:
        return '$day of Christmastide';
      case LiturgicalSeason.lent:
        return '$day of the $ordinalWeek week of Lent';
      case LiturgicalSeason.easter:
        return '$day of the $ordinalWeek week of Easter';
      case LiturgicalSeason.ordinaryTime:
        return '$day of the $ordinalWeek week in Ordinary Time';
    }
  }

  int _liturgicalYearForDate(DateTime date) {
    final adventStart = _calculateAdventStart(date.year);
    return date.isBefore(adventStart) ? date.year : date.year + 1;
  }

  DateTime _calculateAdventStart(int year) {
    final christmas = DateTime(year, 12, 25);
    final daysToPreviousSunday = (christmas.weekday + 6) % 7;
    return christmas.subtract(Duration(days: daysToPreviousSunday + 21));
  }

  LiturgicalSeason _seasonFromApi(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'advent':
        return LiturgicalSeason.advent;
      case 'christmas':
        return LiturgicalSeason.christmas;
      case 'lent':
        return LiturgicalSeason.lent;
      case 'easter':
        return LiturgicalSeason.easter;
      case 'ordinary':
      default:
        return LiturgicalSeason.ordinaryTime;
    }
  }

  DayOfWeek _dayFromApi(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'monday':
        return DayOfWeek.monday;
      case 'tuesday':
        return DayOfWeek.tuesday;
      case 'wednesday':
        return DayOfWeek.wednesday;
      case 'thursday':
        return DayOfWeek.thursday;
      case 'friday':
        return DayOfWeek.friday;
      case 'saturday':
        return DayOfWeek.saturday;
      case 'sunday':
      default:
        return DayOfWeek.sunday;
    }
  }

  LiturgicalColor _colorFromApi(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'red':
        return LiturgicalColor.red;
      case 'white':
        return LiturgicalColor.white;
      case 'violet':
      case 'purple':
        return LiturgicalColor.purple;
      case 'rose':
      case 'pink':
        return LiturgicalColor.pink;
      case 'green':
      default:
        return LiturgicalColor.green;
    }
  }

  String _dayName(DayOfWeek day) {
    switch (day) {
      case DayOfWeek.monday:
        return 'Monday';
      case DayOfWeek.tuesday:
        return 'Tuesday';
      case DayOfWeek.wednesday:
        return 'Wednesday';
      case DayOfWeek.thursday:
        return 'Thursday';
      case DayOfWeek.friday:
        return 'Friday';
      case DayOfWeek.saturday:
        return 'Saturday';
      case DayOfWeek.sunday:
        return 'Sunday';
    }
  }

  String _seasonName(LiturgicalSeason season) {
    switch (season) {
      case LiturgicalSeason.advent:
        return 'Advent';
      case LiturgicalSeason.christmas:
        return 'Christmas';
      case LiturgicalSeason.lent:
        return 'Lent';
      case LiturgicalSeason.easter:
        return 'Easter';
      case LiturgicalSeason.ordinaryTime:
        return 'Ordinary Time';
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  String _epactRoman(int year) {
    final c = year ~/ 100;
    var epact =
        (8 + (c ~/ 4) - c + ((8 * c + 13) ~/ 25) + 11 * (year % 19)) % 30;
    if (epact == 0 || (epact == 1 && (year % 19) > 10)) {
      epact += 1;
    }
    return _toRoman(epact).toLowerCase();
  }

  String _fallbackSundayCycle(int liturgicalYear) {
    const cycles = ['A', 'B', 'C'];
    return cycles[(liturgicalYear + 1) % 3];
  }

  String _fallbackWeekdayCycle(int liturgicalYear) {
    return liturgicalYear.isEven ? 'II' : 'I';
  }

  String _toRoman(int? value) {
    if (value == null || value <= 0) return '';
    final numerals = <int, String>{
      1000: 'M',
      900: 'CM',
      500: 'D',
      400: 'CD',
      100: 'C',
      90: 'XC',
      50: 'L',
      40: 'XL',
      10: 'X',
      9: 'IX',
      5: 'V',
      4: 'IV',
      1: 'I',
    };
    var n = value;
    final out = StringBuffer();
    numerals.forEach((k, v) {
      while (n >= k) {
        out.write(v);
        n -= k;
      }
    });
    return out.toString();
  }
}

class OrdoYearVariables {
  final int year;
  final int goldenNumber;
  final String epact;
  final int solarCycle;
  final int indiction;
  final int julianPeriodYear;
  final int yearsSinceIgnatius;
  final String sundayCycle;
  final String weekdayCycle;

  const OrdoYearVariables({
    required this.year,
    required this.goldenNumber,
    required this.epact,
    required this.solarCycle,
    required this.indiction,
    required this.julianPeriodYear,
    required this.yearsSinceIgnatius,
    required this.sundayCycle,
    required this.weekdayCycle,
  });
}
