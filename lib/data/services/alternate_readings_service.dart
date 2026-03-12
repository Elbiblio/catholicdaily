import 'package:flutter/foundation.dart';
import '../models/daily_reading.dart';
import 'optional_memorial_service.dart';
import 'readings_backend_io.dart';

/// Represents a set of readings for a particular celebration option on a given day.
class CelebrationReadingSet {
  /// The celebration this reading set belongs to (null = ferial/weekday)
  final OptionalCelebration? celebration;

  /// The readings for this celebration
  final List<DailyReading> readings;

  /// Display label (e.g., "Weekday", "St. Patrick, Bishop")
  final String label;

  /// Whether this is the default/ferial option
  final bool isFerial;

  const CelebrationReadingSet({
    this.celebration,
    required this.readings,
    required this.label,
    this.isFerial = false,
  });
}

/// Service that resolves all available reading sets for a given day,
/// including the ferial (weekday) readings and any optional memorial readings.
///
/// Liturgical rules for optional memorials:
/// - The priest may choose to celebrate the optional memorial OR the ferial day
/// - If the optional memorial has proper readings, those readings are used
/// - If the optional memorial has no proper readings, the weekday readings are used
///   (but the collect prayer changes — not relevant for a readings app)
/// - During Lent, optional memorials are suppressed
/// - Some optional memorials share a date (e.g., Jan 20: St. Fabian OR St. Sebastian)
class AlternateReadingsService {
  static final AlternateReadingsService instance = AlternateReadingsService._();
  AlternateReadingsService._();

  final OptionalMemorialService _memorialService = OptionalMemorialService.instance;
  final ReadingsBackendIo _readingsBackend = ReadingsBackendIo();

  /// Get all available reading sets for a given date.
  /// Returns at least one set (the ferial/weekday readings).
  /// May return additional sets for optional memorials with proper readings.
  Future<List<CelebrationReadingSet>> getAvailableReadingSets(DateTime date) async {
    final sets = <CelebrationReadingSet>[];

    // 1. Always include the ferial (weekday) readings
    try {
      final ferialReadings = await _readingsBackend.getReadingsForDate(date);
      sets.add(CelebrationReadingSet(
        readings: ferialReadings,
        label: _buildFerialLabel(date),
        isFerial: true,
      ));
    } catch (e) {
      debugPrint('Error loading ferial readings: $e');
    }

    // 2. Check for celebrations on this date. We include commemorated days too,
    // so the UI can still offer an alternate set where local practice allows it.
    final optionalCelebrations = _memorialService.getAllCelebrationsForDate(date);

    for (final celebration in optionalCelebrations) {
      final properReadings = _memorialService.getProperReadings(celebration.id);

      if (properReadings != null) {
        // This celebration has proper readings — create a distinct reading set
        final readings = _buildReadingsFromProperSet(
          date: date,
          readingSet: properReadings,
          celebration: celebration,
        );
        sets.add(CelebrationReadingSet(
          celebration: celebration,
          readings: readings,
          label: celebration.title,
        ));
      } else {
        // No proper readings — uses weekday readings with different collect
        // Still list the celebration as an option for display purposes
        sets.add(CelebrationReadingSet(
          celebration: celebration,
          readings: sets.isNotEmpty ? sets.first.readings : [],
          label: '${celebration.title} (weekday readings)',
        ));
      }
    }

    return sets;
  }

  /// Check if a date has alternate reading options
  Future<bool> hasAlternateReadings(DateTime date) async {
    return _memorialService.getAllCelebrationsForDate(date).isNotEmpty;
  }

  /// Get just the list of optional celebrations for display (no reading fetching)
  List<OptionalCelebration> getOptionalCelebrations(DateTime date) {
    return _memorialService.getAllCelebrationsForDate(date);
  }

  List<DailyReading> _buildReadingsFromProperSet({
    required DateTime date,
    required ProperReadingSet readingSet,
    required OptionalCelebration celebration,
  }) {
    final readings = <DailyReading>[];

    // First Reading
    readings.add(DailyReading(
      reading: readingSet.firstReading,
      position: 'First Reading',
      date: date,
      feast: celebration.title,
    ));

    // Alternative First Reading (if available)
    if (readingSet.alternativeFirstReading != null) {
      readings.add(DailyReading(
        reading: readingSet.alternativeFirstReading!,
        position: 'First Reading (alternative)',
        date: date,
        feast: celebration.title,
      ));
    }

    // Responsorial Psalm
    readings.add(DailyReading(
      reading: readingSet.psalm,
      position: 'Responsorial Psalm',
      date: date,
      feast: celebration.title,
      psalmResponse: readingSet.psalmResponse,
    ));

    // Second Reading (only for Solemnities/Feasts)
    if (readingSet.secondReading != null) {
      readings.add(DailyReading(
        reading: readingSet.secondReading!,
        position: 'Second Reading',
        date: date,
        feast: celebration.title,
      ));
    }

    // Gospel
    readings.add(DailyReading(
      reading: readingSet.gospel,
      position: 'Gospel',
      date: date,
      feast: celebration.title,
      gospelAcclamation: readingSet.gospelAcclamation,
    ));

    // Alternative Gospel (if available)
    if (readingSet.alternativeGospel != null) {
      readings.add(DailyReading(
        reading: readingSet.alternativeGospel!,
        position: 'Gospel (alternative)',
        date: date,
        feast: celebration.title,
        gospelAcclamation: readingSet.gospelAcclamation,
      ));
    }

    return readings;
  }

  String _buildFerialLabel(DateTime date) {
    final weekday = _weekdayName(date.weekday);
    return '$weekday — Weekday';
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }
}
