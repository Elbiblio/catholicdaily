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
      return _buildAuthoritativeEasterVigilReadings(
        normalizedDate,
        yearVariables.sundayCycle,
      );
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
    var hasMainGospel = false;
    var hasFirstReading = false;
    var hasSecondReading = false;
    final hasNonPsalmNonGospel =
        sorted.any((r) => !_isLegacyPsalmReference(r.reading) && !_isLegacyGospelReference(r.reading));

    for (var i = 0; i < sorted.length; i++) {
      final row = sorted[i];
      final normalizedReading = _normalizeReferenceStyle(row.reading);
      final isPotentialPsalm = _isLegacyPsalmReference(normalizedReading);
      final isPotentialGospel = _isLegacyGospelReference(normalizedReading);
      final isPsalm = isPotentialPsalm && (!isPotentialGospel || row.position <= 2);
      final isGospel = isPotentialGospel && (!isPotentialPsalm || row.position >= 3);

      // Skip gospel acclamations that are being treated as separate reading items
      // Gospel acclamations should be attached to the gospel reading, not be separate items
      if (row.gospelAcclamation != null && 
          row.gospelAcclamation!.trim().isNotEmpty && 
          !isGospel) {
        continue;
      }

      if (isPsalm) {
        final response = row.psalmResponse?.trim().isEmpty == true ? null : row.psalmResponse;
        final alreadyHasPsalm = readings.any((r) => r.position == 'Responsorial Psalm');
        if (response == null || alreadyHasPsalm) {
          // Psalm-like ref with no response is a Gospel Acclamation verse (e.g. Easter Alleluia Ps 118:24).
          // A second psalm-like ref after the real Responsorial Psalm is also an Acclamation.
          readings.add(DailyReading(
            reading: normalizedReading,
            position: 'Gospel Acclamation',
            date: normalizedDate,
            gospelAcclamation: normalizedReading,
          ));
        } else {
          readings.add(DailyReading(
            reading: normalizedReading,
            position: 'Responsorial Psalm',
            date: normalizedDate,
            psalmResponse: response,
          ));
        }
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

      String position;
      
      // Determine if this is a first or second reading based on position
      // Legacy data uses position numbers: 1 = first reading, 2 = psalm, 3 = second reading, 4 = gospel
      // But we need to handle alternatives correctly
      if (!hasFirstReading) {
        position = 'First Reading';
        hasFirstReading = true;
      } else if (!hasSecondReading) {
        position = 'Second Reading';
        hasSecondReading = true;
      } else {
        // This is an alternative reading - determine if it's first or second reading alternative
        // by checking if we've seen a second reading yet
        position = hasSecondReading ? 'Second Reading (alternative)' : 'First Reading (alternative)';
      }
      
      readings.add(DailyReading(
        reading: normalizedReading,
        position: position,
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

    // Check if we have any actual readings (not just psalm or acclamation)
    final hasFirstReading = readings.any(
      (reading) => (reading.position ?? '').toLowerCase().contains('first reading'),
    );
    final hasGospel = readings.any(
      (reading) => (reading.position ?? '').toLowerCase().contains('gospel'),
    );

    // Prefer legacy fallback only if we have no readings at all
    // Weekdays typically don't have gospel readings, so we shouldn't require gospel
    return !hasFirstReading && !hasGospel;
  }

  MemorialFeastEntry? _findCelebrationEntry({
    required List<MemorialFeastEntry> memorialEntries,
    required DateTime date,
    required String celebrationTitle,
  }) {
    final normalizedTitle = _normalizeTitle(celebrationTitle);

    for (final entry in memorialEntries) {
      if (_normalizeTitle(entry.title) == normalizedTitle) {
        if (_isMemorialEntryWellFormed(entry)) return entry;
        return null;
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
        if (_isMemorialEntryWellFormed(entry)) return entry;
        return null;
      }
    }

    return null;
  }

  /// Returns false when a memorial entry has obvious field-shift corruption
  /// (e.g. psalmReference contains a sentence instead of a Psalm reference,
  /// or firstReading begins with a parenthetical like "(Vigil Mass)").
  bool _isMemorialEntryWellFormed(MemorialFeastEntry entry) {
    final fr = entry.firstReading.trim();
    if (fr.startsWith('(')) return false;
    final pr = entry.psalmReference.trim();
    if (pr.isNotEmpty) {
      final validPsalmPrefix = RegExp(
        r'^(Ps|Psalm|Isa|Exod|1\s+Sam|Dan|Luke\s+1)',
      );
      if (!validPsalmPrefix.hasMatch(pr)) return false;
    }
    final gospel = entry.gospel.trim();
    if (gospel.isNotEmpty) {
      final validGospelPrefix = RegExp(r'^(Matt|Mark|Luke|John)\s');
      if (!validGospelPrefix.hasMatch(gospel)) return false;
    }
    return true;
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

    // ── Special day checks first (before season check, since Holy Week
    //    entries use season='Holy Week' but calendar returns 'Lent') ──
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
    if (_isChristmasVigil(date)) {
      return season == 'christmas' && day.contains('christmas') && day.contains('vigil');
    }
    if (_isChristmasDay(date)) {
      return season == 'christmas' && day.contains('christmas');
    }
    if (_isAshWednesday(date)) {
      return season == 'lent' && day == 'ash wednesday';
    }
    if (_isAfterAshWednesdayToSaturday(date)) {
      return season == 'lent' && week == 'after ash wed' && day == liturgicalDay.dayName.toLowerCase();
    }
    if (_isEasterOctave(date)) {
      if (season != 'easter' || week != 'octave') {
        return false;
      }
      // Octave entries are per-day (Mon-Sat), so filter by weekday.
      return day == liturgicalDay.dayName.toLowerCase();
    }

    // ── Season must match exactly ──
    if (season != liturgicalSeason) {
      return false;
    }

    // Sunday cycle check (for Sunday entries)
    if (entry.sundayCycle.isNotEmpty &&
        entry.sundayCycle != 'A/B/C' &&
        entry.sundayCycle != 'ABC' &&
        entry.sundayCycle.toUpperCase() != sundayCycle.toUpperCase()) {
      return false;
    }

    // Weekday cycle check
    if (entry.weekdayCycle.isNotEmpty &&
        entry.weekdayCycle != 'I/II' &&
        entry.weekdayCycle.toUpperCase() != weekdayCycle.toUpperCase()) {
      return false;
    }

    // Date-based matches (December 17-24, Christmas octave, etc.)
    if (_monthDayLabel(date).toLowerCase() == day) {
      if (season == 'advent' && _isDecember17To24(date)) {
        return week == 'dec 17-24' || week.isEmpty;
      }
      if (season == 'christmas' && _isChristmasOctave(date)) {
        return week == 'octave' || week.isEmpty;
      }
      return true;
    }

    // Sunday matching: require season + day + week number
    if (isSunday) {
      if (day != 'sunday') {
        return false;
      }
      // Week must match; skip entries without week numbers
      if (week.isEmpty) {
        return false;
      }
      return week == liturgicalDay.weekNumber.toString();
    }

    // Weekday matching: require season + day of week + week number
    if (day != liturgicalDay.dayName.toLowerCase()) {
      return false;
    }
    if (_isDecember17To24(date)) {
      return season == 'advent' && (week == 'dec 17-24' || week.isEmpty);
    }
    if (_isChristmasOctave(date)) {
      return season == 'christmas' && (week == 'octave' || week.isEmpty);
    }
    if (season == 'holy week') {
      return false;
    }
    // Week must match; skip entries without week numbers
    if (week.isEmpty) {
      return false;
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
      final cleanedResponse = _stripLectionaryNoise(entry.psalmResponse);
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(entry.psalmReference),
        position: 'Responsorial Psalm',
        date: date,
        feast: entry.title,
        psalmResponse: cleanedResponse.isEmpty ? null : cleanedResponse,
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
        gospelAcclamation: _stripLectionaryNoise(entry.gospelAcclamation).isEmpty
            ? null
            : _stripLectionaryNoise(entry.gospelAcclamation),
        incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
      ));
    }
    if (entry.alternativeGospel.isNotEmpty) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(entry.alternativeGospel),
        position: 'Gospel (alternative)',
        date: date,
        feast: entry.title,
        gospelAcclamation: _stripLectionaryNoise(entry.gospelAcclamation).isEmpty
            ? null
            : _stripLectionaryNoise(entry.gospelAcclamation),
        incipit: entry.alternativeGospelIncipit.isEmpty
            ? null
            : entry.alternativeGospelIncipit,
      ));
    }
    return readings;
  }

  /// Authoritative Easter Vigil reading set: 7 OT readings (each with its
  /// own responsorial psalm), the Epistle (Rom 6), and the cycle-appropriate
  /// resurrection Gospel. Source: Roman Missal / Lectionary for Mass.
  List<DailyReading> _buildAuthoritativeEasterVigilReadings(
    DateTime date,
    String sundayCycle,
  ) {
    final cycle = sundayCycle.toUpperCase();

    final gospel = switch (cycle) {
      'A' => 'Matt 28:1-10',
      'B' => 'Mark 16:1-7',
      'C' => 'Luke 24:1-12',
      _ => 'Matt 28:1-10',
    };

    // Each tuple: reading reference, psalm reference, psalm response, incipit.
    final otReadings = <_VigilReading>[
      _VigilReading(
        reading: 'Gen 1:1-2:2',
        psalm: 'Ps 104:1-2, 5-6, 10 and 12, 13-14, 24 and 35',
        psalmResponse: 'Send forth your Spirit, O Lord, and renew the face of the earth.',
      ),
      _VigilReading(
        reading: 'Gen 22:1-18',
        psalm: 'Ps 16:5, 8, 9-10, 11',
        psalmResponse: 'You are my inheritance, O Lord.',
      ),
      _VigilReading(
        reading: 'Exod 14:15-15:1',
        psalm: 'Exod 15:1-2, 3-4, 5-6, 17-18',
        psalmResponse: 'Let us sing to the Lord; he has covered himself in glory.',
      ),
      _VigilReading(
        reading: 'Isa 54:5-14',
        psalm: 'Ps 30:2 and 4, 5-6, 11-12, 13',
        psalmResponse: 'I will praise you, Lord, for you have rescued me.',
      ),
      _VigilReading(
        reading: 'Isa 55:1-11',
        psalm: 'Isa 12:2-3, 4, 5-6',
        psalmResponse: 'You will draw water joyfully from the springs of salvation.',
      ),
      _VigilReading(
        reading: 'Bar 3:9-15, 32-4:4',
        psalm: 'Ps 19:8, 9, 10, 11',
        psalmResponse: 'Lord, you have the words of everlasting life.',
      ),
      _VigilReading(
        reading: 'Ezek 36:16-17a, 18-28',
        psalm: 'Ps 42:3, 5; 43:3, 4',
        psalmResponse: 'Like a deer that longs for running streams, my soul longs for you, my God.',
      ),
    ];

    final readings = <DailyReading>[];

    for (var i = 0; i < otReadings.length; i++) {
      final entry = otReadings[i];
      final positionLabel = _readingPosition(i + 1);
      readings.add(DailyReading(
        reading: entry.reading,
        position: positionLabel,
        date: date,
      ));
      readings.add(DailyReading(
        reading: entry.psalm,
        position: 'Responsorial Psalm after $positionLabel',
        date: date,
        psalmResponse: entry.psalmResponse,
      ));
    }

    // Epistle (8th reading)
    readings.add(DailyReading(
      reading: 'Rom 6:3-11',
      position: 'Epistle',
      date: date,
    ));
    readings.add(DailyReading(
      reading: 'Ps 118:1-2, 16-17, 22-23',
      position: 'Responsorial Psalm after Epistle',
      date: date,
      psalmResponse: 'Alleluia, alleluia, alleluia.',
    ));

    // Gospel
    readings.add(DailyReading(
      reading: gospel,
      position: 'Gospel',
      date: date,
      gospelAcclamation: 'This is the day the Lord has made; let us rejoice and be glad.',
    ));

    return readings;
  }

  // Legacy CSV-based Easter Vigil builder retained for reference — unused
  // after the authoritative override above took over.
  // ignore: unused_element
  List<DailyReading> _buildEasterVigilReadings(
    DateTime date,
    List<StandardLectionaryEntry> entries,
    String sundayCycle,
  ) {
    final vigilEntries = entries.where((entry) {
      return entry.season == 'Easter' &&
          entry.week == 'Vigil' &&
          entry.day.startsWith('Easter Vigil') &&
          (entry.sundayCycle.isEmpty ||
              entry.sundayCycle == 'A/B/C' ||
              entry.sundayCycle.toUpperCase() == sundayCycle.toUpperCase());
    }).toList();

    if (vigilEntries.isEmpty) {
      return const [];
    }

    // Separate main entries from alternatives
    final mainEntries = vigilEntries.where((e) => !e.day.contains('(Alt)')).toList();
    final altEntries = vigilEntries.where((e) => e.day.contains('(Alt)')).toList();

    final readings = <DailyReading>[];
    var readingIndex = 0;

    // Process main entries first
    for (final entry in mainEntries) {
      final isAlleluiaPsalm = entry.day.toLowerCase().contains('alleluia psalm');
      final isAlternative = entry.day.contains('(Alt)');

      if (entry.firstReading.isNotEmpty) {
        readingIndex++;
        String position;
        if (isAlleluiaPsalm) {
          position = 'Epistle';
        } else {
          position = _readingPosition(readingIndex);
          if (isAlternative) {
            position += ' (alternative)';
          }
        }
        readings.add(DailyReading(
          reading: _normalizeReferenceStyle(entry.firstReading),
          position: position,
          date: date,
          incipit: entry.firstReadingIncipit.isEmpty ? null : entry.firstReadingIncipit,
        ));
      }
      if (entry.psalmReference.isNotEmpty) {
        String position;
        if (isAlleluiaPsalm) {
          position = 'Alleluia Psalm';
        } else {
          position = 'Responsorial Psalm';
          if (isAlternative) {
            position += ' (alternative)';
          }
        }
        readings.add(DailyReading(
          reading: _normalizeEasterVigilPsalmReference(entry.psalmReference),
          position: position,
          date: date,
          psalmResponse: entry.psalmResponse.isEmpty ? null : entry.psalmResponse,
        ));
      }
    }

    // Process alternative entries after main entries
    for (final entry in altEntries) {
      final isAlleluiaPsalm = entry.day.toLowerCase().contains('alleluia psalm');
      
      if (entry.firstReading.isNotEmpty) {
        readingIndex++;
        String position;
        if (isAlleluiaPsalm) {
          position = 'Epistle (alternative)';
        } else {
          position = '${_readingPosition(readingIndex)} (alternative)';
        }
        readings.add(DailyReading(
          reading: _normalizeReferenceStyle(entry.firstReading),
          position: position,
          date: date,
          incipit: entry.firstReadingIncipit.isEmpty ? null : entry.firstReadingIncipit,
        ));
      }
      if (entry.psalmReference.isNotEmpty) {
        String position;
        if (isAlleluiaPsalm) {
          position = 'Alleluia Psalm (alternative)';
        } else {
          position = 'Responsorial Psalm (alternative)';
        }
        readings.add(DailyReading(
          reading: _normalizeEasterVigilPsalmReference(entry.psalmReference),
          position: position,
          date: date,
          psalmResponse: entry.psalmResponse.isEmpty ? null : entry.psalmResponse,
        ));
      }
    }

    // Add Gospel from the last main entry (Alleluia Psalm entry)
    final gospelEntry = mainEntries.where((e) => e.day.toLowerCase().contains('alleluia psalm')).firstOrNull;
    if (gospelEntry != null) {
      readings.add(DailyReading(
        reading: _normalizeReferenceStyle(_cycleSpecificGospel(gospelEntry.gospel, sundayCycle)),
        position: 'Gospel',
        date: date,
        gospelAcclamation: _stripLectionaryNoise(gospelEntry.acclamationText).isEmpty ? null : _stripLectionaryNoise(gospelEntry.acclamationText),
        incipit: gospelEntry.gospelIncipit.isEmpty ? null : gospelEntry.gospelIncipit,
      ));
    }

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

    if (normalizedTitle == _normalizeTitle('Saints Peter and Paul, Apostles')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Acts 12:1-11',
        psalm: 'Ps 34:2-3, 4-5, 6-7, 8-9',
        psalmResponse: 'The angel of the Lord will rescue those who fear him.',
        secondReading: '2 Tim 4:6-8, 17-18',
        gospel: 'Matt 16:13-19',
        gospelAcclamation: 'You are Peter, and upon this rock I will build my Church, and the gates of the netherworld shall not prevail against it.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Exaltation of the Holy Cross')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Num 21:4b-9',
        psalm: 'Ps 78:1-2, 34-35, 36-37, 38',
        psalmResponse: 'Do not forget the works of the Lord!',
        secondReading: 'Phil 2:6-11',
        gospel: 'John 3:13-17',
        gospelAcclamation: 'We adore you, O Christ, and we bless you, because by your Cross you have redeemed the world.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Transfiguration of the Lord')) {
      final gospel = switch (cycle) {
        'A' => 'Matt 17:1-9',
        'B' => 'Mark 9:2-10',
        'C' => 'Luke 9:28b-36',
        _ => 'Matt 17:1-9',
      };
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Dan 7:9-10, 13-14',
        psalm: 'Ps 97:1-2, 5-6, 9',
        psalmResponse: 'The Lord is king, the Most High over all the earth.',
        secondReading: '2 Pet 1:16-19',
        gospel: gospel,
        gospelAcclamation: 'This is my beloved Son, with whom I am well pleased; listen to him.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Presentation of the Lord')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Mal 3:1-4',
        psalm: 'Ps 24:7, 8, 9, 10',
        psalmResponse: 'Who is this king of glory? It is the Lord!',
        secondReading: 'Heb 2:14-18',
        gospel: 'Luke 2:22-40',
        gospelAcclamation: 'A light of revelation to the Gentiles, and the glory of your people Israel.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Assumption of the Blessed Virgin Mary') ||
        normalizedTitle == _normalizeTitle('The Assumption')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Rev 11:19a; 12:1-6a, 10ab',
        psalm: 'Ps 45:10, 11, 12, 16',
        psalmResponse: 'The queen stands at your right hand, arrayed in gold.',
        secondReading: '1 Cor 15:20-27',
        gospel: 'Luke 1:39-56',
        gospelAcclamation: 'Mary is taken up to heaven; the host of angels rejoices.',
      );
    }

    if (normalizedTitle == _normalizeTitle('All Saints')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Rev 7:2-4, 9-14',
        psalm: 'Ps 24:1-2, 3-4, 5-6',
        psalmResponse: 'Lord, this is the people that longs to see your face.',
        secondReading: '1 John 3:1-3',
        gospel: 'Matt 5:1-12a',
        gospelAcclamation: 'Come to me, all you who labor and are burdened, and I will give you rest.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Commemoration of All the Faithful Departed') ||
        normalizedTitle == _normalizeTitle('All Souls')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Wis 3:1-9',
        psalm: 'Ps 23:1-3a, 3b-4, 5, 6',
        psalmResponse: 'The Lord is my shepherd; there is nothing I shall want.',
        secondReading: 'Rom 5:5-11',
        gospel: 'John 6:37-40',
        gospelAcclamation: 'This is the will of my Father, says the Lord: that I should not lose anything of what he gave me, but that I should raise it on the last day.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Dedication of the Lateran Basilica')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Ezek 47:1-2, 8-9, 12',
        psalm: 'Ps 46:2-3, 5-6, 8-9',
        psalmResponse: 'The waters of the river gladden the city of God, the holy dwelling of the Most High.',
        secondReading: '1 Cor 3:9c-11, 16-17',
        gospel: 'John 2:13-22',
        gospelAcclamation: 'I have chosen and consecrated this house, says the Lord, that my name may be there forever.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Nativity of Saint John the Baptist')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Isa 49:1-6',
        psalm: 'Ps 139:1-3, 13-14, 14-15',
        psalmResponse: 'I praise you, for I am wonderfully made.',
        secondReading: 'Acts 13:22-26',
        gospel: 'Luke 1:57-66, 80',
        gospelAcclamation: 'You, child, will be called prophet of the Most High, for you will go before the Lord to prepare his ways.',
      );
    }

    if (normalizedTitle == _normalizeTitle('The Holy Family of Jesus, Mary and Joseph') ||
        normalizedTitle == _normalizeTitle('Holy Family')) {
      final firstReading = switch (cycle) {
        'A' => 'Sir 3:2-6, 12-14',
        'B' => 'Gen 15:1-6; 21:1-3',
        'C' => '1 Sam 1:20-22, 24-28',
        _ => 'Sir 3:2-6, 12-14',
      };
      final psalm = switch (cycle) {
        'A' => 'Ps 128:1-2, 3, 4-5',
        'B' => 'Ps 105:1-2, 3-4, 5-6, 8-9',
        'C' => 'Ps 84:2-3, 5-6, 9-10',
        _ => 'Ps 128:1-2, 3, 4-5',
      };
      final psalmResponse = switch (cycle) {
        'A' => 'Blessed are those who fear the Lord and walk in his ways.',
        'B' => 'The Lord remembers his covenant for ever.',
        'C' => 'Blessed are they who dwell in your house, O Lord.',
        _ => 'Blessed are those who fear the Lord and walk in his ways.',
      };
      final secondReading = switch (cycle) {
        'A' => 'Col 3:12-21',
        'B' => 'Heb 11:8, 11-12, 17-19',
        'C' => '1 John 3:1-2, 21-24',
        _ => 'Col 3:12-21',
      };
      final gospel = switch (cycle) {
        'A' => 'Matt 2:13-15, 19-23',
        'B' => 'Luke 2:22-40',
        'C' => 'Luke 2:41-52',
        _ => 'Matt 2:13-15, 19-23',
      };
      return _buildOverrideReadings(
        date: date,
        firstReading: firstReading,
        psalm: psalm,
        psalmResponse: psalmResponse,
        secondReading: secondReading,
        gospel: gospel,
        gospelAcclamation: 'Let the peace of Christ control your hearts; let the word of Christ dwell in you richly.',
      );
    }

    if (normalizedTitle == _normalizeTitle('Easter Sunday of the Resurrection of the Lord')) {
      return _buildOverrideReadings(
        date: date,
        firstReading: 'Acts 10:34a, 37-43',
        psalm: 'Ps 118:1-2, 16-17, 22-23',
        psalmResponse: 'This is the day the Lord has made; let us rejoice and be glad.',
        secondReading: 'Col 3:1-4',
        gospel: 'John 20:1-9',
        gospelAcclamation: 'Christ, our paschal lamb, has been sacrificed; let us then feast with joy in the Lord.',
      );
    }

    // Apostle and other major feasts (gospel-required days)
    final apostleFeasts = <String, _ApostleFeast>{
      _normalizeTitle('The Conversion of Saint Paul, Apostle'): _ApostleFeast(
        firstReading: 'Acts 22:3-16',
        psalm: 'Ps 117:1, 2',
        psalmResponse: 'Go out to all the world and tell the Good News.',
        gospel: 'Mark 16:15-18',
        gospelAcclamation: 'I have chosen you from the world, says the Lord, to go and bear fruit that will remain.',
      ),
      _normalizeTitle('The Chair of Saint Peter, Apostle'): _ApostleFeast(
        firstReading: '1 Pet 5:1-4',
        psalm: 'Ps 23:1-3a, 4, 5, 6',
        psalmResponse: 'The Lord is my shepherd; there is nothing I shall want.',
        gospel: 'Matt 16:13-19',
        gospelAcclamation: 'You are Peter, and upon this rock I will build my Church, and the gates of the netherworld shall not prevail against it.',
      ),
      _normalizeTitle('Saint Mark, Evangelist'): _ApostleFeast(
        firstReading: '1 Pet 5:5b-14',
        psalm: 'Ps 89:2-3, 6-7, 16-17',
        psalmResponse: 'For ever I will sing the goodness of the Lord.',
        gospel: 'Mark 16:15-20',
        gospelAcclamation: 'We proclaim Christ crucified; Christ is the power of God and the wisdom of God.',
      ),
      _normalizeTitle('Saints Philip and James, Apostles'): _ApostleFeast(
        firstReading: '1 Cor 15:1-8',
        psalm: 'Ps 19:2-3, 4-5',
        psalmResponse: 'Their message goes out through all the earth.',
        gospel: 'John 14:6-14',
        gospelAcclamation: 'I am the way and the truth and the life, says the Lord; no one comes to the Father, except through me.',
      ),
      _normalizeTitle('Saint Matthias, Apostle'): _ApostleFeast(
        firstReading: 'Acts 1:15-17, 20-26',
        psalm: 'Ps 113:1-2, 3-4, 5-6, 7-8',
        psalmResponse: 'The Lord will give him a seat with the leaders of his people.',
        gospel: 'John 15:9-17',
        gospelAcclamation: 'I chose you from the world, says the Lord, to go and bear fruit that will remain.',
      ),
      _normalizeTitle('Saint Thomas, Apostle'): _ApostleFeast(
        firstReading: 'Eph 2:19-22',
        psalm: 'Ps 117:1, 2',
        psalmResponse: 'Go out to all the world and tell the Good News.',
        gospel: 'John 20:24-29',
        gospelAcclamation: 'You believe in me, Thomas, because you have seen me, says the Lord; blessed are they who have not seen me, but still believe!',
      ),
      _normalizeTitle('Saint Mary Magdalene'): _ApostleFeast(
        firstReading: 'Song 3:1-4b',
        psalm: 'Ps 63:2, 3-4, 5-6, 8-9',
        psalmResponse: 'My soul is thirsting for you, O Lord my God.',
        gospel: 'John 20:1-2, 11-18',
        gospelAcclamation: 'Tell us, Mary, what did you see on the way? I have seen the Lord of life arisen!',
      ),
      _normalizeTitle('Saint James, Apostle'): _ApostleFeast(
        firstReading: '2 Cor 4:7-15',
        psalm: 'Ps 126:1-2ab, 2cd-3, 4-5, 6',
        psalmResponse: 'Those who sow in tears shall reap rejoicing.',
        gospel: 'Matt 20:20-28',
        gospelAcclamation: 'I chose you from the world, says the Lord, to go and bear fruit that will remain.',
      ),
      _normalizeTitle('Saint Bartholomew, Apostle'): _ApostleFeast(
        firstReading: 'Rev 21:9b-14',
        psalm: 'Ps 145:10-11, 12-13, 17-18',
        psalmResponse: 'Your friends make known, O Lord, the glorious splendor of your Kingdom.',
        gospel: 'John 1:45-51',
        gospelAcclamation: 'Rabbi, you are the Son of God; you are the King of Israel.',
      ),
      _normalizeTitle('The Nativity of the Blessed Virgin Mary'): _ApostleFeast(
        firstReading: 'Mic 5:1-4a',
        psalm: 'Ps 13:6ab, 6c',
        psalmResponse: 'With delight I rejoice in the Lord.',
        gospel: 'Matt 1:1-16, 18-23',
        gospelAcclamation: 'Blessed are you, holy Virgin Mary, and most worthy of all praise; for from you arose the sun of justice, Christ our God.',
      ),
      _normalizeTitle('Saint Matthew, Apostle and Evangelist'): _ApostleFeast(
        firstReading: 'Eph 4:1-7, 11-13',
        psalm: 'Ps 19:2-3, 4-5',
        psalmResponse: 'Their message goes out through all the earth.',
        gospel: 'Matt 9:9-13',
        gospelAcclamation: 'We praise you, O God, we acclaim you as Lord; the glorious company of Apostles praises you.',
      ),
      _normalizeTitle('Saints Michael, Gabriel, and Raphael, Archangels'): _ApostleFeast(
        firstReading: 'Dan 7:9-10, 13-14',
        psalm: 'Ps 138:1-2ab, 2cde-3, 4-5',
        psalmResponse: 'In the sight of the angels I will sing your praises, Lord.',
        gospel: 'John 1:47-51',
        gospelAcclamation: 'Bless the Lord, all you his angels, you ministers, who do his will.',
      ),
      _normalizeTitle('Saint Luke, Evangelist'): _ApostleFeast(
        firstReading: '2 Tim 4:10-17b',
        psalm: 'Ps 145:10-11, 12-13, 17-18',
        psalmResponse: 'Your friends make known, O Lord, the glorious splendor of your Kingdom.',
        gospel: 'Luke 10:1-9',
        gospelAcclamation: 'I chose you from the world, says the Lord, to go and bear fruit that will remain.',
      ),
      _normalizeTitle('Saints Simon and Jude, Apostles'): _ApostleFeast(
        firstReading: 'Eph 2:19-22',
        psalm: 'Ps 19:2-3, 4-5',
        psalmResponse: 'Their message goes out through all the earth.',
        gospel: 'Luke 6:12-16',
        gospelAcclamation: 'We praise you, O God, we acclaim you as Lord; the glorious company of Apostles praises you.',
      ),
      _normalizeTitle('Saint Andrew, Apostle'): _ApostleFeast(
        firstReading: 'Rom 10:9-18',
        psalm: 'Ps 19:2-3, 4-5',
        psalmResponse: 'Their message goes out through all the earth.',
        gospel: 'Matt 4:18-22',
        gospelAcclamation: 'Come after me, says the Lord, and I will make you fishers of men.',
      ),
      _normalizeTitle('Saint Stephen, The First Martyr'): _ApostleFeast(
        firstReading: 'Acts 6:8-10; 7:54-59',
        psalm: 'Ps 31:3cd-4, 6 and 8ab, 16bc and 17',
        psalmResponse: 'Into your hands, O Lord, I commend my spirit.',
        gospel: 'Matt 10:17-22',
        gospelAcclamation: 'Blessed is he who comes in the name of the Lord! Blessed is the kingdom of our father David that is to come!',
      ),
      _normalizeTitle('Saint John, Apostle and Evangelist'): _ApostleFeast(
        firstReading: '1 John 1:1-4',
        psalm: 'Ps 97:1-2, 5-6, 11-12',
        psalmResponse: 'Rejoice in the Lord, you just!',
        gospel: 'John 20:1a, 2-8',
        gospelAcclamation: 'We praise you, O God, we acclaim you as Lord; the glorious company of Apostles praises you.',
      ),
      _normalizeTitle('The Holy Innocents, Martyrs'): _ApostleFeast(
        firstReading: '1 John 1:5 - 2:2',
        psalm: 'Ps 124:2-3, 4-5, 7b-8',
        psalmResponse: 'Our soul has been rescued like a bird from the fowler\'s snare.',
        gospel: 'Matt 2:13-18',
        gospelAcclamation: 'We praise you, O God, we acclaim you as Lord; the white-robed army of martyrs praises you.',
      ),
    };

    final feast = apostleFeasts[normalizedTitle];
    if (feast != null) {
      return _buildOverrideReadings(
        date: date,
        firstReading: feast.firstReading,
        psalm: feast.psalm,
        psalmResponse: feast.psalmResponse,
        secondReading: null,
        gospel: feast.gospel,
        gospelAcclamation: feast.gospelAcclamation,
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
    var hasAcclamation = false;
    var hasSecondReading = false;
    var hasGospel = false;

    for (final entry in entries) {
      if (entry.firstReading.isNotEmpty) {
        final normalized = _normalizeReferenceStyle(entry.firstReading);
        final firstReadingExists = readings.any((r) => r.position == 'First Reading');
        final candidateKey = _referenceDedupeKey(normalized);
        final hasSameFirstReading = readings.any(
          (r) => _referenceDedupeKey(r.reading) == candidateKey &&
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
        final cleanedResponse =
            _stripLectionaryNoise(entry.psalmResponse);
        readings.add(DailyReading(
          reading: _normalizeReferenceStyle(entry.psalmReference),
          position: 'Responsorial Psalm',
          date: date,
          psalmResponse: cleanedResponse.isEmpty ? null : cleanedResponse,
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
            incipit: entry.secondReadingIncipit.isEmpty ? null : entry.secondReadingIncipit,
          ));
        } else {
          final candidateKey = _referenceDedupeKey(normalizedSecondReading);
          final hasSameSecondReading = readings.any(
            (r) => _referenceDedupeKey(r.reading) == candidateKey &&
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
        // Emit Gospel Acclamation as a separate reading once, just before the first gospel.
        if (!hasGospel && !hasAcclamation && entry.acclamationRef.isNotEmpty) {
          hasAcclamation = true;
          readings.add(DailyReading(
            reading: _normalizeReferenceStyle(entry.acclamationRef),
            position: 'Gospel Acclamation',
            date: date,
            gospelAcclamation: _stripLectionaryNoise(entry.acclamationText).isEmpty ? null : _stripLectionaryNoise(entry.acclamationText),
          ));
        }

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
              gospelAcclamation: _stripLectionaryNoise(entry.acclamationText).isEmpty
                  ? null
                  : _stripLectionaryNoise(entry.acclamationText),
              incipit: entry.gospelIncipit.isEmpty ? null : entry.gospelIncipit,
            ));
            // Always add the alternative when present
            readings.add(DailyReading(
              reading: normalizedSecond,
              position: 'Gospel (alternative)',
              date: date,
              gospelAcclamation: _stripLectionaryNoise(entry.acclamationText).isEmpty
                  ? null
                  : _stripLectionaryNoise(entry.acclamationText),
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
                gospelAcclamation: _stripLectionaryNoise(entry.acclamationText).isEmpty
                    ? null
                    : _stripLectionaryNoise(entry.acclamationText),
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
                gospelAcclamation: _stripLectionaryNoise(entry.acclamationText).isEmpty
                    ? null
                    : _stripLectionaryNoise(entry.acclamationText),
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
              gospelAcclamation: _stripLectionaryNoise(entry.acclamationText).isEmpty
                  ? null
                  : _stripLectionaryNoise(entry.acclamationText),
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
                gospelAcclamation: _stripLectionaryNoise(entry.acclamationText).isEmpty
                    ? null
                    : _stripLectionaryNoise(entry.acclamationText),
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

  /// Strips page numbers, section headers, and lectionary-rubric residue
  /// that the source PDF extraction glued onto the end of refrain / gospel
  /// acclamation text. Examples the cleaner must handle:
  ///   "God loved … eternal life. 518 SECOND WEEK OF EASTER"
  ///       → "God loved … eternal life."
  ///   "Lord Jesus … you speak to us.-R."
  ///       → "Lord Jesus … you speak to us."
  ///   "I give you a new commandment … GO S P E L 1586 TWENTY-FIRST WEEK …"
  ///       → "I give you a new commandment …"
  String _stripLectionaryNoise(String value) {
    var cleaned = value.trim();
    if (cleaned.isEmpty) return cleaned;

    // Normalize spaced-out section markers e.g. "GO S P E L" → "GOSPEL".
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b([A-Z])(\s[A-Z]){3,}\b'),
      (match) => match.group(0)!.replaceAll(' ', ''),
    );

    // Trailing " 1234 SECTION HEADER" (page number + ALL-CAPS heading).
    cleaned = cleaned.replaceFirst(
      RegExp(r'\s+\d{2,4}\s+[A-Z][A-Z \-–]{2,}.*$'),
      '',
    );

    // Trailing ALL-CAPS section heading without a page number (e.g.
    // "… give ear to my words. GOSPEL" → strip "GOSPEL").
    cleaned = cleaned.replaceFirst(
      RegExp(r'\s+(GOSPEL|EPISTLE|RESPONSORIAL\s+PSALM|ALLELUIA|SEQUENCE)\b.*$',
          caseSensitive: true),
      '',
    );

    // Trailing rubric "-R." / "- R." / ".—R." (response marker artifact).
    cleaned = cleaned.replaceFirst(
      RegExp(r'\s*[-–—]\s*R\.?\s*$'),
      '',
    );

    return cleaned.trim();
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

  /// Produces a loose key for deduping scripture references that differ only
  /// in punctuation/whitespace/book-name style, e.g. "2 Cor 5:20-6:2" and
  /// "2 Corinthians 5.20 - 6.2" both map to "2cor5206-62" (chapter:verse
  /// boundaries collapsed). Book names get abbreviated first via
  /// [_normalizeReferenceStyle] so "Corinthians" and "Cor" hash the same.
  String _referenceDedupeKey(String value) {
    final abbreviated = _normalizeReferenceStyle(value);
    return abbreviated
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('.', ':')
        .replaceAll(',', '')
        .replaceAll(';', '');
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
        .replaceAll('2 Corinthians', '2 Cor')
        .replaceAll('1 Corinthians', '1 Cor')
        .replaceAll('2 Kings', '2 Kgs')
        .replaceAll('1 Kings', '1 Kgs')
        .replaceAll('2 Chronicles', '2 Chr')
        .replaceAll('1 Chronicles', '1 Chr')
        .replaceAll('2 Thessalonians', '2 Thess')
        .replaceAll('1 Thessalonians', '1 Thess')
        .replaceAll('2 Timothy', '2 Tim')
        .replaceAll('1 Timothy', '1 Tim')
        .replaceAll('2 Peter', '2 Pet')
        .replaceAll('1 Peter', '1 Pet')
        .replaceAll('2 John', '2 John')
        .replaceAll('1 John', '1 John')
        .replaceAll('Isaiah', 'Isa')
        .replaceAll('Jeremiah', 'Jer')
        .replaceAll('Zephaniah', 'Zeph')
        .replaceAll('Zechariah', 'Zech')
        .replaceAll('Malachi', 'Mal')
        .replaceAll('Genesis', 'Gen')
        .replaceAll('Exodus', 'Exod')
        .replaceAll('Leviticus', 'Lev')
        .replaceAll('Numbers', 'Num')
        .replaceAll('Deuteronomy', 'Deut')
        .replaceAll('Matthew', 'Matt')
        .replaceAll('Luke', 'Luke')
        .replaceAll('Mark', 'Mark')
        .replaceAll('John', 'John')
        .replaceAll('Romans', 'Rom')
        .replaceAll('Galatians', 'Gal')
        .replaceAll('Ephesians', 'Eph')
        .replaceAll('Philippians', 'Phil')
        .replaceAll('Colossians', 'Col')
        .replaceAll('Philemon', 'Phlm')
        .replaceAll('Hebrews', 'Heb')
        .replaceAll('James', 'Jas')
        .replaceAll('Revelation', 'Rev')
        .replaceAll('Wisdom', 'Wis')
        .replaceAll('Sirach', 'Sir')
        .replaceAll('Ecclesiastes', 'Eccl')
        .replaceAll('Ecclesiasticus', 'Sir')
        .replaceAll('Ezekiel', 'Ezek')
        .replaceAll('Daniel', 'Dan')
        .replaceAll('Lamentations', 'Lam')
        .replaceAll('Nehemiah', 'Neh')
        .replaceAll('Baruch', 'Bar')
        .replaceAll('Psalms', 'Ps')
        .replaceAll('Psalm', 'Ps');
    // Convert period notation to colon for the chapter.verse separator only.
    // Anchored to the start so mid-string periods like "and 12.13" are not touched.
    // Handles both "Psalm 72.1-2" and "Psalm 1. 1-2" (space after period).
    result = result.replaceFirstMapped(
      RegExp(r'^([A-Za-z0-9 ]+\s\d+)\.\s*(\d)'),
      (match) => '${match.group(1)}:${match.group(2)}',
    );
    result = result.replaceFirst(RegExp(r'\s+or\s+.+$', caseSensitive: false), '');
    // Note: "(R. Xx)" refrain notation is preserved intentionally. The
    // ReadingsBackend decodes it to fetch the authoritative RSVCE refrain
    // text so the displayed response matches the selected Bible translation.
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

  bool _isChristmasDay(DateTime date) {
    return date.month == 12 && date.day == 25;
  }

  bool _isChristmasVigil(DateTime date) {
    return date.month == 12 && date.day == 24;
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

class _ApostleFeast {
  final String firstReading;
  final String psalm;
  final String psalmResponse;
  final String gospel;
  final String gospelAcclamation;

  const _ApostleFeast({
    required this.firstReading,
    required this.psalm,
    required this.psalmResponse,
    required this.gospel,
    required this.gospelAcclamation,
  });
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

class _VigilReading {
  final String reading;
  final String psalm;
  final String psalmResponse;

  const _VigilReading({
    required this.reading,
    required this.psalm,
    required this.psalmResponse,
  });
}
