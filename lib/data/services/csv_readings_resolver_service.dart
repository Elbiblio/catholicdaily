import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/daily_reading.dart';
import 'base_service.dart';
import 'improved_liturgical_calendar_service.dart';
import 'ordo_resolver_service.dart';
import 'reading_catalog_service.dart';

class CsvReadingsResolverService extends BaseService<CsvReadingsResolverService> {
  static CsvReadingsResolverService get instance =>
      BaseService.init(() => CsvReadingsResolverService._());

  CsvReadingsResolverService._();

  final ReadingCatalogService _catalog = ReadingCatalogService.instance;
  final ImprovedLiturgicalCalendarService _calendar =
      ImprovedLiturgicalCalendarService.instance;
  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;
  Map<int, List<_LegacyReadingRow>>? _legacyRowsByDate;

  Future<List<DailyReading>> resolve(DateTime date) async {
    final normalizedDate = _normalizeDate(date);
    final liturgicalDay = _calendar.getLiturgicalDay(normalizedDate);
    final resolvedDay = await _ordoResolver.resolveDay(normalizedDate);
    final yearVariables = await _ordoResolver.resolveYearVariables(normalizedDate);

    final authoritativeOverride = _buildAuthoritativeCelebrationOverride(
      date: normalizedDate,
      celebrationTitle: resolvedDay.title,
      sundayCycle: yearVariables.sundayCycle,
    );
    if (authoritativeOverride != null) {
      return authoritativeOverride;
    }

    if (_isEasterVigil(normalizedDate)) {
      final standardEntries = await _catalog.loadStandardEntries();
      final vigilReadings = _buildEasterVigilReadings(
        normalizedDate,
        standardEntries,
        yearVariables.sundayCycle,
      );
      if (vigilReadings.isNotEmpty) {
        return vigilReadings;
      }

      final legacyFallback = await _resolveLegacyFallback(normalizedDate);
      if (legacyFallback.isNotEmpty) {
        return legacyFallback;
      }

      return const [];
    }

    final memorialEntries = await _catalog.loadMemorialEntries();
    final celebrationEntry = _findCelebrationEntry(
      memorialEntries: memorialEntries,
      date: normalizedDate,
      celebrationTitle: resolvedDay.title,
    );
    if (celebrationEntry != null &&
        (celebrationEntry.firstReading.isNotEmpty ||
            celebrationEntry.gospel.isNotEmpty)) {
      return _buildCelebrationReadings(normalizedDate, celebrationEntry);
    }

    final standardEntries = await _catalog.loadStandardEntries();
    final matches = standardEntries.where((entry) {
      return _matchesStandardEntry(
        entry: entry,
        date: normalizedDate,
        liturgicalDay: liturgicalDay,
        sundayCycle: yearVariables.sundayCycle,
        weekdayCycle: yearVariables.weekdayCycle,
      );
    }).toList();

    if (matches.isEmpty) {
      final legacyFallback = await _resolveLegacyFallback(normalizedDate);
      if (legacyFallback.isNotEmpty) {
        return legacyFallback;
      }
      return const [];
    }

    final standardReadings = _buildStandardReadings(normalizedDate, matches);
    if (_shouldPreferLegacyFallback(standardReadings)) {
      final legacyFallback = await _resolveLegacyFallback(normalizedDate);
      if (legacyFallback.isNotEmpty) {
        return legacyFallback;
      }
    }

    return standardReadings;
  }

  Future<List<DailyReading>> _resolveLegacyFallback(DateTime date) async {
    final byDate = await _loadLegacyRowsByDate();
    final normalizedDate = _normalizeDate(date);
    final key = _legacyDateKey(normalizedDate);
    final rows = byDate[key];
    if (rows == null || rows.isEmpty) {
      return const [];
    }

    final sorted = [...rows]..sort((a, b) => a.position.compareTo(b.position));
    final readings = <DailyReading>[];
    var numberedReadingIndex = 0;
    var hasMainGospel = false;
    final hasNonPsalmNonGospel =
        sorted.any((r) => !_isLegacyPsalmReference(r.reading) && !_isLegacyGospelReference(r.reading));

    for (var i = 0; i < sorted.length; i++) {
      final row = sorted[i];
      final normalizedReading = _normalizeReferenceStyle(row.reading);
      final isPotentialPsalm = _isLegacyPsalmReference(normalizedReading);
      final isPotentialGospel = _isLegacyGospelReference(normalizedReading);
      final isPsalm = isPotentialPsalm && (!isPotentialGospel || row.position <= 2);
      final isGospel = isPotentialGospel && (!isPotentialPsalm || row.position >= 3);

      if (isPsalm) {
        readings.add(DailyReading(
          reading: normalizedReading,
          position: 'Responsorial Psalm',
          date: normalizedDate,
          psalmResponse: row.psalmResponse?.trim().isEmpty == true ? null : row.psalmResponse,
        ));
        continue;
      }

      if (isGospel) {
        final isProcessionGospel =
            i == 0 && hasNonPsalmNonGospel && row.position == 1;
        String position;
        if (isProcessionGospel) {
          position = 'Gospel at Procession';
        } else if (!hasMainGospel) {
          position = 'Gospel';
          hasMainGospel = true;
        } else {
          position = 'Gospel (alternative)';
        }

        readings.add(DailyReading(
          reading: normalizedReading,
          position: position,
          date: normalizedDate,
          gospelAcclamation:
              row.gospelAcclamation?.trim().isEmpty == true ? null : row.gospelAcclamation,
        ));
        continue;
      }

      numberedReadingIndex += 1;
      readings.add(DailyReading(
        reading: normalizedReading,
        position: _readingPosition(numberedReadingIndex),
        date: normalizedDate,
      ));
    }

    return readings;
  }

  Future<Map<int, List<_LegacyReadingRow>>> _loadLegacyRowsByDate() async {
    if (_legacyRowsByDate != null) {
      return _legacyRowsByDate!;
    }

    String raw;
    try {
      raw = await rootBundle.loadString('assets/data/readings_rows.json');
    } catch (_) {
      _legacyRowsByDate = <int, List<_LegacyReadingRow>>{};
      return _legacyRowsByDate!;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      _legacyRowsByDate = <int, List<_LegacyReadingRow>>{};
      return _legacyRowsByDate!;
    }

    final grouped = <int, List<_LegacyReadingRow>>{};
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final map = item.map((k, v) => MapEntry('$k', v));
      final timestampRaw = map['timestamp'];
      final readingRaw = map['reading'];
      if (timestampRaw == null || readingRaw == null) {
        continue;
      }

      final timestamp = int.tryParse('$timestampRaw');
      final position = int.tryParse('${map['position'] ?? ''}');
      final reading = '$readingRaw'.trim();
      if (timestamp == null || position == null || reading.isEmpty) {
        continue;
      }

      final millis = timestamp > 9999999999 ? timestamp : timestamp * 1000;
      final date = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      final localDate = date.toLocal();
      final dateKey = _legacyDateKey(DateTime(localDate.year, localDate.month, localDate.day));

      final row = _LegacyReadingRow(
        position: position,
        reading: reading,
        psalmResponse: map['psalm_response']?.toString(),
        gospelAcclamation: map['gospel_acclamation']?.toString(),
      );
      grouped.putIfAbsent(dateKey, () => <_LegacyReadingRow>[]).add(row);
    }

    _legacyRowsByDate = grouped;
    return grouped;
  }

  int _legacyDateKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isLegacyPsalmReference(String reference) {
    final lower = reference.trim().toLowerCase();
    return lower.startsWith('ps ') || lower.startsWith('psalm ') ||
        lower.startsWith('isa 12:') ||
        lower.startsWith('exod 15:') ||
        lower.startsWith('1 sam 2:') ||
        lower.startsWith('luke 1:');
  }

  bool _isLegacyGospelReference(String reference) {
    final lower = reference.trim().toLowerCase();
    return lower.startsWith('matt ') ||
        lower.startsWith('mark ') ||
        lower.startsWith('luke ') ||
        lower.startsWith('john ');
  }

  bool _shouldPreferLegacyFallback(List<DailyReading> readings) {
    if (readings.isEmpty) {
      return true;
    }

    final hasGospel = readings.any(
      (reading) => (reading.position ?? '').toLowerCase().contains('gospel'),
    );
    final hasNonPsalmReading = readings.any(
      (reading) => !(reading.position ?? '').toLowerCase().contains('psalm'),
    );

    return !hasGospel || !hasNonPsalmReading;
  }

  MemorialFeastEntry? _findCelebrationEntry({
    required List<MemorialFeastEntry> memorialEntries,
    required DateTime date,
    required String celebrationTitle,
  }) {
    final normalizedTitle = _normalizeTitle(celebrationTitle);

    for (final entry in memorialEntries) {
      if (_normalizeTitle(entry.title) == normalizedTitle) {
        return entry;
      }
    }

    if (_isCalculatedCelebrationDate(date) || date.weekday == DateTime.sunday) {
      return null;
    }

    for (final entry in memorialEntries) {
      if (entry.month.isEmpty || entry.day.isEmpty) {
        continue;
      }
      if (int.tryParse(entry.month) == date.month &&
          int.tryParse(entry.day) == date.day) {
        return entry;
      }
    }

    return null;
  }

  bool _matchesStandardEntry({
    required StandardLectionaryEntry entry,
    required DateTime date,
    required LiturgicalDay liturgicalDay,
    required String sundayCycle,
    required String weekdayCycle,
  }) {
    final isSunday = date.weekday == DateTime.sunday;
    final season = entry.season.trim().toLowerCase();
    final week = entry.week.trim().toLowerCase();
    final day = entry.day.trim().toLowerCase();
    final liturgicalSeason = liturgicalDay.seasonName.toLowerCase();

    if (entry.sundayCycle.isNotEmpty &&
        entry.sundayCycle != 'A/B/C' &&
        entry.sundayCycle.toUpperCase() != sundayCycle.toUpperCase()) {
      return false;
    }

    if (entry.weekdayCycle.isNotEmpty &&
        entry.weekdayCycle != 'I/II' &&
        entry.weekdayCycle.toUpperCase() != weekdayCycle.toUpperCase()) {
      return false;
    }

    if (_monthDayLabel(date).toLowerCase() == day) {
      if (season == 'advent' && _isDecember17To24(date)) {
        return week == 'dec 17-24';
      }
      if (season == 'christmas' && _isChristmasOctave(date)) {
        return week == 'octave';
      }
      return true;
    }

    if (_isHolyThursday(date)) {
      return season == 'holy week' && day == 'holy thursday';
    }
    if (_isGoodFriday(date)) {
      return season == 'holy week' && day == 'good friday';
    }
    if (_isPalmSunday(date)) {
      return season == 'holy week' && day == 'palm sunday';
    }
    if (_isEasterVigil(date)) {
      return season == 'easter' && week == 'vigil';
    }
    if (_isEasterOctave(date)) {
      return season == 'easter' && week == 'octave';
    }
    if (_isAshWednesday(date)) {
      return season == 'lent' && week == 'after ash wed' && day == 'ash wednesday';
    }
    if (_isAfterAshWednesdayToSaturday(date)) {
      return season == 'lent' && week == 'after ash wed' && day == liturgicalDay.dayName.toLowerCase();
    }

    if (isSunday) {
      if (day != 'sunday') {
        return false;
      }
      if (season != liturgicalSeason) {
        return false;
      }
      if (week.isEmpty) {
        return true;
      }
      return week == liturgicalDay.weekNumber.toString();
    }

    if (day != liturgicalDay.dayName.toLowerCase()) {
      return false;
    }
    if (_isDecember17To24(date)) {
      return season == 'advent' && week == 'dec 17-24';
    }
    if (_isChristmasOctave(date)) {
      return season == 'christmas' && week == 'octave';
    }
    if (season == 'holy week') {
      return false;
    }
    if (season != liturgicalSeason) {
      return false;
    }
    if (week.isEmpty) {
      return true;
    }
    return week == liturgicalDay.weekNumber.toString();
  }

  List<DailyReading> _buildCelebrationReadings(
    DateTime date,
    MemorialFeastEntry entry,
  ) {
    final readings = <DailyReading>[];
    if (entry.firstReading.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(entry.firstReading),
        position: 'First Reading',
        date: date,
        feast: entry.title,
        incipit:
            entry.firstReadingIncipit.isEmpty ? null : entry.firstReadingIncipit,
      ));
    }
    if (entry.alternativeFirstReading.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(entry.alternativeFirstReading),
        position: 'First Reading (alternative)',
        date: date,
        feast: entry.title,
        incipit: entry.alternativeFirstReadingIncipit.isEmpty
            ? null
            : entry.alternativeFirstReadingIncipit,
      ));
    }
    if (entry.psalmReference.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(entry.psalmReference),
        position: 'Responsorial Psalm',
        date: date,
        feast: entry.title,
        psalmResponse:
            entry.psalmResponse.isEmpty ? null : entry.psalmResponse,
      ));
    }
    if (entry.secondReading.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(entry.secondReading),
        position: 'Second Reading',
        date: date,
        feast: entry.title,
        incipit:
            entry.secondReadingIncipit.isEmpty ? null : entry.secondReadingIncipit,
      ));
    }
    if (entry.gospel.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(entry.gospel),
        position: 'Gospel',
        date: date,
        feast: entry.title,
        gospelAcclamation: entry.gospelAcclamation.isEmpty
            ? null
            : entry.gospelAcclamation,
        incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
      ));
    }
    if (entry.alternativeGospel.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(entry.alternativeGospel),
        position: 'Gospel (alternative)',
        date: date,
        feast: entry.title,
        gospelAcclamation: entry.gospelAcclamation.isEmpty
            ? null
            : entry.gospelAcclamation,
        incipit: entry.alternativeGospelIncipit.isEmpty
            ? null
            : entry.alternativeGospelIncipit,
      ));
    }
    return readings;
  }

  List<DailyReading> _buildEasterVigilReadings(
    DateTime date,
    List<StandardLectionaryEntry> entries,
    String sundayCycle,
  ) {
    final vigilEntries = entries.where((entry) {
      return entry.season == 'Easter' &&
          entry.week == 'Vigil' &&
          entry.day.startsWith('Easter Vigil') &&
          !entry.day.contains('(Alt)') &&
          (entry.sundayCycle.isEmpty ||
              entry.sundayCycle == 'A/B/C' ||
              entry.sundayCycle.toUpperCase() == sundayCycle.toUpperCase());
    }).toList();

    if (vigilEntries.isEmpty) {
      return const [];
    }

    final readings = <DailyReading>[];
    for (final entry in vigilEntries) {
      final isAlleluiaPsalm = entry.day.contains('Alleluia Psalm');
      if (entry.firstReading.isNotEmpty) {
        readings.add(DailyReading(
          reading: _normalizeReferenceStyle(entry.firstReading),
          position: isAlleluiaPsalm ? 'Epistle' : _readingPosition(readings.where((r) => r.position?.contains('Reading') == true).length + 1),
          date: date,
        ));
      }
      if (entry.psalmReference.isNotEmpty) {
        readings.add(DailyReading(
          reading: _normalizeEasterVigilPsalmReference(entry.psalmReference),
          position: isAlleluiaPsalm ? 'Alleluia Psalm' : 'Responsorial Psalm',
          date: date,
          psalmResponse: entry.psalmResponse.isEmpty ? null : entry.psalmResponse,
        ));
      }
    }

    final gospelEntry = vigilEntries.last;
    readings.add(DailyReading(
      reading: _normalizeReferenceStyle(_cycleSpecificGospel(gospelEntry.gospel, sundayCycle)),
      position: 'Gospel',
      date: date,
      gospelAcclamation: gospelEntry.acclamationText.isEmpty ? null : gospelEntry.acclamationText,
      incipit: gospelEntry.gospelIncipit.isEmpty ? null : gospelEntry.gospelIncipit,
    ));
    return readings;
  }

  List<DailyReading>? _buildAuthoritativeCelebrationOverride({
    required DateTime date,
    required String celebrationTitle,
    required String sundayCycle,
  }) {
    final normalizedTitle = _normalizeTitle(celebrationTitle);
    final cycle = sundayCycle.toUpperCase();

    if (normalizedTitle == _normalizeTitle('Palm Sunday of the Passion of the Lord')) {
      final gospel = switch (cycle) {
        'A' => 'Matt 21:1-11',
        'B' => 'Mark 11:1-10',
        'C' => 'Luke 19:28-40',
        _ => 'Matt 21:1-11',
      };
      final gospelAlt = switch (cycle) {
        'A' => 'Matt 26:14-27:66',
        'B' => 'Mark 14:1-15:47',
        'C' => 'Luke 22:14-23:56',
        _ => 'Matt 26:14-27:66',
      };
      return _buildPalmSundayOverrideReadings(
        date: date,
        gospelAtProcession: gospel,
        passionGospel: gospelAlt,
        firstReading: 'Isa 50:4-7',
        psalm: 'Ps 22:8-9, 17-18, 19-20, 23-24',
        psalmResponse: 'My God, my God, why have you abandoned me?',
        secondReading: 'Phil 2:6-11',
        gospelAcclamation: 'Phil 2:8-9',
      );
    }

    if (normalizedTitle == _normalizeTitle('Pentecost Sunday')) {
      final secondReading = switch (cycle) {
        'C' => 'Rom 8:8-17',
        _ => '1 Cor 12:3b-7, 12-13',
      };
      final gospel = switch (cycle) {
        'C' => 'John 14:15-16, 23b-26',
        _ => 'John 20:19-23',
      };
      final gospelAlt = switch (cycle) {
        'A' => 'John 15:26-27; 16:12-15',
        'B' => 'John 15:26-27; 16:12-15',
        _ => null,
      };
      return _buildPentecostOverrideReadings(
        date: date,
        firstReading: 'Acts 2:1-11',
        psalm: 'Ps 104:1, 24, 29-30, 31, 34',
        psalmResponse: 'Lord, send out your Spirit, and renew the face of the earth.',
        secondReading: secondReading,
        sequence: 'Veni Sancte Spiritus (Sequence)',
        gospel: gospel,
        gospelAlternate: gospelAlt,
        gospelAcclamation: 'Come, Holy Spirit, fill the hearts of your faithful and kindle in them the fire of your love.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Most Holy Trinity')) {
      final firstReading = switch (cycle) {
        'A' => 'Exod 34:4b-6, 8-9',
        'B' => 'Dt 4:32-34, 39-40',
        'C' => 'Prov 8:22-31',
        _ => 'Exod 34:4b-6, 8-9',
      };
      final psalm = switch (cycle) {
        'A' => 'Dan 3:52, 53, 54, 55, 56',
        'B' => 'Ps 33:4-5, 6, 9, 18-19, 20, 22',
        'C' => 'Ps 8:4-5, 6-7, 8-9',
        _ => 'Dan 3:52, 53, 54, 55, 56',
      };
      final psalmResponse = switch (cycle) {
        'A' => 'Glory and praise for ever!',
        'B' => 'Happy the people the Lord has chosen to be his own.',
        'C' => 'O Lord, our God, how wonderful your name in all the earth!',
        _ => 'Glory and praise for ever!',
      };
      final secondReading = switch (cycle) {
        'A' => '2 Cor 13:11-13',
        'B' => 'Rom 8:14-17',
        'C' => 'Rom 5:1-5',
        _ => '2 Cor 13:11-13',
      };
      final gospel = switch (cycle) {
        'A' => 'John 3:16-18',
        'B' => 'Matt 28:16-20',
        'C' => 'John 16:12-15',
        _ => 'John 3:16-18',
      };
      return _buildOverrideReadings(
        date: date,
        firstReading: firstReading,
        psalm: psalm,
        psalmResponse: psalmResponse,
        secondReading: secondReading,
        gospel: gospel,
        gospelAcclamation: 'Glory to the Father, the Son, and the Holy Spirit; to God who is, who was, and who is to come.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Most Holy Body and Blood of Christ')) {
      final firstReading = switch (cycle) {
        'A' => 'Deut 8:2-3, 14b-16a',
        'B' => 'Exod 24:3-8',
        'C' => 'Gen 14:18-20',
        _ => 'Deut 8:2-3, 14b-16a',
      };
      final psalm = switch (cycle) {
        'A' => 'Ps 147:12-13, 14-15, 19-20',
        'B' => 'Ps 116:12-13, 15-16, 17-18',
        'C' => 'Ps 110:1, 2, 3, 4',
        _ => 'Ps 147:12-13, 14-15, 19-20',
      };
      final psalmResponse = switch (cycle) {
        'A' => 'Praise the Lord, Jerusalem.',
        'B' => 'I will take the cup of salvation, and call on the name of the Lord.',
        'C' => 'You are a priest for ever, in the line of Melchizedek.',
        _ => 'Praise the Lord, Jerusalem.',
      };
      final secondReading = switch (cycle) {
        'A' => '1 Cor 10:16-17',
        'B' => 'Heb 9:11-15',
        'C' => '1 Cor 11:23-26',
        _ => '1 Cor 10:16-17',
      };
      final gospel = switch (cycle) {
        'A' => 'John 6:51-58',
        'B' => 'Mark 14:12-16, 22-26',
        'C' => 'Luke 9:11b-17',
        _ => 'John 6:51-58',
      };
      return _buildOverrideReadings(
        date: date,
        firstReading: firstReading,
        psalm: psalm,
        psalmResponse: psalmResponse,
        secondReading: secondReading,
        gospel: gospel,
        gospelAcclamation: 'I am the living bread that came down from heaven, says the Lord; whoever eats this bread will live forever.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Most Sacred Heart of Jesus')) {
      final firstReading = switch (cycle) {
        'A' => 'Deut 7:6-11',
        'B' => 'Hos 11:1, 3-4, 8c-9',
        'C' => 'Ezek 34:11-16',
        _ => 'Deut 7:6-11',
      };
      final psalm = switch (cycle) {
        'A' => 'Ps 103:1-2, 3-4, 6-7, 8, 10',
        'B' => 'Isa 12:2-3, 4, 5-6',
        'C' => 'Ps 23:1-3a, 3b-4, 5, 6',
        _ => 'Ps 103:1-2, 3-4, 6-7, 8, 10',
      };
      final psalmResponse = switch (cycle) {
        'A' => "The Lord's kindness is everlasting to those who fear him.",
        'B' => 'You will draw water joyfully from the springs of salvation.',
        'C' => 'The Lord is my shepherd; there is nothing I shall want.',
        _ => "The Lord's kindness is everlasting to those who fear him.",
      };
      final secondReading = switch (cycle) {
        'A' => '1 John 4:7-16',
        'B' => 'Eph 3:8-12, 14-19',
        'C' => 'Rom 5:5b-11',
        _ => '1 John 4:7-16',
      };
      final gospel = switch (cycle) {
        'A' => 'Matt 11:25-30',
        'B' => 'John 19:31-37',
        'C' => 'Luke 15:3-7',
        _ => 'Matt 11:25-30',
      };
      return _buildOverrideReadings(
        date: date,
        firstReading: firstReading,
        psalm: psalm,
        psalmResponse: psalmResponse,
        secondReading: secondReading,
        gospel: gospel,
        gospelAcclamation: 'Take my yoke upon you, says the Lord, and learn from me, for I am meek and humble of heart.',
      );
    }

    if (normalizedTitle == _normalizeTitle('Our Lord Jesus Christ, King of the Universe')) {
      final firstReading = switch (cycle) {
        'A' => 'Ezek 34:11-12, 15-17',
        'B' => 'Dan 7:13-14',
        'C' => '2 Sam 5:1-3',
        _ => 'Ezek 34:11-12, 15-17',
      };
      final psalm = switch (cycle) {
        'A' => 'Ps 23:1-2, 2-3, 5-6',
        'B' => 'Ps 93:1, 1-2, 5',
        'C' => 'Ps 122:1-2, 3-4, 4-5',
        _ => 'Ps 23:1-2, 2-3, 5-6',
      };
      final psalmResponse = switch (cycle) {
        'A' => 'The Lord is my shepherd; there is nothing I shall want.',
        'B' => 'The Lord is king; he is robed in majesty.',
        'C' => 'Let us go rejoicing to the house of the Lord.',
        _ => 'The Lord is my shepherd; there is nothing I shall want.',
      };
      final secondReading = switch (cycle) {
        'A' => '1 Cor 15:20-26, 28',
        'B' => 'Rev 1:5-8',
        'C' => 'Col 1:12-20',
        _ => '1 Cor 15:20-26, 28',
      };
      final gospel = switch (cycle) {
        'A' => 'Matt 25:31-46',
        'B' => 'John 18:33b-37',
        'C' => 'Luke 23:35-43',
        _ => 'Matt 25:31-46',
      };
      return _buildOverrideReadings(
        date: date,
        firstReading: firstReading,
        psalm: psalm,
        psalmResponse: psalmResponse,
        secondReading: secondReading,
        gospel: gospel,
        gospelAcclamation: 'Blessed is he who comes in the name of the Lord! Blessed is the kingdom of our father David that is to come!',
      );
    }

    if (normalizedTitle == _normalizeTitle('Mary, the Holy Mother of God')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Num 6:22-27',
        psalm: 'Ps 67:2-3, 5, 6, 8',
        psalmResponse: 'May God bless us in his mercy.',
        secondReading: 'Gal 4:4-7',
        gospel: 'Luke 2:16-21',
        gospelAcclamation: 'Heb 1:1-2',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Immaculate Conception of the Blessed Virgin Mary')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Gen 3:9-15, 20',
        psalm: 'Ps 98:1, 2-3ab, 3cd-4',
        psalmResponse: 'Sing to the Lord a new song, for he has done marvelous deeds.',
        secondReading: 'Eph 1:3-6, 11-12',
        gospel: 'Luke 1:26-38',
        gospelAcclamation: 'Hail, Mary, full of grace, the Lord is with you; blessed are you among women.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Annunciation of the Lord')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Isa 7:10-14; 8:10',
        psalm: 'Ps 40:7-8a, 8b-9, 10, 11',
        psalmResponse: 'Here I am, Lord; I come to do your will.',
        secondReading: 'Heb 10:4-10',
        gospel: 'Luke 1:26-38',
        gospelAcclamation: 'The Word of God became flesh and dwelt among us, and we saw his glory.',
      );
    }

    if (normalizedTitle == _normalizeTitle('Saint Joseph, Spouse of the Blessed Virgin Mary')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: '2 Sam 7:4-5a, 12-14a, 16',
        psalm: 'Ps 89:2-3, 4-5, 27, 29',
        psalmResponse: 'The son of David will live for ever.',
        secondReading: 'Rom 4:13, 16-18, 22',
        gospel: 'Matt 1:16, 18-21, 24a',
        gospelAlternate: 'Luke 2:41-51a',
        gospelAcclamation: 'Ps 84:5',
      );
    }

    return null;
  }

  List<DailyReading> _buildPentecostOverrideReadings({
    required DateTime date,
    required String firstReading,
    required String psalm,
    required String psalmResponse,
    String? secondReading,
    required String sequence,
    required String gospel,
    String? gospelAlternate,
    String? gospelAcclamation,
  }) {
    final readings = <DailyReading>[
      DailyReading(
        reading: _normalizeReferenceStyle(firstReading),
        position: 'First Reading',
        date: date,
      ),
      DailyReading(
        reading: _normalizeReferenceStyle(psalm),
        position: 'Responsorial Psalm',
        date: date,
        psalmResponse: psalmResponse,
      ),
    ];

    if (secondReading != null && secondReading.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(secondReading),
        position: 'Second Reading',
        date: date,
      ));
    }

    // Add the Sequence for Pentecost
    readings.add(DailyReading(
      reading: sequence,
      position: 'Sequence',
      date: date,
    ));

    readings.add(DailyReading(
      reading: _normalizeReferenceStyle(gospel),
      position: 'Gospel',
      date: date,
      gospelAcclamation: gospelAcclamation,
    ));

    if (gospelAlternate != null && gospelAlternate.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(gospelAlternate),
        position: 'Gospel (alternative)',
        date: date,
        gospelAcclamation: gospelAcclamation,
      ));
    }

    return readings;
  }

  List<DailyReading> _buildPalmSundayOverrideReadings({
    required DateTime date,
    required String gospelAtProcession,
    required String passionGospel,
    required String firstReading,
    required String psalm,
    required String psalmResponse,
    required String secondReading,
    String? gospelAcclamation,
  }) {
    return <DailyReading>[
      DailyReading(
        reading: _normalizeReferenceStyle(gospelAtProcession),
        position: 'Gospel at Procession',
        date: date,
      ),
      DailyReading(
        reading: _normalizeReferenceStyle(firstReading),
        position: 'First Reading',
        date: date,
      ),
      DailyReading(
        reading: _normalizeReferenceStyle(psalm),
        position: 'Responsorial Psalm',
        date: date,
        psalmResponse: psalmResponse,
      ),
      DailyReading(
        reading: _normalizeReferenceStyle(secondReading),
        position: 'Second Reading',
        date: date,
      ),
      DailyReading(
        reading: _normalizeReferenceStyle(passionGospel),
        position: 'Gospel',
        date: date,
        gospelAcclamation: gospelAcclamation,
      ),
    ];
  }

  List<DailyReading> _buildOverrideReadings({
    required DateTime date,
    required String firstReading,
    required String psalm,
    required String psalmResponse,
    String? secondReading,
    required String gospel,
    String? gospelAlternate,
    String? gospelAcclamation,
  }) {
    final readings = <DailyReading>[
      DailyReading(
        reading: _normalizeReferenceStyle(firstReading),
        position: 'First Reading',
        date: date,
      ),
      DailyReading(
        reading: _normalizeReferenceStyle(psalm),
        position: 'Responsorial Psalm',
        date: date,
        psalmResponse: psalmResponse,
      ),
    ];

    if (secondReading != null && secondReading.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(secondReading),
        position: 'Second Reading',
        date: date,
      ));
    }

    readings.add(DailyReading(
      reading: _normalizeReferenceStyle(gospel),
      position: 'Gospel',
      date: date,
      gospelAcclamation: gospelAcclamation,
    ));

    if (gospelAlternate != null && gospelAlternate.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(gospelAlternate),
        position: 'Gospel (alternative)',
        date: date,
        gospelAcclamation: gospelAcclamation,
      ));
    }

    return readings;
  }

  List<DailyReading> _buildStandardReadings(
    DateTime date,
    List<StandardLectionaryEntry> entries,
  ) {
    // When multiple CSV rows match the same day (alternate psalm options),
    // deduplicate so we only emit one reading per position slot.
    final readings = <DailyReading>[];
    var firstReadingCount = 0;
    var firstReadingAlternativeCount = 0;
    var secondReadingAlternativeCount = 0;
    var gospelAlternativeCount = 0;
    var hasPsalm = false;
    var hasSecondReading = false;
    var hasGospel = false;

    for (final entry in entries) {
      if (entry.firstReading.isNotEmpty) {
        final normalized = _normalizeReferenceStyle(entry.firstReading);
        final firstReadingExists = readings.any((r) => r.position == 'First Reading');
        final hasSameFirstReading = readings.any(
          (r) => r.reading == normalized &&
              (r.position == 'First Reading' || r.position?.startsWith('First Reading (alternative') == true),
        );

        if (!firstReadingExists) {
          firstReadingCount += 1;
          readings.add(DailyReading(
            reading: normalized,
            position: _readingPosition(firstReadingCount),
            date: date,
            psalmResponse: null,
            gospelAcclamation: null,
            incipit:
                entry.firstReadingIncipit.isEmpty ? null : entry.firstReadingIncipit,
          ));
        } else if (!hasSameFirstReading) {
          firstReadingAlternativeCount += 1;
          final suffix = firstReadingAlternativeCount == 1 ? '' : ' ${firstReadingAlternativeCount + 1}';
          readings.add(DailyReading(
            reading: normalized,
            position: 'First Reading (alternative$suffix)',
            date: date,
            psalmResponse: null,
            gospelAcclamation: null,
            incipit:
                entry.firstReadingIncipit.isEmpty ? null : entry.firstReadingIncipit,
          ));
        }
      }
      if (entry.psalmReference.isNotEmpty && !hasPsalm) {
        hasPsalm = true;
        readings.add(DailyReading(
          reading: _normalizeReferenceStyle(entry.psalmReference),
          position: 'Responsorial Psalm',
          date: date,
          psalmResponse:
              entry.psalmResponse.isEmpty ? null : entry.psalmResponse,
        ));
      }
      if (entry.secondReading.isNotEmpty) {
        final normalizedSecondReading = _normalizeReferenceStyle(entry.secondReading);
        if (!hasSecondReading) {
          hasSecondReading = true;
          readings.add(DailyReading(
            reading: normalizedSecondReading,
            position: firstReadingCount <= 1 ? 'Second Reading' : 'Epistle',
            date: date,
          ));
        } else {
          final hasSameSecondReading = readings.any(
            (r) => r.reading == normalizedSecondReading &&
                (r.position == 'Second Reading' ||
                    r.position?.startsWith('Second Reading (alternative') == true ||
                    r.position == 'Epistle' ||
                    r.position?.startsWith('Epistle (alternative') == true),
          );
          if (!hasSameSecondReading) {
            secondReadingAlternativeCount += 1;
            final suffix = secondReadingAlternativeCount == 1
                ? ''
                : ' ${secondReadingAlternativeCount + 1}';
            final basePosition = firstReadingCount <= 1 ? 'Second Reading' : 'Epistle';
            readings.add(DailyReading(
              reading: normalizedSecondReading,
              position: '$basePosition (alternative$suffix)',
              date: date,
            ));
          }
        }
      }
      if (entry.gospel.isNotEmpty) {
        // Some standard lectionary rows encode an alternative Gospel in a single field using " or ".
        // Example: "John 4:5-42 or 4:5-15, 19b-26, 39a, 40-42".
        // Emit the first as 'Gospel' and the second as 'Gospel (alternative)'.
        final rawGospel = entry.gospel.trim();
        if (rawGospel.contains(' or ')) {
          final parts = rawGospel.split(' or ');
          final firstPart = parts[0].trim();
          var secondPart = parts.sublist(1).join(' or ').trim(); // In case of nested 'or', join remainder

          // Normalize first part normally
          final normalizedFirst = _normalizeReferenceStyle(firstPart);

          // If second part omits the book, propagate it from the first part
          final bookMatch = RegExp(r'^[A-Za-z\s\d]+').firstMatch(normalizedFirst);
          final firstBook = bookMatch != null
              ? normalizedFirst.substring(0, normalizedFirst.indexOf(' ')).trim()
              : '';
          if (!RegExp(r'^[A-Za-z]').hasMatch(secondPart)) {
            if (firstBook.isNotEmpty) {
              secondPart = '$firstBook $secondPart';
            }
          }
          final normalizedSecond = _normalizeReferenceStyle(secondPart);

          if (!hasGospel) {
            hasGospel = true;
            readings.add(DailyReading(
              reading: normalizedFirst,
              position: 'Gospel',
              date: date,
              gospelAcclamation:
                  entry.acclamationText.isEmpty ? null : entry.acclamationText,
              incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
            ));
            // Always add the alternative when present
            readings.add(DailyReading(
              reading: normalizedSecond,
              position: 'Gospel (alternative)',
              date: date,
              gospelAcclamation:
                  entry.acclamationText.isEmpty ? null : entry.acclamationText,
              // Use the same incipit if a single incipit is provided in the CSV for the combined row
              incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
            ));
          } else {
            // If a primary Gospel already exists from another row, append both parts as alternatives if unique
            final existsPrimary = readings.any(
              (r) => r.reading == normalizedFirst &&
                  (r.position == 'Gospel' || r.position?.startsWith('Gospel (alternative') == true),
            );
            if (!existsPrimary) {
              gospelAlternativeCount += 1;
              final suffix = gospelAlternativeCount == 1 ? '' : ' ${gospelAlternativeCount + 1}';
              readings.add(DailyReading(
                reading: normalizedFirst,
                position: 'Gospel (alternative$suffix)',
                date: date,
                gospelAcclamation:
                    entry.acclamationText.isEmpty ? null : entry.acclamationText,
                incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
              ));
            }
            final existsAlt = readings.any(
              (r) => r.reading == normalizedSecond &&
                  (r.position == 'Gospel' || r.position?.startsWith('Gospel (alternative') == true),
            );
            if (!existsAlt) {
              gospelAlternativeCount += 1;
              final suffix = gospelAlternativeCount == 1 ? '' : ' ${gospelAlternativeCount + 1}';
              readings.add(DailyReading(
                reading: normalizedSecond,
                position: 'Gospel (alternative$suffix)',
                date: date,
                gospelAcclamation:
                    entry.acclamationText.isEmpty ? null : entry.acclamationText,
                incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
              ));
            }
          }
        } else {
          final normalizedGospel = _normalizeReferenceStyle(rawGospel);
          if (!hasGospel) {
            hasGospel = true;
            readings.add(DailyReading(
              reading: normalizedGospel,
              position: 'Gospel',
              date: date,
              gospelAcclamation:
                  entry.acclamationText.isEmpty ? null : entry.acclamationText,
              incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
            ));
          } else {
            final hasSameGospel = readings.any(
              (r) => r.reading == normalizedGospel &&
                  (r.position == 'Gospel' || r.position?.startsWith('Gospel (alternative') == true),
            );
            if (!hasSameGospel) {
              gospelAlternativeCount += 1;
              final suffix = gospelAlternativeCount == 1 ? '' : ' ${gospelAlternativeCount + 1}';
              readings.add(DailyReading(
                reading: normalizedGospel,
                position: 'Gospel (alternative$suffix)',
                date: date,
                gospelAcclamation:
                    entry.acclamationText.isEmpty ? null : entry.acclamationText,
                incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
              ));
            }
          }
        }
      }
    }

    return readings;
  }

  String _readingPosition(int index) {
    switch (index) {
      case 1:
        return 'First Reading';
      case 2:
        return 'Second Reading';
      case 3:
        return 'Third Reading';
      case 4:
        return 'Fourth Reading';
      case 5:
        return 'Fifth Reading';
      case 6:
        return 'Sixth Reading';
      case 7:
        return 'Seventh Reading';
      default:
        return 'Reading $index';
    }
  }

  String _normalizeTitle(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(',', '')
        .replaceAll(RegExp(r'\bblessed virgin mary\b'), 'virgin mary')
        .replaceAll(RegExp(r'\bspouse of the virgin mary\b'), 'husband of mary')
        .replaceAll(RegExp(r'\bspouse of the blessed virgin mary\b'), 'husband of mary')
        .replaceAll(RegExp(r'\bhusband of the blessed virgin mary\b'), 'husband of mary')
        .replaceAll(RegExp(r'[“”]'), '"')
        .trim();
  }

  String _normalizeReferenceStyle(String value) {
    var result = value.trim();
    if (result.isEmpty) {
      return result;
    }
    // Remove malformed shorter-form prefixes such as:
    // "(s h o r te r ) John 9.1..." and "(shorter) John ..."
    result = result.replaceFirst(
      RegExp(r'^\(\s*s\s*h\s*o\s*r\s*t?\s*e\s*r\s*\)\s*', caseSensitive: false),
      '',
    );
    result = result.replaceFirst(
      RegExp(r'^\(\s*shorter\s*\)\s*', caseSensitive: false),
      '',
    );
    final cycleRef = RegExp(r'^(.*?)\s*\(([ABC])\);\s*(.*)$').firstMatch(result);
    if (cycleRef != null) {
      result = cycleRef.group(1)!.trim();
    }
    result = result
        .replaceAll('2 Samuel', '2 Sam')
        .replaceAll('1 Samuel', '1 Sam')
        .replaceAll('Isaiah', 'Isa')
        .replaceAll('Jeremiah', 'Jer')
        .replaceAll('Zephaniah', 'Zeph')
        .replaceAll('Malachi', 'Mal')
        .replaceAll('Genesis', 'Gen')
        .replaceAll('Exodus', 'Exod')
        .replaceAll('Matthew', 'Matt')
        .replaceAll('Luke', 'Luke')
        .replaceAll('Mark', 'Mark')
        .replaceAll('John', 'John')
        .replaceAll('Romans', 'Rom')
        .replaceAll('Baruch', 'Bar')
        .replaceAll('Psalm', 'Ps');
    // Convert period notation to colon for the chapter.verse separator only.
    // Anchored to the start so mid-string periods like "and 12.13" are not touched.
    // Handles both "Psalm 72.1-2" and "Psalm 1. 1-2" (space after period).
    result = result.replaceFirstMapped(
      RegExp(r'^([A-Za-z0-9 ]+\s\d+)\.\s*(\d)'),
      (match) => '${match.group(1)}:${match.group(2)}',
    );
    result = result.replaceFirst(RegExp(r'\s+or\s+.+$', caseSensitive: false), '');
    result = result.replaceFirst(RegExp(r'\s*\(R\.[^)]+\)$', caseSensitive: false), '');
    return result;
  }

  String _normalizeEasterVigilPsalmReference(String value) {
    const vigilPsalmMap = <String, String>{
      'Psalm 104:1-2a.5-6.10 and 12.13-14.24 and 35c (R. cf. 30)': 'Ps 104:1-35',
      'Psalm 33:4-5.6-7.12-13.20 and 22 (R. 5b)': 'Ps 33:4-22',
      'Psalm 16:5 and 8.9-10.11 (R. 1)': 'Ps 16:5-11',
      'Exodus 15:1b-2.3-4.5-6.17-18 (R. 1b)': 'Exod 15:1-18',
      'Psalm 30:2 and 4.5-6.11-12a and 13b (R. 2a)': 'Ps 30:2-13',
      'Isaiah 12:2-6 (R. 3)': 'Isa 12:2-6',
      'Psalm 19:8.9.10.11 (R. John 6:68c)': 'Ps 19:8-11',
      'Psalm 42:3.5; 43:3-4 (R. 42:2)': 'Ps 42:3-5; 43:3-4',
      'Psalm 118:1-2.15c-17.22-23': 'Ps 118:1-23',
    };
    final trimmed = value.trim();
    return vigilPsalmMap[trimmed] ?? _normalizeReferenceStyle(value);
  }

  String _cycleSpecificGospel(String value, String sundayCycle) {
    final match = RegExp(r'^(.*?)\(A\);\s*(.*?)\(B\);\s*(.*?)\(C\)$').firstMatch(value);
    if (match == null) {
      return value;
    }
    switch (sundayCycle.toUpperCase()) {
      case 'A':
        return match.group(1)!.trim();
      case 'B':
        return match.group(2)!.trim();
      case 'C':
        return match.group(3)!.trim();
      default:
        return match.group(3)!.trim();
    }
  }

  String _monthDayLabel(DateTime date) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month]} ${date.day}';
  }

  bool _isDecember17To24(DateTime date) {
    return date.month == 12 && date.day >= 17 && date.day <= 24;
  }

  bool _isChristmasOctave(DateTime date) {
    if (date.month == 12 && date.day >= 26) {
      return true;
    }
    return date.month == 1 && date.day == 1;
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

  bool _isPalmSunday(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    final palmSunday = easter.subtract(const Duration(days: 7));
    return _isSameDate(date, palmSunday);
  }

  bool _isHolyThursday(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    return _isSameDate(date, easter.subtract(const Duration(days: 3)));
  }

  bool _isGoodFriday(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    return _isSameDate(date, easter.subtract(const Duration(days: 2)));
  }

  bool _isEasterVigil(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    return _isSameDate(date, easter.subtract(const Duration(days: 1)));
  }

  bool _isEasterOctave(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    final octaveEnd = easter.add(const Duration(days: 7));
    return !date.isBefore(DateTime(easter.year, easter.month, easter.day + 1)) &&
        !date.isAfter(octaveEnd);
  }

  bool _isAshWednesday(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    return _isSameDate(date, easter.subtract(const Duration(days: 46)));
  }

  bool _isAfterAshWednesdayToSaturday(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    final ashWednesday = easter.subtract(const Duration(days: 46));
    final firstLentSunday = ashWednesday.add(const Duration(days: 4));
    return date.isAfter(ashWednesday) && date.isBefore(firstLentSunday);
  }

  bool _isCalculatedCelebrationDate(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
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
    final adventStart = _calculateAdventStart(date.year);
    final christTheKing = adventStart.subtract(const Duration(days: 7));
    final holyFamily = _calculateHolyFamily(date.year);

    return _isSameDate(date, ashWednesday) ||
        _isSameDate(date, palmSunday) ||
        _isSameDate(date, holyThursday) ||
        _isSameDate(date, goodFriday) ||
        _isSameDate(date, holySaturday) ||
        _isSameDate(date, easter) ||
        _isSameDate(date, pentecost) ||
        _isSameDate(date, trinitySunday) ||
        _isSameDate(date, corpusChristi) ||
        _isSameDate(date, sacredHeart) ||
        _isSameDate(date, immaculateHeart) ||
        _isSameDate(date, christTheKing) ||
        _isSameDate(date, holyFamily);
  }

  DateTime _calculateHolyFamily(int year) {
    for (var day = 26; day <= 31; day++) {
      final candidate = DateTime(year, 12, day);
      if (candidate.weekday == DateTime.sunday) {
        return candidate;
      }
    }
    return DateTime(year, 12, 30);
  }

  DateTime _calculateAdventStart(int year) {
    final christmas = DateTime(year, 12, 25);
    final daysUntilSunday = (DateTime.sunday - christmas.weekday + 7) % 7;
    final sundayOnOrAfterChristmas = christmas.add(Duration(days: daysUntilSunday));
    return sundayOnOrAfterChristmas.subtract(const Duration(days: 28));
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _LegacyReadingRow {
  final int position;
  final String reading;
  final String? psalmResponse;
  final String? gospelAcclamation;

  const _LegacyReadingRow({
    required this.position,
    required this.reading,
    this.psalmResponse,
    this.gospelAcclamation,
  });
}
