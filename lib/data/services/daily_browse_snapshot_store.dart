import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
