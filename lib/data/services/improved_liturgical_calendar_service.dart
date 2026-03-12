import 'package:flutter/material.dart';

/// Improved Liturgical Calendar Service with accurate calculations
class ImprovedLiturgicalCalendarService {
  static final ImprovedLiturgicalCalendarService instance = ImprovedLiturgicalCalendarService._();
  ImprovedLiturgicalCalendarService._();

  /// Get the liturgical day for a given date using proper Catholic liturgical calculations
  LiturgicalDay getLiturgicalDay(DateTime date) {
    // Determine the liturgical year (it starts with Advent)
    // For a date in 2026, we need to find if it's in Advent 2025-2026 or Advent 2026-2027
    int adventYear;
    DateTime adventStart;
    
    final thisYearAdventStart = _calculateAdventStart(date.year);
    
    if (date.isAfter(thisYearAdventStart.subtract(const Duration(days: 1))) || 
        date.isAtSameMomentAs(thisYearAdventStart)) {
      // We're in Advent of this year or later, so liturgical year is this year
      adventYear = date.year;
      adventStart = thisYearAdventStart;
    } else {
      // We're in the liturgical year that started last Advent
      adventYear = date.year - 1;
      adventStart = _calculateAdventStart(date.year - 1);
    }
    
    // Calculate key liturgical dates for the liturgical year
    // Easter is always in the calendar year after Advent starts
    // For Advent 2025-2026, Easter is in 2026
    final easterSunday = _calculateEasterSunday(adventYear + 1);
    final christmasStart = DateTime(adventYear, 12, 25);
    final epiphany = _calculateEpiphany(adventYear + 1);
    final lentStart = easterSunday.subtract(const Duration(days: 46));
    final pentecostSunday = easterSunday.add(const Duration(days: 49));
    
    // Determine liturgical season and week
    LiturgicalSeason season;
    int weekNumber = 0;
    DayOfWeek dayOfWeek = _getDayOfWeek(date.weekday);
    
    if (date.isBefore(christmasStart)) {
      // Advent season
      season = LiturgicalSeason.advent;
      weekNumber = _calculateAdventWeek(adventStart, date);
    } else if (date.isBefore(epiphany)) {
      // Christmas season
      season = LiturgicalSeason.christmas;
      weekNumber = _calculateChristmasWeek(christmasStart, date);
    } else if (date.isBefore(lentStart)) {
      // Ordinary Time I
      season = LiturgicalSeason.ordinaryTime;
      weekNumber = _calculateOrdinaryTimeWeek(epiphany, date);
    } else if (date.isBefore(easterSunday)) {
      // Lenten season
      season = LiturgicalSeason.lent;
      weekNumber = _calculateLentenWeek(lentStart, date);
    } else if (date.isBefore(pentecostSunday)) {
      // Easter season
      season = LiturgicalSeason.easter;
      weekNumber = _calculateEasterWeek(easterSunday, date);
    } else {
      // Ordinary Time II
      season = LiturgicalSeason.ordinaryTime;
      weekNumber = _calculateOrdinaryTimeWeekIi(pentecostSunday, date);
    }

    // Check for specific feast days
    final feast = _getFeastDay(date, adventYear, easterSunday);
    if (feast != null) {
      return feast;
    }

    // Determine color and rank
    final color = _getLiturgicalColor(season, date, weekNumber, easterSunday);
    final rank = _getLiturgicalRank(season, date, weekNumber, easterSunday);
    
    return LiturgicalDay(
      date: date,
      title: _getLiturgicalTitle(date, season, weekNumber, easterSunday),
      rank: rank,
      color: color,
      season: season,
      weekNumber: weekNumber,
      dayOfWeek: dayOfWeek,
    );
  }

  /// Calculate Easter Sunday using the Gregorian algorithm (Computus)
  DateTime _calculateEasterSunday(int year) {
    // Anonymous Gregorian algorithm
    int a = year % 19;
    int b = year ~/ 100;
    int c = year % 100;
    int d = b ~/ 4;
    int e = b % 4;
    int f = (b + 8) ~/ 25;
    int g = (b - f + 1) ~/ 3;
    int h = (19 * a + b - d - g + 15) % 30;
    int i = c ~/ 4;
    int k = c % 4;
    int l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * l) ~/ 451;
    int month = (h + l - 7 * m + 114) ~/ 31;
    int day = ((h + l - 7 * m + 114) % 31) + 1;
    
    DateTime easter = DateTime(year, month, day);
    
    // Apply corrections for edge cases
    if (month == 4 && day == 26 && h == 29 && l == 6) {
      easter = DateTime(year, 4, 19);
    } else if (month == 4 && day == 25 && h == 28 && l == 6 && a > 10) {
      easter = DateTime(year, 4, 18);
    }
    
    return easter;
  }

  /// Calculate Advent start (4th Sunday before Christmas)
  DateTime _calculateAdventStart(int year) {
    final christmas = DateTime(year, 12, 25);
    // Find the Sunday before Christmas (Christmas weekday - 1 = days to previous Sunday)
    int daysToPreviousSunday = (christmas.weekday + 6) % 7; // Sunday=0, Monday=1, ..., Saturday=6
    return christmas.subtract(Duration(days: daysToPreviousSunday + 21)); // 21 days = 3 weeks before that Sunday
  }

  /// Calculate Epiphany (Sunday between January 2-8, or January 6 if that's a Sunday)
  DateTime _calculateEpiphany(int year) {
    final epiphany = DateTime(year, 1, 6);
    // If January 6 is a Sunday, that's Epiphany
    if (epiphany.weekday == DateTime.sunday) {
      return epiphany;
    }
    // Otherwise, find the Sunday between Jan 2-8
    final jan2 = DateTime(year, 1, 2);
    final daysToNextSunday = (7 - jan2.weekday) % 7;
    return jan2.add(Duration(days: daysToNextSunday));
  }

  int _calculateAdventWeek(DateTime adventStart, DateTime date) {
    final daysSinceAdventStart = date.difference(adventStart).inDays;
    return (daysSinceAdventStart ~/ 7) + 1;
  }

  int _calculateChristmasWeek(DateTime christmasStart, DateTime date) {
    final daysSinceChristmas = date.difference(christmasStart).inDays;
    return (daysSinceChristmas ~/ 7) + 1;
  }

  int _calculateOrdinaryTimeWeek(DateTime startDate, DateTime date) {
    final daysSinceStart = date.difference(startDate).inDays;
    return (daysSinceStart ~/ 7) + 1;
  }

  int _calculateLentenWeek(DateTime lentStart, DateTime date) {
    final daysSinceLentStart = date.difference(lentStart).inDays;
    return (daysSinceLentStart ~/ 7) + 1;
  }

  int _calculateEasterWeek(DateTime easterStart, DateTime date) {
    final daysSinceEaster = date.difference(easterStart).inDays;
    return (daysSinceEaster ~/ 7) + 1;
  }

  int _calculateOrdinaryTimeWeekIi(DateTime pentecostStart, DateTime date) {
    final daysSincePentecost = date.difference(pentecostStart).inDays;
    return (daysSincePentecost ~/ 7) + 9; // Start counting from week 9 after Pentecost
  }

  DayOfWeek _getDayOfWeek(int weekday) {
    switch (weekday) {
      case 1: return DayOfWeek.monday;
      case 2: return DayOfWeek.tuesday;
      case 3: return DayOfWeek.wednesday;
      case 4: return DayOfWeek.thursday;
      case 5: return DayOfWeek.friday;
      case 6: return DayOfWeek.saturday;
      case 7: return DayOfWeek.sunday;
      default: return DayOfWeek.sunday;
    }
  }

  LiturgicalColor _getLiturgicalColor(LiturgicalSeason season, DateTime date, int weekNumber, DateTime easterSunday) {
    // Check for special days
    if (date.weekday == DateTime.sunday) {
      // Gaudete Sunday (3rd Advent)
      if (season == LiturgicalSeason.advent && weekNumber == 3) {
        return LiturgicalColor.pink;
      }
      // Laetare Sunday (4th Lent)
      if (season == LiturgicalSeason.lent && weekNumber == 4) {
        return LiturgicalColor.pink;
      }
      // Palm Sunday
      if (season == LiturgicalSeason.lent && _isPalmSunday(date, easterSunday)) {
        return LiturgicalColor.red;
      }
      // Pentecost Sunday
      if (season == LiturgicalSeason.easter && weekNumber == 8) {
        return LiturgicalColor.red;
      }
    }

    // Good Friday
    if (_isGoodFriday(date, easterSunday)) {
      return LiturgicalColor.red;
    }

    // Easter Octave
    if (season == LiturgicalSeason.easter && weekNumber == 1) {
      return LiturgicalColor.white;
    }

    // Default seasonal colors
    switch (season) {
      case LiturgicalSeason.advent: return LiturgicalColor.purple;
      case LiturgicalSeason.christmas: return LiturgicalColor.white;
      case LiturgicalSeason.lent: return LiturgicalColor.purple;
      case LiturgicalSeason.easter: return LiturgicalColor.white;
      case LiturgicalSeason.ordinaryTime: return LiturgicalColor.green;
    }
  }

  String? _getLiturgicalRank(LiturgicalSeason season, DateTime date, int weekNumber, DateTime easterSunday) {
    // Check for solemnities
    if (_isSolemnity(date, easterSunday)) {
      return 'Solemnity';
    }
    
    if (date.weekday == DateTime.sunday) {
      if (season == LiturgicalSeason.advent || season == LiturgicalSeason.lent) {
        return 'Sunday';
      } else if (season == LiturgicalSeason.easter && weekNumber <= 7) {
        return 'Sunday of Easter';
      } else {
        return 'Sunday';
      }
    }
    
    return null;
  }

  bool _isSolemnity(DateTime date, DateTime easterSunday) {
    final month = date.month;
    final day = date.day;
    
    // Fixed date solemnities
    if (month == 1 && day == 1) return true; // Mary, Mother of God
    if (month == 8 && day == 15) return true; // Assumption
    if (month == 11 && day == 1) return true; // All Saints
    if (month == 12 && day == 8) return true; // Immaculate Conception
    if (month == 12 && day == 25) return true; // Christmas
    
    // Easter-related solemnities
    if (_isEasterSunday(date, easterSunday)) return true;
    if (_isAscension(date, easterSunday)) return true;
    if (_isPentecost(date, easterSunday)) return true;
    
    return false;
  }

  bool _isEasterSunday(DateTime date, DateTime easterSunday) {
    return date.year == easterSunday.year && 
           date.month == easterSunday.month && 
           date.day == easterSunday.day;
  }

  bool _isPalmSunday(DateTime date, DateTime easterSunday) {
    final palmSunday = easterSunday.subtract(const Duration(days: 7));
    return date.year == palmSunday.year && 
           date.month == palmSunday.month && 
           date.day == palmSunday.day;
  }

  bool _isGoodFriday(DateTime date, DateTime easterSunday) {
    final goodFriday = easterSunday.subtract(const Duration(days: 2));
    return date.year == goodFriday.year && 
           date.month == goodFriday.month && 
           date.day == goodFriday.day;
  }

  bool _isAscension(DateTime date, DateTime easterSunday) {
    final ascension = easterSunday.add(const Duration(days: 39));
    return date.year == ascension.year && 
           date.month == ascension.month && 
           date.day == ascension.day;
  }

  bool _isPentecost(DateTime date, DateTime easterSunday) {
    final pentecost = easterSunday.add(const Duration(days: 49));
    return date.year == pentecost.year && 
           date.month == pentecost.month && 
           date.day == pentecost.day;
  }

  String _getLiturgicalTitle(DateTime date, LiturgicalSeason season, int weekNumber, DateTime easterSunday) {
    // Check for major feast days first
    if (_isEasterSunday(date, easterSunday)) return 'Easter Sunday';
    if (_isPalmSunday(date, easterSunday)) return 'Palm Sunday';
    if (_isGoodFriday(date, easterSunday)) return 'Good Friday';
    if (_isAscension(date, easterSunday)) return 'Ascension Thursday';
    if (_isPentecost(date, easterSunday)) return 'Pentecost Sunday';
    
    // Check for fixed feast days
    final month = date.month;
    final day = date.day;
    
    if (month == 12 && day == 25) return 'The Nativity of the Lord';
    if (month == 1 && day == 1) return 'Mary, Mother of God';
    if (month == 1 && day == 6) return 'The Epiphany of the Lord';
    if (month == 8 && day == 15) return 'The Assumption';
    if (month == 11 && day == 1) return 'All Saints';
    if (month == 12 && day == 8) return 'The Immaculate Conception';
    
    // Seasonal titles for Sundays
    if (date.weekday == DateTime.sunday) {
      switch (season) {
        case LiturgicalSeason.advent:
          return 'Advent Week $weekNumber';
        case LiturgicalSeason.christmas:
          if (weekNumber == 1) return 'Christmas Day';
          return 'Christmas Week $weekNumber';
        case LiturgicalSeason.lent:
          return 'Lent Week $weekNumber';
        case LiturgicalSeason.easter:
          return 'Easter Week $weekNumber';
        case LiturgicalSeason.ordinaryTime:
          return 'Ordinary Time Week $weekNumber';
      }
    }
    
    // Return empty for weekdays (no special title)
    return '';
  }

  LiturgicalDay? _getFeastDay(DateTime date, int year, DateTime easterSunday) {
    final month = date.month;
    final day = date.day;
    
    // Check fixed feast days
    switch (month) {
      case 1:
        if (day == 1) {
          return LiturgicalDay(
            date: date,
            title: 'Mary, Mother of God',
            rank: 'Solemnity',
            color: LiturgicalColor.white,
            season: LiturgicalSeason.christmas,
            weekNumber: 0,
            dayOfWeek: _getDayOfWeek(date.weekday),
          );
        }
        break;
      case 12:
        if (day == 8) {
          return LiturgicalDay(
            date: date,
            title: 'The Immaculate Conception',
            rank: 'Solemnity',
            color: LiturgicalColor.white,
            season: LiturgicalSeason.advent,
            weekNumber: 0,
            dayOfWeek: _getDayOfWeek(date.weekday),
          );
        }
        if (day == 25) {
          return LiturgicalDay(
            date: date,
            title: 'The Nativity of the Lord',
            rank: 'Solemnity',
            color: LiturgicalColor.white,
            season: LiturgicalSeason.christmas,
            weekNumber: 0,
            dayOfWeek: _getDayOfWeek(date.weekday),
          );
        }
        break;
    }
    
    // Easter-based feast days
    if (date.year == easterSunday.year) {
      final daysFromEaster = date.difference(easterSunday).inDays;
      
      if (daysFromEaster == 0) {
        return LiturgicalDay(
          date: date,
          title: 'Easter Sunday',
          rank: 'Solemnity',
          color: LiturgicalColor.white,
          season: LiturgicalSeason.easter,
          weekNumber: 0,
          dayOfWeek: _getDayOfWeek(date.weekday),
        );
      }
      
      if (daysFromEaster == 49) {
        return LiturgicalDay(
          date: date,
          title: 'Pentecost Sunday',
          rank: 'Solemnity',
          color: LiturgicalColor.red,
          season: LiturgicalSeason.easter,
          weekNumber: 0,
          dayOfWeek: _getDayOfWeek(date.weekday),
        );
      }
    }
    
    return null;
  }
}

/// Re-use existing enums and classes from the original service
enum LiturgicalColor {
  green, purple, red, pink, white, gold
}

enum LiturgicalSeason {
  advent, christmas, lent, easter, ordinaryTime
}

enum DayOfWeek {
  sunday, monday, tuesday, wednesday, thursday, friday, saturday
}

class LiturgicalDay {
  final DateTime date;
  final String title;
  final String? rank;
  final LiturgicalColor color;
  final LiturgicalSeason season;
  final int weekNumber;
  final DayOfWeek dayOfWeek;

  const LiturgicalDay({
    required this.date,
    required this.title,
    this.rank,
    required this.color,
    required this.season,
    required this.weekNumber,
    required this.dayOfWeek,
  });

  Color get colorValue {
    switch (color) {
      case LiturgicalColor.green: return const Color(0xFF228B22);
      case LiturgicalColor.purple: return const Color(0xFF6B3FA0);
      case LiturgicalColor.red: return const Color(0xFFB22222);
      case LiturgicalColor.pink: return const Color(0xFFFF69B4);
      case LiturgicalColor.white: return const Color(0xFFF5F5F5);
      case LiturgicalColor.gold: return const Color(0xFFFFD700);
    }
  }

  Color get textColor {
    switch (color) {
      case LiturgicalColor.white:
      case LiturgicalColor.gold:
        return Colors.black87;
      default:
        return Colors.white;
    }
  }

  String get seasonName {
    switch (season) {
      case LiturgicalSeason.advent: return 'Advent';
      case LiturgicalSeason.christmas: return 'Christmas';
      case LiturgicalSeason.lent: return 'Lent';
      case LiturgicalSeason.easter: return 'Easter';
      case LiturgicalSeason.ordinaryTime: return 'Ordinary Time';
    }
  }

  String get weekDescription {
    if (season == LiturgicalSeason.ordinaryTime) {
      return '$dayName of the ${_ordinal(weekNumber)} week of Ordinary Time';
    } else if (season == LiturgicalSeason.lent) {
      return '$dayName of the ${_ordinal(weekNumber)} week of Lent';
    } else if (season == LiturgicalSeason.advent) {
      return '$dayName of the ${_ordinal(weekNumber)} week of Advent';
    } else if (season == LiturgicalSeason.easter) {
      return '$dayName of the ${_ordinal(weekNumber)} week of Easter';
    } else if (season == LiturgicalSeason.christmas) {
      return dayName;
    }
    return '';
  }

  String get dayName {
    switch (dayOfWeek) {
      case DayOfWeek.sunday: return 'Sunday';
      case DayOfWeek.monday: return 'Monday';
      case DayOfWeek.tuesday: return 'Tuesday';
      case DayOfWeek.wednesday: return 'Wednesday';
      case DayOfWeek.thursday: return 'Thursday';
      case DayOfWeek.friday: return 'Friday';
      case DayOfWeek.saturday: return 'Saturday';
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  String get fullDescription {
    final buffer = StringBuffer();
    if (rank != null && rank!.isNotEmpty) {
      buffer.write(rank);
      if (title.isNotEmpty) {
        buffer.write(': ');
      }
    }
    buffer.write(title);
    if (weekNumber > 0) {
      buffer.write(' — $weekDescription');
    }
    return buffer.toString();
  }
}
