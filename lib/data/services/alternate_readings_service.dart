import 'package:flutter/foundation.dart';
import '../models/daily_reading.dart';
import 'csv_readings_resolver_service.dart';
import 'optional_memorial_service.dart';
import 'ordo_resolver_service.dart';
import 'reading_catalog_service.dart';
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
  final ReadingCatalogService _catalog = ReadingCatalogService.instance;

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

    final weekdayReadings = await _csvResolver.resolveWeekday(date);
    final resolvedCatalogEntry = resolvedDay.title.trim().isEmpty
        ? null
        : await _catalog.findMemorialEntry(
            celebrationId: '',
            celebrationTitle: resolvedDay.title,
          );
    final primaryUsesWeekday =
        sets.isNotEmpty &&
        weekdayReadings.isNotEmpty &&
        _sameReadings(sets.first.readings, weekdayReadings);
    final resolvedRank = (resolvedDay.rank ?? '').toLowerCase();
    if (sets.isNotEmpty &&
        !primaryUsesWeekday &&
        resolvedRank.contains('memorial') &&
        resolvedCatalogEntry != null) {
      sets[0] = CelebrationReadingSet(
        readings: sets.first.readings,
        label: _properLabel(resolvedDay.title, sets.first.readings),
      );
      final weekdayFirstReading = _weekdayFirstReadingWithProperGospel(
        weekdayReadings: weekdayReadings,
        properReadings: sets.first.readings,
      );
      if (weekdayFirstReading.isNotEmpty) {
        final hybrid = CelebrationReadingSet(
          readings: weekdayFirstReading,
          label:
              '${resolvedDay.title} — Weekday first reading${_sourceEditionSuffix(weekdayFirstReading)}',
        );
        if (_hasDatedNigeriaMissalSource(weekdayFirstReading)) {
          sets.insert(0, hybrid);
        } else {
          sets.insert(1, hybrid);
        }
      }
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

      if (resolvedCatalogEntry?.commonType.trim().isNotEmpty == true) {
        await _addCommonChoices(
          sets: sets,
          date: date,
          celebrationTitle: resolvedDay.title,
          commonType: resolvedCatalogEntry!.commonType,
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
        _addDistinctSet(
          sets,
          CelebrationReadingSet(
            celebration: celebration,
            readings: readings,
            label: _properLabel(celebration.title, readings),
          ),
        );
      } else {
        // No verified proper readings: the memorial legitimately retains the
        // weekday references, with its choice clearly labelled.
        _addDistinctSet(
          sets,
          CelebrationReadingSet(
            celebration: celebration,
            readings: weekdayReadings,
            label: '${celebration.title} (weekday readings)',
          ),
        );
      }
      if (celebration.commonType?.trim().isNotEmpty == true) {
        await _addCommonChoices(
          sets: sets,
          date: date,
          celebrationTitle: celebration.title,
          commonType: celebration.commonType!,
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

  Future<void> _addCommonChoices({
    required List<CelebrationReadingSet> sets,
    required DateTime date,
    required String celebrationTitle,
    required String commonType,
  }) async {
    final commonChoices = await _csvResolver.resolveCommonChoices(
      date: date,
      commonType: commonType,
    );
    for (final choice in commonChoices) {
      _addDistinctSet(
        sets,
        CelebrationReadingSet(
          readings: choice.readings,
          label: '$celebrationTitle — ${choice.label}',
        ),
      );
    }
  }

  void _addDistinctSet(
    List<CelebrationReadingSet> sets,
    CelebrationReadingSet candidate,
  ) {
    if (candidate.readings.isEmpty ||
        sets.any((set) => _sameReadings(set.readings, candidate.readings))) {
      return;
    }
    sets.add(candidate);
  }

  List<DailyReading> _weekdayFirstReadingWithProperGospel({
    required List<DailyReading> weekdayReadings,
    required List<DailyReading> properReadings,
  }) {
    if (weekdayReadings.isEmpty || properReadings.isEmpty) return const [];
    final weekdayBeforeGospel = weekdayReadings
        .where(
          (reading) =>
              !(reading.position ?? '').toLowerCase().contains('gospel'),
        )
        .toList();
    final properGospels = properReadings
        .where(
          (reading) =>
              (reading.position ?? '').toLowerCase().contains('gospel'),
        )
        .toList();
    if (weekdayBeforeGospel.isEmpty || properGospels.isEmpty) return const [];
    return <DailyReading>[...weekdayBeforeGospel, ...properGospels];
  }

  String _properLabel(String title, List<DailyReading> readings) {
    final edition = _sourceEdition(readings);
    return edition.isEmpty ? title : '$title — Proper ($edition)';
  }

  String _sourceEditionSuffix(List<DailyReading> readings) {
    final edition = _sourceEdition(readings);
    return edition.isEmpty ? '' : ' ($edition)';
  }

  String _sourceEdition(List<DailyReading> readings) {
    for (final reading in readings) {
      final source = reading.source ?? '';
      final parts = source.split('|');
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        return parts[1].trim();
      }
    }
    return '';
  }

  bool _hasDatedNigeriaMissalSource(List<DailyReading> readings) =>
      readings.any((reading) {
        final source = reading.source ?? '';
        final parts = source.split('|');
        return parts.length > 3 &&
            parts[1] == 'Catholic Missal for Nigeria' &&
            parts[3].isNotEmpty;
      });

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
