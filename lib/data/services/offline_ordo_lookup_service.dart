import 'improved_liturgical_calendar_service.dart';

class OfflineOrdoLookupService {
  static final OfflineOrdoLookupService instance = OfflineOrdoLookupService._();
  OfflineOrdoLookupService._();

  LiturgicalDay resolve(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final easter = _calculateEasterSunday(day.year);
    final adventStart = _calculateAdventStart(day.year);
    final previousAdventStart = _calculateAdventStart(day.year - 1);
    final christmas = DateTime(day.year, 12, 25);

    final epiphany = _calculateEpiphany(day.year);
    final baptism = _calculateBaptismOfTheLord(day.year, epiphany);
    final ashWednesday = easter.subtract(const Duration(days: 46));
    final palmSunday = easter.subtract(const Duration(days: 7));
    final holyThursday = easter.subtract(const Duration(days: 3));
    final goodFriday = easter.subtract(const Duration(days: 2));
    final holySaturday = easter.subtract(const Duration(days: 1));
    final pentecost = easter.add(const Duration(days: 49));
    final trinitySunday = pentecost.add(const Duration(days: 7));
    final corpusChristi = pentecost.add(const Duration(days: 14));
    final sacredHeart = pentecost.add(const Duration(days: 19));
    final immaculateHeart = pentecost.add(const Duration(days: 20));
    final divineMercySunday = easter.add(const Duration(days: 7));
    final christTheKing = _lastSundayBefore(adventStart);

    final annunciation = _transferAnnunciation(day.year, easter);
    final joseph = _transferStJoseph(day.year, easter);
    final holyFamily = _calculateHolyFamilySunday(day.year);

    final movable = <DateTime, _Celebration>{
      DateTime(day.year, 1, 1): _solemnity(
        'Mary, the Holy Mother of God',
        LiturgicalColor.white,
      ),
      epiphany: _solemnity('The Epiphany of the Lord', LiturgicalColor.white),
      baptism: _feast('The Baptism of the Lord', LiturgicalColor.white),
      ashWednesday: _day('Ash Wednesday', LiturgicalColor.purple, 'Day'),
      joseph: _solemnity(
        'Saint Joseph, Spouse of the Blessed Virgin Mary',
        LiturgicalColor.white,
      ),
      annunciation: _solemnity(
        'The Annunciation of the Lord',
        LiturgicalColor.white,
      ),
      palmSunday: _solemnity(
        'Palm Sunday of the Passion of the Lord',
        LiturgicalColor.red,
      ),
      holyThursday: _solemnity(
        'Holy Thursday - Evening Mass of the Lord\'s Supper',
        LiturgicalColor.white,
      ),
      goodFriday: _day(
        'Friday of the Passion of the Lord',
        LiturgicalColor.red,
        'Day',
      ),
      holySaturday: _day('Holy Saturday', LiturgicalColor.purple, 'Day'),
      easter: _solemnity(
        'Easter Sunday of the Resurrection of the Lord',
        LiturgicalColor.white,
      ),
      divineMercySunday: _sunday(
        'Second Sunday of Easter (Divine Mercy)',
        LiturgicalColor.white,
      ),
      pentecost: _solemnity('Pentecost Sunday', LiturgicalColor.red),
      trinitySunday: _solemnity('The Most Holy Trinity', LiturgicalColor.white),
      corpusChristi: _solemnity(
        'The Most Holy Body and Blood of Christ',
        LiturgicalColor.white,
      ),
      sacredHeart: _solemnity(
        'The Most Sacred Heart of Jesus',
        LiturgicalColor.white,
      ),
      immaculateHeart: _memorial(
        'The Immaculate Heart of the Blessed Virgin Mary',
        LiturgicalColor.white,
      ),
      christTheKing: _solemnity(
        'Our Lord Jesus Christ, King of the Universe',
        LiturgicalColor.white,
      ),
      holyFamily: _feast(
        'The Holy Family of Jesus, Mary, and Joseph',
        LiturgicalColor.white,
      ),
      DateTime(day.year, 6, 24): _solemnity(
        'The Nativity of Saint John the Baptist',
        LiturgicalColor.white,
      ),
      DateTime(day.year, 6, 29): _solemnity(
        'Saints Peter and Paul, Apostles',
        LiturgicalColor.red,
      ),
      DateTime(day.year, 8, 15): _solemnity(
        'The Assumption of the Blessed Virgin Mary',
        LiturgicalColor.white,
      ),
      DateTime(day.year, 11, 1): _solemnity(
        'All Saints',
        LiturgicalColor.white,
      ),
      DateTime(day.year, 11, 2): _day(
        'The Commemoration of All the Faithful Departed',
        LiturgicalColor.purple,
        'Commemoration',
      ),
      DateTime(day.year, 12, 8): _solemnity(
        'The Immaculate Conception of the Blessed Virgin Mary',
        LiturgicalColor.white,
      ),
      DateTime(day.year, 12, 25): _solemnity(
        'The Nativity of the Lord',
        LiturgicalColor.white,
      ),
    };

    final fixed = _fixedCelebrations(day.year);
    final candidate = movable[day] ?? fixed[day];

    final seasonData = _seasonForDay(
      day: day,
      easter: easter,
      ashWednesday: ashWednesday,
      pentecost: pentecost,
      adventStart: adventStart,
      previousAdventStart: previousAdventStart,
      christmas: christmas,
      epiphany: epiphany,
      baptism: baptism,
    );

    final ferial = _ferialDay(day, seasonData);
    if (candidate == null) return ferial;

    // Sundays of Advent/Lent/Easter outrank most fixed celebrations except solemnities.
    if (day.weekday == DateTime.sunday &&
        (seasonData.season == LiturgicalSeason.advent ||
            seasonData.season == LiturgicalSeason.lent ||
            seasonData.season == LiturgicalSeason.easter) &&
        candidate.rank != 'Solemnity') {
      return ferial;
    }

    return LiturgicalDay(
      date: day,
      title: candidate.title,
      rank: candidate.rank,
      color: candidate.color,
      season: seasonData.season,
      weekNumber: seasonData.weekNumber,
      dayOfWeek: _toDayOfWeek(day.weekday),
    );
  }

  Map<DateTime, _Celebration> _fixedCelebrations(int year) {
    return {
      DateTime(year, 1, 25): _feast(
        'The Conversion of Saint Paul, Apostle',
        LiturgicalColor.white,
      ),
      DateTime(year, 2, 2): _feast(
        'The Presentation of the Lord',
        LiturgicalColor.white,
      ),
      DateTime(year, 2, 22): _feast(
        'The Chair of Saint Peter, Apostle',
        LiturgicalColor.white,
      ),
      DateTime(year, 3, 25): _solemnity(
        'The Annunciation of the Lord',
        LiturgicalColor.white,
      ),
      DateTime(year, 7, 3): _feast(
        'Saint Thomas, Apostle',
        LiturgicalColor.red,
      ),
      DateTime(year, 7, 22): _feast(
        'Saint Mary Magdalene',
        LiturgicalColor.white,
      ),
      DateTime(year, 7, 25): _feast(
        'Saint James, Apostle',
        LiturgicalColor.red,
      ),
      DateTime(year, 8, 6): _feast(
        'The Transfiguration of the Lord',
        LiturgicalColor.white,
      ),
      DateTime(year, 8, 24): _feast(
        'Saint Bartholomew, Apostle',
        LiturgicalColor.red,
      ),
      DateTime(year, 9, 8): _feast(
        'The Nativity of the Blessed Virgin Mary',
        LiturgicalColor.white,
      ),
      DateTime(year, 9, 14): _feast(
        'The Exaltation of the Holy Cross',
        LiturgicalColor.red,
      ),
      DateTime(year, 9, 21): _feast(
        'Saint Matthew, Apostle and Evangelist',
        LiturgicalColor.red,
      ),
      DateTime(year, 9, 29): _feast(
        'Saints Michael, Gabriel, and Raphael, Archangels',
        LiturgicalColor.white,
      ),
      DateTime(year, 10, 18): _feast(
        'Saint Luke, Evangelist',
        LiturgicalColor.red,
      ),
      DateTime(year, 10, 28): _feast(
        'Saints Simon and Jude, Apostles',
        LiturgicalColor.red,
      ),
      DateTime(year, 11, 9): _feast(
        'The Dedication of the Lateran Basilica',
        LiturgicalColor.white,
      ),
      DateTime(year, 11, 30): _feast(
        'Saint Andrew, Apostle',
        LiturgicalColor.red,
      ),
      DateTime(year, 12, 26): _feast(
        'Saint Stephen, the First Martyr',
        LiturgicalColor.red,
      ),
      DateTime(year, 12, 27): _feast(
        'Saint John, Apostle and Evangelist',
        LiturgicalColor.white,
      ),
      DateTime(year, 12, 28): _feast(
        'The Holy Innocents, Martyrs',
        LiturgicalColor.red,
      ),
    };
  }

  _SeasonData _seasonForDay({
    required DateTime day,
    required DateTime easter,
    required DateTime ashWednesday,
    required DateTime pentecost,
    required DateTime adventStart,
    required DateTime previousAdventStart,
    required DateTime christmas,
    required DateTime epiphany,
    required DateTime baptism,
  }) {
    if (!day.isBefore(adventStart) && day.isBefore(christmas)) {
      final week = ((day.difference(adventStart).inDays) ~/ 7) + 1;
      return _SeasonData(LiturgicalSeason.advent, week.clamp(1, 4));
    }

    if (!day.isBefore(christmas) &&
        day.isBefore(epiphany.add(const Duration(days: 1)))) {
      return const _SeasonData(LiturgicalSeason.christmas, 1);
    }

    final januaryOrdinaryStart = baptism.add(const Duration(days: 1));
    if (!day.isBefore(januaryOrdinaryStart) && day.isBefore(ashWednesday)) {
      final week =
          ((day
                  .difference(_firstOrdinarySunday(januaryOrdinaryStart))
                  .inDays) ~/
              7) +
          1;
      return _SeasonData(LiturgicalSeason.ordinaryTime, week.clamp(1, 9));
    }

    if (!day.isBefore(ashWednesday) && day.isBefore(easter)) {
      final firstLentSunday = ashWednesday.add(const Duration(days: 4));
      if (day.isBefore(firstLentSunday)) {
        return const _SeasonData(LiturgicalSeason.lent, 0);
      }
      final week = ((day.difference(firstLentSunday).inDays) ~/ 7) + 1;
      return _SeasonData(LiturgicalSeason.lent, week.clamp(1, 6));
    }

    if (!day.isBefore(easter) && !day.isAfter(pentecost)) {
      final week = ((day.difference(easter).inDays) ~/ 7) + 1;
      return _SeasonData(LiturgicalSeason.easter, week.clamp(1, 8));
    }

    final ordinary2Start = pentecost.add(const Duration(days: 1));
    final endOfYear = adventStart.subtract(const Duration(days: 1));
    if (!day.isBefore(ordinary2Start) && !day.isAfter(endOfYear)) {
      final week =
          ((day.difference(_firstOrdinarySunday(ordinary2Start)).inDays) ~/ 7) +
          10;
      return _SeasonData(LiturgicalSeason.ordinaryTime, week.clamp(10, 34));
    }

    if (!day.isBefore(previousAdventStart) &&
        day.isBefore(DateTime(day.year, 1, 1))) {
      final week = ((day.difference(previousAdventStart).inDays) ~/ 7) + 1;
      return _SeasonData(LiturgicalSeason.advent, week.clamp(1, 4));
    }

    return const _SeasonData(LiturgicalSeason.ordinaryTime, 0);
  }

  LiturgicalDay _ferialDay(DateTime day, _SeasonData seasonData) {
    final weekday = _toDayOfWeek(day.weekday);

    if (day.weekday == DateTime.sunday) {
      final title = _sundayTitle(day, seasonData);
      final color = switch (seasonData.season) {
        LiturgicalSeason.advent => LiturgicalColor.purple,
        LiturgicalSeason.christmas => LiturgicalColor.white,
        LiturgicalSeason.lent => LiturgicalColor.purple,
        LiturgicalSeason.easter => LiturgicalColor.white,
        LiturgicalSeason.ordinaryTime => LiturgicalColor.green,
      };
      return LiturgicalDay(
        date: day,
        title: title,
        rank: 'Sunday',
        color: color,
        season: seasonData.season,
        weekNumber: seasonData.weekNumber,
        dayOfWeek: weekday,
      );
    }

    final color = switch (seasonData.season) {
      LiturgicalSeason.advent => LiturgicalColor.purple,
      LiturgicalSeason.christmas => LiturgicalColor.white,
      LiturgicalSeason.lent => LiturgicalColor.purple,
      LiturgicalSeason.easter => LiturgicalColor.white,
      LiturgicalSeason.ordinaryTime => LiturgicalColor.green,
    };

    return LiturgicalDay(
      date: day,
      title: '',
      rank: null,
      color: color,
      season: seasonData.season,
      weekNumber: seasonData.weekNumber,
      dayOfWeek: weekday,
    );
  }

  String _sundayTitle(DateTime day, _SeasonData seasonData) {
    switch (seasonData.season) {
      case LiturgicalSeason.advent:
        return '${_ordinal(seasonData.weekNumber)} Sunday of Advent';
      case LiturgicalSeason.christmas:
        return 'Sunday of Christmas Time';
      case LiturgicalSeason.lent:
        return '${_ordinal(seasonData.weekNumber)} Sunday of Lent';
      case LiturgicalSeason.easter:
        if (seasonData.weekNumber == 1) return 'Easter Sunday';
        return '${_ordinal(seasonData.weekNumber)} Sunday of Easter';
      case LiturgicalSeason.ordinaryTime:
        return '${_ordinal(seasonData.weekNumber)} Sunday in Ordinary Time';
    }
  }

  DateTime _calculateEasterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  DateTime _calculateAdventStart(int year) {
    final christmas = DateTime(year, 12, 25);
    final daysUntilSunday = (DateTime.sunday - christmas.weekday + 7) % 7;
    final sundayOnOrAfterChristmas = christmas.add(Duration(days: daysUntilSunday));
    return sundayOnOrAfterChristmas.subtract(const Duration(days: 28));
  }

  DateTime _calculateEpiphany(int year) {
    for (var day = 2; day <= 8; day++) {
      final date = DateTime(year, 1, day);
      if (date.weekday == DateTime.sunday) return date;
    }
    return DateTime(year, 1, 6);
  }

  DateTime _calculateBaptismOfTheLord(int year, DateTime epiphany) {
    if (epiphany.day == 7 || epiphany.day == 8) {
      return epiphany.add(const Duration(days: 1));
    }
    return _nextSunday(epiphany);
  }

  DateTime _transferAnnunciation(int year, DateTime easter) {
    final base = DateTime(year, 3, 25);
    final holyWeekStart = easter.subtract(const Duration(days: 7));
    final octaveEnd = easter.add(const Duration(days: 7));
    if (!base.isBefore(holyWeekStart) && !base.isAfter(octaveEnd)) {
      return easter.add(const Duration(days: 8));
    }
    return base;
  }

  DateTime _calculateHolyFamilySunday(int year) {
    // Holy Family is the Sunday within the Octave of Christmas (Dec 26-31).
    // If there is no Sunday in that range (i.e., Christmas falls on Sunday),
    // then Holy Family is celebrated on December 30.
    for (var day = 26; day <= 31; day++) {
      final date = DateTime(year, 12, day);
      if (date.weekday == DateTime.sunday) return date;
    }
    return DateTime(year, 12, 30);
  }

  DateTime _transferStJoseph(int year, DateTime easter) {
    final base = DateTime(year, 3, 19);
    final holyWeekStart = easter.subtract(const Duration(days: 7));
    if (!base.isBefore(holyWeekStart) && base.isBefore(easter)) {
      return holyWeekStart.subtract(const Duration(days: 1));
    }
    return base;
  }

  DateTime _nextSunday(DateTime from) {
    final delta = (7 - from.weekday) % 7;
    return from.add(Duration(days: delta == 0 ? 7 : delta));
  }

  DateTime _lastSundayBefore(DateTime day) {
    return day.subtract(Duration(days: day.weekday % 7 == 0 ? 7 : day.weekday));
  }

  DateTime _firstOrdinarySunday(DateTime date) {
    final daysUntilSunday = (DateTime.sunday - date.weekday) % 7;
    return date.add(Duration(days: daysUntilSunday));
  }

  DayOfWeek _toDayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return DayOfWeek.monday;
      case DateTime.tuesday:
        return DayOfWeek.tuesday;
      case DateTime.wednesday:
        return DayOfWeek.wednesday;
      case DateTime.thursday:
        return DayOfWeek.thursday;
      case DateTime.friday:
        return DayOfWeek.friday;
      case DateTime.saturday:
        return DayOfWeek.saturday;
      case DateTime.sunday:
      default:
        return DayOfWeek.sunday;
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

  _Celebration _solemnity(String title, LiturgicalColor color) =>
      _Celebration(title: title, rank: 'Solemnity', color: color);

  _Celebration _feast(String title, LiturgicalColor color) =>
      _Celebration(title: title, rank: 'Feast', color: color);

  _Celebration _memorial(String title, LiturgicalColor color) =>
      _Celebration(title: title, rank: 'Memorial', color: color);

  _Celebration _sunday(String title, LiturgicalColor color) =>
      _Celebration(title: title, rank: 'Sunday', color: color);

  _Celebration _day(String title, LiturgicalColor color, String rank) =>
      _Celebration(title: title, rank: rank, color: color);
}

class _Celebration {
  final String title;
  final String rank;
  final LiturgicalColor color;

  const _Celebration({
    required this.title,
    required this.rank,
    required this.color,
  });
}

class _SeasonData {
  final LiturgicalSeason season;
  final int weekNumber;

  const _SeasonData(this.season, this.weekNumber);
}
