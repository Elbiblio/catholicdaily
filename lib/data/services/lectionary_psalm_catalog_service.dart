import 'package:flutter/services.dart' show rootBundle;

import 'improved_liturgical_calendar_service.dart';
import 'ordo_resolver_service.dart';

class LectionaryPsalmCatalogEntry {
  final String season;
  final String week;
  final String day;
  final String weekdayCycle;
  final String sundayCycle;
  final String fullReference;
  final String refrainText;
  final String acclamationRef;
  final String acclamationText;
  final String lectionaryNumber;

  const LectionaryPsalmCatalogEntry({
    required this.season,
    required this.week,
    required this.day,
    required this.weekdayCycle,
    required this.sundayCycle,
    required this.fullReference,
    required this.refrainText,
    required this.acclamationRef,
    required this.acclamationText,
    required this.lectionaryNumber,
  });
}

class LectionaryPsalmCatalogService {
  static final LectionaryPsalmCatalogService instance =
      LectionaryPsalmCatalogService._();

  LectionaryPsalmCatalogService._();

  final ImprovedLiturgicalCalendarService _calendarService =
      ImprovedLiturgicalCalendarService.instance;
  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;

  List<LectionaryPsalmCatalogEntry>? _entries;
  final Map<String, List<LectionaryPsalmCatalogEntry>> _dateCache = {};

  Future<List<LectionaryPsalmCatalogEntry>> getEntriesForDate(DateTime date) async {
    final key = _dateKey(date);
    if (_dateCache.containsKey(key)) {
      return _dateCache[key]!;
    }

    final allEntries = await _loadEntries();
    final liturgicalDay = _calendarService.getLiturgicalDay(date);
    final yearVariables = await _ordoResolver.resolveYearVariables(date);
    final easterSunday = _calculateEasterSunday(date.year);

    final matches = allEntries.where((entry) {
      return _matchesDate(
        entry: entry,
        date: date,
        liturgicalDay: liturgicalDay,
        sundayCycle: yearVariables.sundayCycle,
        weekdayCycle: yearVariables.weekdayCycle,
        easterSunday: easterSunday,
      );
    }).toList();

    _dateCache[key] = matches;
    return matches;
  }

  String? resolvePsalmResponseFromEntries({
    required List<LectionaryPsalmCatalogEntry> entries,
    required String psalmReference,
    String? positionLabel,
    int? psalmSequence,
  }) {
    final match = _resolvePsalmEntry(
      entries: entries,
      psalmReference: psalmReference,
      positionLabel: positionLabel,
      psalmSequence: psalmSequence,
    );
    final response = match?.refrainText.trim();
    if (response == null || response.isEmpty) {
      return null;
    }
    return response;
  }

  String? resolveGospelAcclamationFromEntries({
    required List<LectionaryPsalmCatalogEntry> entries,
    required String gospelReference,
    String? positionLabel,
  }) {
    final withText = entries
        .where((entry) => entry.acclamationText.trim().isNotEmpty)
        .toList();
    if (withText.isEmpty) {
      return null;
    }

    final normalizedPosition = (positionLabel ?? '').toLowerCase();
    if (normalizedPosition.contains('vigil')) {
      return withText.last.acclamationText.trim();
    }

    return withText.last.acclamationText.trim();
  }

  Future<List<LectionaryPsalmCatalogEntry>> _loadEntries() async {
    if (_entries != null) {
      return _entries!;
    }

    final rawCsv = await rootBundle.loadString('lectionary_psalms.csv');
    final lines = rawCsv
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final parsed = <LectionaryPsalmCatalogEntry>[];
    for (var i = 1; i < lines.length; i++) {
      final columns = _parseCsvLine(lines[i]);
      if (columns.length < 10) {
        continue;
      }

      parsed.add(
        LectionaryPsalmCatalogEntry(
          season: columns[0].trim(),
          week: columns[1].trim(),
          day: columns[2].trim(),
          weekdayCycle: columns[3].trim(),
          sundayCycle: columns[4].trim(),
          fullReference: columns[5].trim(),
          refrainText: columns[6].trim(),
          acclamationRef: columns[7].trim(),
          acclamationText: columns[8].trim(),
          lectionaryNumber: columns[9].trim(),
        ),
      );
    }

    _entries = parsed;
    return parsed;
  }

  bool _matchesDate({
    required LectionaryPsalmCatalogEntry entry,
    required DateTime date,
    required LiturgicalDay liturgicalDay,
    required String sundayCycle,
    required String weekdayCycle,
    required DateTime easterSunday,
  }) {
    final isSunday = date.weekday == DateTime.sunday;
    final normalizedSeason = entry.season.trim().toLowerCase();
    final normalizedDay = entry.day.trim().toLowerCase();
    final normalizedWeek = entry.week.trim().toLowerCase();

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

    if (_isSameDate(date, easterSunday.subtract(const Duration(days: 1)))) {
      return normalizedSeason == 'easter' && normalizedWeek == 'vigil';
    }

    if (_isSameDate(date, easterSunday.subtract(const Duration(days: 7)))) {
      return normalizedSeason == 'holy week' && normalizedDay == 'palm sunday';
    }

    if (_isSameDate(date, easterSunday.subtract(const Duration(days: 3)))) {
      return normalizedSeason == 'holy week' && normalizedDay == 'holy thursday';
    }

    if (_isSameDate(date, easterSunday.subtract(const Duration(days: 2)))) {
      return normalizedSeason == 'holy week' && normalizedDay == 'good friday';
    }

    if (date.isAfter(easterSunday.subtract(const Duration(days: 7))) &&
        date.isBefore(easterSunday.subtract(const Duration(days: 3)))) {
      return normalizedSeason == 'holy week' &&
          normalizedDay == _weekdayName(date).toLowerCase();
    }

    final monthDayLabel = _monthDayLabel(date).toLowerCase();
    if (normalizedDay == monthDayLabel) {
      if (normalizedSeason == 'advent' && _isDecember17To24(date)) {
        return normalizedWeek == 'dec 17-24';
      }
      if (normalizedSeason == 'christmas' && _isChristmasOctave(date)) {
        return normalizedWeek == 'octave';
      }
      return true;
    }

    if (isSunday) {
      if (normalizedDay != 'sunday') {
        return false;
      }
      return _matchesSundaySeasonAndWeek(
        entry: entry,
        liturgicalDay: liturgicalDay,
        date: date,
        easterSunday: easterSunday,
      );
    }

    if (normalizedDay != _weekdayName(date).toLowerCase()) {
      return false;
    }

    return _matchesWeekdaySeasonAndWeek(
      entry: entry,
      liturgicalDay: liturgicalDay,
      date: date,
      easterSunday: easterSunday,
    );
  }

  bool _matchesSundaySeasonAndWeek({
    required LectionaryPsalmCatalogEntry entry,
    required LiturgicalDay liturgicalDay,
    required DateTime date,
    required DateTime easterSunday,
  }) {
    final season = entry.season.trim().toLowerCase();
    final week = entry.week.trim().toLowerCase();

    if (_isSameDate(date, easterSunday.subtract(const Duration(days: 7)))) {
      return season == 'holy week' && entry.day.trim().toLowerCase() == 'palm sunday';
    }

    final seasonName = liturgicalDay.seasonName.toLowerCase();
    if (season != seasonName) {
      return false;
    }

    if (seasonName == 'christmas' && week == 'octave') {
      return _isChristmasOctave(date);
    }

    if (week.isEmpty) {
      return true;
    }

    return week == liturgicalDay.weekNumber.toString();
  }

  bool _matchesWeekdaySeasonAndWeek({
    required LectionaryPsalmCatalogEntry entry,
    required LiturgicalDay liturgicalDay,
    required DateTime date,
    required DateTime easterSunday,
  }) {
    final season = entry.season.trim().toLowerCase();
    final week = entry.week.trim().toLowerCase();
    final seasonName = liturgicalDay.seasonName.toLowerCase();

    if (_isDecember17To24(date)) {
      return season == 'advent' && week == 'dec 17-24';
    }

    if (_isChristmasOctave(date)) {
      return season == 'christmas' && week == 'octave';
    }

    if (_isSameDate(date, easterSunday.subtract(const Duration(days: 1)))) {
      return season == 'easter' && week == 'vigil';
    }

    if (season == 'holy week') {
      return false;
    }

    if (seasonName != season) {
      return false;
    }

    if (week.isEmpty) {
      return true;
    }

    return week == liturgicalDay.weekNumber.toString();
  }

  LectionaryPsalmCatalogEntry? _resolvePsalmEntry({
    required List<LectionaryPsalmCatalogEntry> entries,
    required String psalmReference,
    String? positionLabel,
    int? psalmSequence,
  }) {
    if (entries.isEmpty) {
      return null;
    }

    final normalizedReference = _normalizeReference(psalmReference);
    final exactMatches = entries
        .where((entry) => _normalizeReference(entry.fullReference) == normalizedReference)
        .toList();
    if (exactMatches.isNotEmpty) {
      return exactMatches.first;
    }

    final looseMatches = entries.where((entry) {
      final candidate = _normalizeReference(entry.fullReference);
      return candidate.contains(normalizedReference) ||
          normalizedReference.contains(candidate);
    }).toList();
    if (looseMatches.isNotEmpty) {
      return looseMatches.first;
    }

    final psalmEntries = entries
        .where((entry) => entry.day.toLowerCase().contains('psalm'))
        .toList();
    if (psalmEntries.isNotEmpty && psalmSequence != null) {
      final index = psalmSequence - 1;
      if (index >= 0 && index < psalmEntries.length) {
        return psalmEntries[index];
      }
    }

    if (psalmSequence != null) {
      final index = psalmSequence - 1;
      if (index >= 0 && index < entries.length) {
        return entries[index];
      }
    }

    return entries.first;
  }

  List<String> _parseCsvLine(String line) {
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

  String _normalizeReference(String value) {
    return value
        .toLowerCase()
        .replaceAll('psalm', 'ps')
        .replaceAll('see ', '')
        .replaceAll('cf. ', '')
        .replaceAll('cf ', '')
        .replaceAll(RegExp(r'\(r\.[^)]*\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
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

  String _weekdayName(DateTime date) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday];
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
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
}
