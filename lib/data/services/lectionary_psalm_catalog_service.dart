import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'base_service.dart';
import 'ordo_resolver_service.dart';
import 'improved_liturgical_calendar_service.dart';
import 'reading_catalog_service.dart';

class LectionaryPsalmCatalogEntry {
  final String season;
  final String week;
  final String day;
  final String weekdayCycle;
  final String sundayCycle;
  final String fullReference;
  final String refrainText;
  final String refrainTextRsvce;
  final String refrainTextNabre;
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
    this.refrainTextRsvce = '',
    this.refrainTextNabre = '',
    required this.acclamationRef,
    required this.acclamationText,
    required this.lectionaryNumber,
  });
}

class LectionaryPsalmCatalogService
    extends BaseService<LectionaryPsalmCatalogService> {
  static LectionaryPsalmCatalogService get instance =>
      BaseService.init(() => LectionaryPsalmCatalogService._());

  LectionaryPsalmCatalogService._();

  final ImprovedLiturgicalCalendarService _calendarService =
      ImprovedLiturgicalCalendarService.instance;
  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;
  final ReadingCatalogService _readingCatalogService =
      ReadingCatalogService.instance;

  List<LectionaryPsalmCatalogEntry>? _entries;
  final Map<String, List<LectionaryPsalmCatalogEntry>> _dateCache = {};

  Future<List<LectionaryPsalmCatalogEntry>> getEntriesForDate(
    DateTime date,
  ) async {
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
    String bibleVersion = 'rsvce',
  }) {
    final match = _resolvePsalmEntry(
      entries: entries,
      psalmReference: psalmReference,
      positionLabel: positionLabel,
      psalmSequence: psalmSequence,
    );
    if (match == null) return null;

    // The response belongs to the lectionary selection, not the user's Bible
    // preference. [bibleVersion] remains temporarily for API compatibility.
    final response = match.refrainText.trim();
    if (response.isEmpty) {
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

    final standardEntries = await _readingCatalogService.loadStandardEntries();
    final parsed = <LectionaryPsalmCatalogEntry>[];

    // Primary: rows from the standard lectionary CSV.
    for (final entry in standardEntries) {
      parsed.add(
        LectionaryPsalmCatalogEntry(
          season: entry.season,
          week: entry.week,
          day: entry.day,
          weekdayCycle: entry.weekdayCycle,
          sundayCycle: entry.sundayCycle,
          fullReference: entry.psalmReference,
          refrainText: entry.psalmResponse,
          refrainTextRsvce:
              '', // Standard entries don't have version-specific data yet
          refrainTextNabre:
              '', // Standard entries don't have version-specific data yet
          acclamationRef: entry.acclamationRef,
          acclamationText: entry.acclamationText,
          lectionaryNumber: entry.lectionaryNumber,
        ),
      );
    }

    // Supplementary: rows from lectionary_psalms.csv and
    // lectionary_psalms_weekday.csv. These files preserve the lectionary
    // "(R. Xx)" verse refrain notation and cleaner acclamation text that
    // the primary CSV drops/pollutes.
    parsed.addAll(await _loadSupplementary('lectionary_psalms.csv'));
    parsed.addAll(await _loadSupplementary('lectionary_psalms_weekday.csv'));

    final filtered = parsed.where((entry) {
      return entry.fullReference.trim().isNotEmpty ||
          entry.acclamationText.trim().isNotEmpty;
    }).toList();

    _entries = filtered;
    return filtered;
  }

  Future<List<LectionaryPsalmCatalogEntry>> _loadSupplementary(
    String asset,
  ) async {
    try {
      final rawCsv = await rootBundle.loadString(asset);
      final lines = rawCsv
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.length <= 1) return const [];

      final out = <LectionaryPsalmCatalogEntry>[];
      // Header: Season,Week,Day,Weekday Cycle,Sunday Cycle,Full Reference,
      //         Refrain Text,Refrain Text RSVCE,Refrain Text NABRE,
      //         Acclamation Ref,Acclamation Text,Lectionary Number
      for (var i = 1; i < lines.length; i++) {
        final rawCols = _readingCatalogService.parseCsvLine(lines[i]);
        final hasVersionSpecific = rawCols.length >= 12;
        final cols = List<String>.from(rawCols);
        while (cols.length < 12) {
          cols.add('');
        }
        out.add(
          LectionaryPsalmCatalogEntry(
            season: cols[0].trim(),
            week: cols[1].trim(),
            day: cols[2].trim(),
            weekdayCycle: cols[3].trim(),
            sundayCycle: cols[4].trim(),
            fullReference: cols[5].trim(),
            refrainText: cols[6].trim(),
            refrainTextRsvce: hasVersionSpecific ? cols[7].trim() : '',
            refrainTextNabre: hasVersionSpecific ? cols[8].trim() : '',
            acclamationRef: hasVersionSpecific
                ? cols[9].trim()
                : cols[7].trim(),
            acclamationText: hasVersionSpecific
                ? cols[10].trim()
                : cols[8].trim(),
            lectionaryNumber: hasVersionSpecific
                ? cols[11].trim()
                : cols[9].trim(),
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('Supplementary psalm catalog missing ($asset): $e');
      return const [];
    }
  }

  /// Returns the richest catalog entry for [date] / [psalmReference]:
  /// the one whose [fullReference] contains a "(R. Xx)" verse refrain notation
  /// (allowing us to decode the refrain from RSVCE). Falls back to the first
  /// non-R entry when no R-bearing match is found.
  Future<LectionaryPsalmCatalogEntry?> getBestPsalmEntryForDate({
    required DateTime date,
    required String psalmReference,
    String? positionLabel,
    int? psalmSequence,
  }) async {
    final matches = await getEntriesForDate(date);
    if (matches.isEmpty) return null;

    return _resolvePsalmEntry(
      entries: matches,
      psalmReference: psalmReference,
      positionLabel: positionLabel,
      psalmSequence: psalmSequence,
    );
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
      return normalizedSeason == 'holy week' &&
          normalizedDay == 'holy thursday';
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
      return season == 'holy week' &&
          entry.day.trim().toLowerCase() == 'palm sunday';
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
    final queryRNotation = _extractRNotation(normalizedReference);
    final normalizedSelection = _stripRNotation(normalizedReference);

    // Match the biblical selection first, then prefer the richer
    // supplementary row that carries the lectionary's (R. ...) notation.
    // This keeps exact canticles such as Deut 32 on their primary row while
    // preserving refrains for psalms represented in both catalogs.
    final exactSelectionMatches = entries.where((entry) {
      final candidate = _normalizeReference(entry.fullReference);
      return _stripRNotation(candidate) == normalizedSelection;
    }).toList();
    if (exactSelectionMatches.isNotEmpty) {
      if (queryRNotation != null) {
        final exactResponseMatches = exactSelectionMatches.where((entry) {
          return _extractRNotation(_normalizeReference(entry.fullReference)) ==
              queryRNotation;
        }).toList();
        if (exactResponseMatches.isNotEmpty) {
          return exactResponseMatches.first;
        }
      } else {
        final richerMatches = exactSelectionMatches.where((entry) {
          return _extractRNotation(_normalizeReference(entry.fullReference)) !=
              null;
        }).toList();
        if (richerMatches.isNotEmpty) {
          return richerMatches.first;
        }
      }
      return exactSelectionMatches.first;
    }

    // Try to match entries with the same R. notation
    if (queryRNotation != null) {
      final rNotationMatches = entries.where((entry) {
        final candidate = _normalizeReference(entry.fullReference);
        final entryRNotation = _extractRNotation(candidate);
        return entryRNotation == queryRNotation &&
            (_stripRNotation(candidate).contains(normalizedSelection) ||
                normalizedSelection.contains(_stripRNotation(candidate)));
      }).toList();
      if (rNotationMatches.isNotEmpty) {
        return rNotationMatches.first;
      }
    }

    // Fallback to loose matching only if no R. notation is involved
    // This prevents false matches like R.7 matching R.7a
    if (queryRNotation == null) {
      final looseMatches = entries.where((entry) {
        final candidate = _normalizeReference(entry.fullReference);
        final candidateSelection = _stripRNotation(candidate);
        return candidateSelection.contains(normalizedSelection) ||
            normalizedSelection.contains(candidateSelection);
      }).toList();
      if (looseMatches.isNotEmpty) {
        return looseMatches.firstWhere(
          (entry) =>
              _extractRNotation(_normalizeReference(entry.fullReference)) !=
              null,
          orElse: () => looseMatches.first,
        );
      }
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

    // A date match alone is not enough to identify a responsorial psalm.
    // Returning an arbitrary same-day entry here can attach an unrelated
    // refrain when a canticle is absent from a supplementary catalog.
    return null;
  }

  /// Extracts the (R. ...) notation from a normalized reference
  /// Returns null if no notation is present
  String? _extractRNotation(String normalizedReference) {
    final match = RegExp(
      r'\(r\.[^)]*\)',
      caseSensitive: false,
    ).firstMatch(normalizedReference);
    return match?.group(0);
  }

  String _stripRNotation(String normalizedReference) => normalizedReference
      .replaceAll(RegExp(r'\(r\.[^)]*\)', caseSensitive: false), '');

  String _normalizeReference(String value) {
    var normalized = value
        .toLowerCase()
        .replaceAll('psalm', 'ps')
        .replaceFirst(RegExp(r'^(?:deuteronomy|dt)\s*'), 'deut')
        .replaceAll('see ', '')
        .replaceAll('cf. ', '')
        .replaceAll('cf ', '');

    // DO NOT remove (R. ...) notation - it's critical for distinguishing response verses
    // R.7, R.7a, R.7ac are different and must be preserved
    // Only remove spaces, but keep commas, colons, semicolons, hyphens, and periods
    // These are needed to distinguish verse ranges (e.g., 2-3, 6-7 vs 2-3, 16-17)
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    normalized = normalized.replaceFirstMapped(
      RegExp(r'^([1-3]?[a-z]+)(\d+)[.:]'),
      (match) => '${match.group(1)}${match.group(2)}:',
    );
    final responseIndex = normalized.indexOf('(r.');
    final selection = responseIndex == -1
        ? normalized
        : normalized.substring(0, responseIndex);
    final response = responseIndex == -1
        ? ''
        : normalized.substring(responseIndex);
    normalized =
        selection.replaceAllMapped(
          RegExp(r'(?<=[0-9a-z])[.;](?=\d)'),
          (_) => ',',
        ) +
        response;

    return normalized;
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
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
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
