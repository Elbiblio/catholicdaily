import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/liturgical_region.dart';
import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_preferences.dart';
import 'feast_reminder_service.dart';

class FeastNotificationCatalogOccurrence {
  const FeastNotificationCatalogOccurrence({
    required this.occurrenceKey,
    required this.notificationId,
  });

  final String occurrenceKey;
  final int notificationId;

  Map<String, Object> toJson() => <String, Object>{
    'occurrence_key': occurrenceKey,
    'notification_id': notificationId,
  };

  factory FeastNotificationCatalogOccurrence.fromJson(
    Map<String, dynamic> json,
  ) => FeastNotificationCatalogOccurrence(
    occurrenceKey: json['occurrence_key'] as String,
    notificationId: json['notification_id'] as int,
  );
}

class FeastNotificationCatalogEvent {
  const FeastNotificationCatalogEvent({
    required this.region,
    required this.date,
    required this.title,
    required this.rank,
    required this.celebrationId,
    required this.onDay,
    required this.eve,
  });

  final String region;
  final DateTime date;
  final String title;
  final String rank;
  final String celebrationId;
  final FeastNotificationCatalogOccurrence onDay;
  final FeastNotificationCatalogOccurrence eve;

  Map<String, Object> toJson() => <String, Object>{
    'region': region,
    'date': _formatDate(date),
    'title': title,
    'rank': rank,
    'celebration_id': celebrationId,
    'on_day': onDay.toJson(),
    'eve': eve.toJson(),
  };

  factory FeastNotificationCatalogEvent.fromJson(Map<String, dynamic> json) =>
      FeastNotificationCatalogEvent(
        region: json['region'] as String,
        date: DateTime.parse(json['date'] as String),
        title: json['title'] as String,
        rank: json['rank'] as String,
        celebrationId: json['celebration_id'] as String,
        onDay: FeastNotificationCatalogOccurrence.fromJson(
          json['on_day'] as Map<String, dynamic>,
        ),
        eve: FeastNotificationCatalogOccurrence.fromJson(
          json['eve'] as Map<String, dynamic>,
        ),
      );
}

class FeastNotificationCatalog {
  const FeastNotificationCatalog({
    required this.schema,
    required this.scheduleGeneration,
    required this.startDate,
    required this.endDate,
    required this.sha256Digest,
    required this.events,
  });

  final int schema;
  final String scheduleGeneration;
  final DateTime startDate;
  final DateTime endDate;
  final String sha256Digest;
  final List<FeastNotificationCatalogEvent> events;

  String get computedDigest =>
      sha256.convert(utf8.encode(jsonEncode(_eventMaps(events)))).toString();

  bool get hasValidDigest =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256Digest) &&
      sha256Digest == computedDigest;

  Map<String, Object> toJson() => <String, Object>{
    'schema': schema,
    'schedule_generation': scheduleGeneration,
    'start_date': _formatDate(startDate),
    'end_date': _formatDate(endDate),
    'sha256': sha256Digest,
    'events': _eventMaps(events),
  };

  String canonicalJson() => jsonEncode(toJson());

  factory FeastNotificationCatalog.fromJson(Map<String, dynamic> json) =>
      FeastNotificationCatalog(
        schema: json['schema'] as int,
        scheduleGeneration: json['schedule_generation'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        sha256Digest: json['sha256'] as String,
        events: (json['events'] as List<dynamic>)
            .map(
              (event) => FeastNotificationCatalogEvent.fromJson(
                event as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
      );

  static List<Map<String, Object>> _eventMaps(
    List<FeastNotificationCatalogEvent> events,
  ) => events.map((event) => event.toJson()).toList(growable: false);
}

class FeastNotificationCatalogBuilder {
  FeastNotificationCatalogBuilder({FeastReminderService? reminderService})
    : _reminderService = reminderService ?? FeastReminderService.instance;

  final FeastReminderService _reminderService;

  Future<FeastNotificationCatalog> build({
    required int startYear,
    required int endYear,
  }) async {
    if (startYear > endYear) {
      throw ArgumentError.value(
        startYear,
        'startYear',
        'must not be after endYear',
      );
    }

    final events = <FeastNotificationCatalogEvent>[];
    final regions = List<LiturgicalRegion>.of(LiturgicalRegion.selectable)
      ..sort((left, right) => left.name.compareTo(right.name));

    for (final region in regions) {
      for (var year = startYear; year <= endYear; year++) {
        final previews = await _reminderService.buildCatalogEventsForYear(
          year,
          FeastReminderRank.all,
          region: region,
        );
        for (final preview in previews) {
          final celebrationSource = preview.saintProfileId ?? preview.title;
          final onDayIdentity = FeastReminderNotificationContract.identity(
            region: region.name,
            celebrationDate: preview.date,
            dayBefore: false,
            celebrationId: celebrationSource,
          );
          final eveIdentity = FeastReminderNotificationContract.identity(
            region: region.name,
            celebrationDate: preview.date,
            dayBefore: true,
            celebrationId: celebrationSource,
          );
          events.add(
            FeastNotificationCatalogEvent(
              region: region.name,
              date: DateTime(
                preview.date.year,
                preview.date.month,
                preview.date.day,
              ),
              title: preview.title.trim(),
              rank: _normalizeRank(preview.rank),
              celebrationId: _celebrationIdFrom(onDayIdentity.occurrenceKey),
              onDay: FeastNotificationCatalogOccurrence(
                occurrenceKey: onDayIdentity.occurrenceKey,
                notificationId: onDayIdentity.notificationId,
              ),
              eve: FeastNotificationCatalogOccurrence(
                occurrenceKey: eveIdentity.occurrenceKey,
                notificationId: eveIdentity.notificationId,
              ),
            ),
          );
        }
      }
    }

    events.sort(_compareEvents);
    final digest = sha256
        .convert(
          utf8.encode(jsonEncode(FeastNotificationCatalog._eventMaps(events))),
        )
        .toString();
    return FeastNotificationCatalog(
      schema: 1,
      scheduleGeneration: FeastReminderNotificationContract.scheduleGeneration,
      startDate: DateTime(startYear, 1, 1),
      endDate: DateTime(endYear, 12, 31),
      sha256Digest: digest,
      events: List<FeastNotificationCatalogEvent>.unmodifiable(events),
    );
  }

  static String _celebrationIdFrom(String occurrenceKey) =>
      occurrenceKey.substring(occurrenceKey.lastIndexOf(':') + 1);

  static String _normalizeRank(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('optional')) return 'optional_memorial';
    if (normalized.contains('memorial')) return 'memorial';
    if (normalized.contains('solemnity')) return 'solemnity';
    if (normalized.contains('feast')) return 'feast';
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  static int _compareEvents(
    FeastNotificationCatalogEvent left,
    FeastNotificationCatalogEvent right,
  ) {
    final byRegion = left.region.compareTo(right.region);
    if (byRegion != 0) return byRegion;
    final byDate = left.date.compareTo(right.date);
    if (byDate != 0) return byDate;
    final byRank = left.rank.compareTo(right.rank);
    if (byRank != 0) return byRank;
    final byId = left.celebrationId.compareTo(right.celebrationId);
    if (byId != 0) return byId;
    return left.title.compareTo(right.title);
  }
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
