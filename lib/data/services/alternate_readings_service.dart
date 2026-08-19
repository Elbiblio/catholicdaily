import 'package:flutter/foundation.dart';
import '../models/daily_reading.dart';
import 'csv_readings_resolver_service.dart';
import 'optional_memorial_service.dart';
import 'ordo_resolver_service.dart';
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

  final OptionalMemorialService _memorialService =
      OptionalMemorialService.instance;
  final ReadingsBackendIo _readingsBackend = ReadingsBackendIo();
  final CsvReadingsResolverService _csvResolver =
      CsvReadingsResolverService.instance;
  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;

  /// Get all available reading sets for a given date.
  /// Returns at least one set. The resolved celebration is always first;
  /// additional legitimate Vigil, weekday, memorial, and common choices follow.
  Future<List<CelebrationReadingSet>> getAvailableReadingSets(
    DateTime date,
  ) async {
    final sets = <CelebrationReadingSet>[];
    final resolvedDay = await _ordoResolver.resolveDay(date);

    // 1. The calendar-resolved celebration is always the primary set.
    try {
      final primaryReadings = await _readingsBackend.getReadingsForDate(date);
      sets.add(
        CelebrationReadingSet(
          readings: primaryReadings,
          label: resolvedDay.title.trim().isEmpty
              ? _buildFerialLabel(date)
              : resolvedDay.title.trim(),
          isFerial: resolvedDay.title.trim().isEmpty,
        ),
      );
    } catch (e) {
      debugPrint('Error loading primary readings: $e');
    }

    // 2. Add an explicitly labelled Vigil where the canonical catalog has one.
    if (resolvedDay.title.trim().isNotEmpty) {
      final vigilReadings = await _csvResolver.resolveVigilChoice(
        date: date,
        celebrationTitle: resolvedDay.title,
      );
      if (vigilReadings.isNotEmpty) {
        sets.add(
          CelebrationReadingSet(
            readings: vigilReadings,
            label: '${resolvedDay.title} — Vigil Mass',
          ),
        );
      }

      final otherMassChoices = await _csvResolver.resolveOtherMassChoices(
        date: date,
        celebrationTitle: resolvedDay.title,
      );
      for (final choice in otherMassChoices) {
        sets.add(
          CelebrationReadingSet(readings: choice.readings, label: choice.label),
        );
      }
    }

    // Vigils belong to the evening before a solemnity. The civil-date page
    // therefore needs to look ahead instead of depending on today's title.
    final tomorrow = date.add(const Duration(days: 1));
    final tomorrowDay = await _ordoResolver.resolveDay(tomorrow);
    if (tomorrowDay.title.trim().isNotEmpty) {
      final eveReadings = await _csvResolver.resolveVigilChoice(
        date: date,
        celebrationTitle: tomorrowDay.title,
      );
      final alreadyIncluded = sets.any(
        (set) => _sameReadings(set.readings, eveReadings),
      );
      if (eveReadings.isNotEmpty && !alreadyIncluded) {
        sets.add(
          CelebrationReadingSet(
            readings: eveReadings,
            label: '${tomorrowDay.title} — Vigil Mass',
          ),
        );
      }
    }

    // 3. Keep the underlying weekday/temporal set available after the primary
    // celebration. Never mislabel the primary celebration itself as ferial.
    final weekdayReadings = await _csvResolver.resolveWeekday(date);
    final primaryUsesWeekday =
        sets.isNotEmpty &&
        weekdayReadings.isNotEmpty &&
        _sameReadings(sets.first.readings, weekdayReadings);
    final resolvedRank = (resolvedDay.rank ?? '').toLowerCase();
    if (primaryUsesWeekday &&
        (resolvedDay.title.trim().isEmpty ||
            resolvedRank.contains('memorial'))) {
      sets[0] = CelebrationReadingSet(
        readings: sets.first.readings,
        label: resolvedDay.title.trim().isEmpty
            ? _buildFerialLabel(date)
            : '${resolvedDay.title.trim()} — Weekday readings',
        isFerial: true,
      );
    }
    if (weekdayReadings.isNotEmpty && (sets.isEmpty || !primaryUsesWeekday)) {
      sets.add(
        CelebrationReadingSet(
          readings: weekdayReadings,
          label: _buildFerialLabel(date),
          isFerial: true,
        ),
      );
    }

    // 4. Include every fixed memorial/feast choice for easy access, while
    // obtaining scripture references from the canonical resolver.
    final optionalCelebrations = _memorialService.getAllCelebrationsForDate(
      date,
    );

    for (final celebration in optionalCelebrations) {
      if (_normalizeTitle(celebration.title) ==
              _normalizeTitle(resolvedDay.title) &&
          !primaryUsesWeekday) {
        continue;
      }

      final readings = await _csvResolver.resolveCelebrationChoice(
        date: date,
        celebrationId: celebration.id,
        celebrationTitle: celebration.title,
      );
      if (readings.isNotEmpty) {
        sets.add(
          CelebrationReadingSet(
            celebration: celebration,
            readings: readings,
            label: celebration.title,
          ),
        );
      } else {
        // No verified proper readings: the memorial legitimately retains the
        // weekday references, with its choice clearly labelled.
        sets.add(
          CelebrationReadingSet(
            celebration: celebration,
            readings: weekdayReadings,
            label: '${celebration.title} (weekday readings)',
          ),
        );
      }
    }

    return sets;
  }

  /// Check if a date has alternate reading options
  Future<bool> hasAlternateReadings(DateTime date) async {
    return (await getAvailableReadingSets(date)).length > 1;
  }

  /// Get just the list of optional celebrations for display (no reading fetching)
  List<OptionalCelebration> getOptionalCelebrations(DateTime date) {
    return _memorialService.getAllCelebrationsForDate(date);
  }

  String _buildFerialLabel(DateTime date) {
    final weekday = _weekdayName(date.weekday);
    return '$weekday — Weekday';
  }

  bool _sameReadings(List<DailyReading> left, List<DailyReading> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].reading.trim() != right[i].reading.trim() ||
          (left[i].position ?? '').trim() != (right[i].position ?? '').trim()) {
        return false;
      }
    }
    return true;
  }

  String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

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
