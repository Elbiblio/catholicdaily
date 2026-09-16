import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_reading.dart';
import 'alternate_readings_service.dart';
import 'improved_liturgical_calendar_service.dart';
import 'optional_memorial_service.dart';
import 'ordo_resolver_service.dart';

/// The complete data set rendered by the daily browse view.
///
/// This deliberately excludes derived presentation state.  A cache hit is only
/// usable when every domain object needed for the initial reading choice can be
/// reconstructed; otherwise callers discard it and use the live resolver.
class DailyBrowseSnapshotPayload {
  const DailyBrowseSnapshotPayload({
    required this.liturgicalDay,
    required this.ordoYearVariables,
    required this.celebrationsSuppressed,
    required this.saintCelebrations,
    required this.readingSets,
    required this.selectedReadingSetIndex,
    required this.readings,
    required this.readingTexts,
    required this.readingPreviews,
  });

  final LiturgicalDay liturgicalDay;
  final OrdoYearVariables ordoYearVariables;
  final bool celebrationsSuppressed;
  final List<OptionalCelebration> saintCelebrations;
  final List<CelebrationReadingSet> readingSets;
  final int selectedReadingSetIndex;
  final List<DailyReading> readings;
  final Map<String, String> readingTexts;
  final Map<String, String> readingPreviews;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'liturgical_day': <String, dynamic>{
      'date': liturgicalDay.date.toIso8601String(),
      'title': liturgicalDay.title,
      'rank': liturgicalDay.rank,
      'color': liturgicalDay.color.name,
      'season': liturgicalDay.season.name,
      'week_number': liturgicalDay.weekNumber,
      'day_of_week': liturgicalDay.dayOfWeek.name,
    },
    'ordo_year_variables': <String, dynamic>{
      'year': ordoYearVariables.year,
      'golden_number': ordoYearVariables.goldenNumber,
      'epact': ordoYearVariables.epact,
      'solar_cycle': ordoYearVariables.solarCycle,
      'indiction': ordoYearVariables.indiction,
      'julian_period_year': ordoYearVariables.julianPeriodYear,
      'years_since_ignatius': ordoYearVariables.yearsSinceIgnatius,
      'sunday_cycle': ordoYearVariables.sundayCycle,
      'weekday_cycle': ordoYearVariables.weekdayCycle,
    },
    'celebrations_suppressed': celebrationsSuppressed,
    'saint_celebrations': saintCelebrations.map(_celebrationToJson).toList(),
    'reading_sets': readingSets
        .map(
          (set) => <String, dynamic>{
            'celebration': set.celebration == null
                ? null
                : _celebrationToJson(set.celebration!),
            'readings': set.readings.map((reading) => reading.toMap()).toList(),
            'label': set.label,
            'is_ferial': set.isFerial,
          },
        )
        .toList(),
    'selected_reading_set_index': selectedReadingSetIndex,
    'readings': readings.map((reading) => reading.toMap()).toList(),
    'reading_texts': readingTexts,
    'reading_previews': readingPreviews,
  };

  static DailyBrowseSnapshotPayload? tryFromJson(Map<String, dynamic> json) {
    try {
      final liturgicalDayJson = _map(json['liturgical_day']);
      final ordoJson = _map(json['ordo_year_variables']);
      final liturgicalDay = LiturgicalDay(
        date: DateTime.parse(_string(liturgicalDayJson['date'])),
        title: _string(liturgicalDayJson['title']),
        rank: liturgicalDayJson['rank'] as String?,
        color: LiturgicalColor.values.byName(
          _string(liturgicalDayJson['color']),
        ),
        season: LiturgicalSeason.values.byName(
          _string(liturgicalDayJson['season']),
        ),
        weekNumber: _int(liturgicalDayJson['week_number']),
        dayOfWeek: DayOfWeek.values.byName(
          _string(liturgicalDayJson['day_of_week']),
        ),
      );
      final ordo = OrdoYearVariables(
        year: _int(ordoJson['year']),
        goldenNumber: _int(ordoJson['golden_number']),
        epact: _string(ordoJson['epact']),
        solarCycle: _int(ordoJson['solar_cycle']),
        indiction: _int(ordoJson['indiction']),
        julianPeriodYear: _int(ordoJson['julian_period_year']),
        yearsSinceIgnatius: _int(ordoJson['years_since_ignatius']),
        sundayCycle: _string(ordoJson['sunday_cycle']),
        weekdayCycle: _string(ordoJson['weekday_cycle']),
      );
      final saintCelebrations = _list(json['saint_celebrations'])
          .map((value) => _celebrationFromJson(_map(value)))
          .toList(growable: false);
      final readingSets = _list(json['reading_sets'])
          .map((value) {
            final set = _map(value);
            final rawCelebration = set['celebration'];
            return CelebrationReadingSet(
              celebration: rawCelebration == null
                  ? null
                  : _celebrationFromJson(_map(rawCelebration)),
              readings: _list(set['readings'])
                  .map((reading) => DailyReading.fromMap(_map(reading)))
                  .toList(growable: false),
              label: _string(set['label']),
              isFerial: _bool(set['is_ferial']),
            );
          })
          .toList(growable: false);
      final selectedIndex = _int(json['selected_reading_set_index']);
      if (readingSets.isEmpty ||
          selectedIndex < 0 ||
          selectedIndex >= readingSets.length) {
        return null;
      }
      final readings = _list(json['readings'])
          .map((reading) => DailyReading.fromMap(_map(reading)))
          .toList(growable: false);
      final readingTexts = _stringMap(json['reading_texts']);
      final readingPreviews = _stringMap(json['reading_previews']);
      if (readings.any(
        (reading) => !readingTexts.containsKey(reading.reading),
      )) {
        return null;
      }
      return DailyBrowseSnapshotPayload(
        liturgicalDay: liturgicalDay,
        ordoYearVariables: ordo,
        celebrationsSuppressed: _bool(json['celebrations_suppressed']),
        saintCelebrations: saintCelebrations,
        readingSets: readingSets,
        selectedReadingSetIndex: selectedIndex,
        readings: readings,
        readingTexts: readingTexts,
        readingPreviews: readingPreviews,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _celebrationToJson(OptionalCelebration value) =>
      <String, dynamic>{
        'id': value.id,
        'title': value.title,
        'rank': value.rank.name,
        'color': value.color.name,
        'month': value.month,
        'day': value.day,
        'common_type': value.commonType,
      };

  static OptionalCelebration _celebrationFromJson(Map<String, dynamic> json) =>
      OptionalCelebration(
        id: _string(json['id']),
        title: _string(json['title']),
        rank: CelebrationRank.values.byName(_string(json['rank'])),
        color: LiturgicalColor.values.byName(_string(json['color'])),
        month: _int(json['month']),
        day: _int(json['day']),
        commonType: json['common_type'] as String?,
      );

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) throw const FormatException('Expected a JSON object');
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(dynamic value) {
    if (value is! List) throw const FormatException('Expected a JSON list');
    return value;
  }

  static String _string(dynamic value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Expected a non-empty string');
    }
    return value;
  }

  static int _int(dynamic value) {
    if (value is! int) throw const FormatException('Expected an integer');
    return value;
  }

  static bool _bool(dynamic value) {
    if (value is! bool) throw const FormatException('Expected a boolean');
    return value;
  }

  static Map<String, String> _stringMap(dynamic value) {
    final map = _map(value);
    if (map.values.any((entry) => entry is! String)) {
      throw const FormatException('Expected a string map');
    }
    return map.map((key, entry) => MapEntry(key, entry as String));
  }
}

class DailyBrowseSnapshotKey {
  const DailyBrowseSnapshotKey({
    required this.date,
    required this.region,
    required this.bibleVersion,
    required this.generation,
  });

  final DateTime date;
  final String region;
  final String bibleVersion;
  final String generation;

  String get value => '${_dateOnly(date)}|$region|$bibleVersion|$generation';

  Map<String, String> toJson() => <String, String>{
    'date': _dateOnly(date),
    'region': region,
    'bible_version': bibleVersion,
    'generation': generation,
  };

  static DailyBrowseSnapshotKey? fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse(json['date'] as String? ?? '');
    final region = json['region'] as String?;
    final bibleVersion = json['bible_version'] as String?;
    final generation = json['generation'] as String?;
    if (date == null ||
        region == null ||
        region.isEmpty ||
        bibleVersion == null ||
        bibleVersion.isEmpty ||
        generation == null ||
        generation.isEmpty) {
      return null;
    }
    return DailyBrowseSnapshotKey(
      date: DateTime(date.year, date.month, date.day),
      region: region,
      bibleVersion: bibleVersion,
      generation: generation,
    );
  }
}

class DailyBrowseSnapshot {
  const DailyBrowseSnapshot({required this.key, required this.payload});

  final DailyBrowseSnapshotKey key;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key.toJson(),
    'payload': payload,
  };

  static DailyBrowseSnapshot? fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final payload = json['payload'];
    if (key is! Map || payload is! Map) return null;
    final parsedKey = DailyBrowseSnapshotKey.fromJson(
      Map<String, dynamic>.from(key),
    );
    if (parsedKey == null) return null;
    return DailyBrowseSnapshot(
      key: parsedKey,
      payload: Map<String, dynamic>.from(payload),
    );
  }
}

class DailyBrowseSnapshotStore {
  DailyBrowseSnapshotStore({
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  @visibleForTesting
  DailyBrowseSnapshotStore.forTesting({
    required Future<SharedPreferences> Function() preferences,
    required DateTime Function() now,
  }) : _preferences = preferences,
       _now = now;

  static const storageKey = 'daily_browse_snapshots_v1';
  static const _schemaVersion = 1;
  static const _warmDays = 7;

  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;

  Future<DailyBrowseSnapshot?> read(DailyBrowseSnapshotKey key) async {
    final preferences = await _preferences();
    final snapshots = await _readDocument(preferences);
    final snapshot = snapshots[key.value];
    if (snapshot == null || !_isInWarmWindow(snapshot.key.date)) return null;
    return snapshot;
  }

  Future<void> save(DailyBrowseSnapshot snapshot) async {
    if (!_isInWarmWindow(snapshot.key.date)) return;
    final preferences = await _preferences();
    final snapshots = await _readDocument(preferences);
    snapshots[snapshot.key.value] = snapshot;
    snapshots.removeWhere((_, value) => !_isInWarmWindow(value.key.date));
    final document = <String, dynamic>{
      'version': _schemaVersion,
      'entries': snapshots.map((key, value) => MapEntry(key, value.toJson())),
    };
    await preferences.setString(storageKey, jsonEncode(document));
  }

  Future<void> remove(DailyBrowseSnapshotKey key) async {
    final preferences = await _preferences();
    final snapshots = await _readDocument(preferences);
    if (snapshots.remove(key.value) == null) return;
    final document = <String, dynamic>{
      'version': _schemaVersion,
      'entries': snapshots.map(
        (entryKey, value) => MapEntry(entryKey, value.toJson()),
      ),
    };
    await preferences.setString(storageKey, jsonEncode(document));
  }

  Future<Map<String, DailyBrowseSnapshot>> _readDocument(
    SharedPreferences preferences,
  ) async {
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return <String, DailyBrowseSnapshot>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['version'] != _schemaVersion) {
        throw const FormatException('Invalid daily browse snapshot document');
      }
      final entries = decoded['entries'];
      if (entries is! Map) throw const FormatException('Invalid entries');
      final snapshots = <String, DailyBrowseSnapshot>{};
      for (final entry in entries.entries) {
        if (entry.key is! String || entry.value is! Map) {
          throw const FormatException('Invalid snapshot entry');
        }
        final snapshot = DailyBrowseSnapshot.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (snapshot == null || snapshot.key.value != entry.key) {
          throw const FormatException('Invalid snapshot key');
        }
        snapshots[entry.key] = snapshot;
      }
      return snapshots;
    } on FormatException {
      await preferences.remove(storageKey);
      return <String, DailyBrowseSnapshot>{};
    } on TypeError {
      await preferences.remove(storageKey);
      return <String, DailyBrowseSnapshot>{};
    }
  }

  bool _isInWarmWindow(DateTime value) {
    final today = _dateAtMidnight(_now());
    final date = _dateAtMidnight(value);
    return !date.isBefore(today) &&
        !date.isAfter(today.add(const Duration(days: _warmDays)));
  }
}

DateTime _dateAtMidnight(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
