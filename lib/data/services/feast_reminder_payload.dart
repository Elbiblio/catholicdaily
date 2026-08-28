import 'dart:convert';

import 'feast_reminder_notification_contract.dart';
import 'improved_liturgical_calendar_service.dart';
import 'optional_memorial_service.dart';

class FeastReminderPayload {
  const FeastReminderPayload({
    required this.celebrationDate,
    this.scheduledFor,
    this.occurrenceKey,
    this.timeZone,
    this.liturgicalRegion,
    this.scheduleGeneration,
    this.remoteExpiresAt,
    this.localSafetyAt,
    this.localNotificationId,
    this.sourceSchemaVersion,
    required this.title,
    required this.rank,
    required this.saintProfileId,
    required this.dayBefore,
  });

  static const int schemaVersion = 3;

  final DateTime celebrationDate;
  final DateTime? scheduledFor;
  final String? occurrenceKey;
  final String? timeZone;
  final String? liturgicalRegion;
  final String? scheduleGeneration;
  final DateTime? remoteExpiresAt;
  final DateTime? localSafetyAt;
  final int? localNotificationId;
  final int? sourceSchemaVersion;
  final String title;
  final String rank;
  final String? saintProfileId;
  final bool dayBefore;

  OptionalCelebration? toSaintCelebration() {
    final profileId = saintProfileId;
    if (profileId == null || profileId.isEmpty || title.trim().isEmpty) {
      return null;
    }
    final normalizedRank = rank.trim().toLowerCase();
    return OptionalCelebration(
      id: profileId,
      title: title,
      rank: switch (normalizedRank) {
        'solemnity' => CelebrationRank.solemnity,
        'feast' => CelebrationRank.feast,
        'memorial' => CelebrationRank.obligatoryMemorial,
        _ => CelebrationRank.optionalMemorial,
      },
      color: _colorFromTitle(title),
      month: celebrationDate.month,
      day: celebrationDate.day,
      commonType: null,
    );
  }

  Map<String, dynamic> toMap() {
    final key = occurrenceKey;
    if (key == null || key.trim().isEmpty) {
      return {
        'type': 'feast',
        'v': 1,
        'date': _dateOnly(celebrationDate),
        'title': title,
        'rank': rank,
        if (saintProfileId != null) 'saintId': saintProfileId,
        'timing': dayBefore ? 'eve' : 'day',
      };
    }

    final scheduled = scheduledFor;
    if (sourceSchemaVersion == 2 || scheduled == null) {
      return {
        'type': 'feast_reminder',
        'schema': 2,
        'v': 2,
        'occurrence_key': key,
        'celebration_date': _dateOnly(celebrationDate),
        if (scheduled != null) 'scheduled_for': scheduled.toIso8601String(),
        if (timeZone != null) 'timezone': timeZone,
        if (liturgicalRegion != null) 'liturgical_region': liturgicalRegion,
        if (scheduleGeneration != null)
          'schedule_generation': scheduleGeneration,
        'title': title,
        'rank': rank,
        if (saintProfileId != null) 'saint_id': saintProfileId,
        'timing': dayBefore ? 'eve' : 'on_day',
      };
    }

    final remoteExpiry = FeastReminderNotificationContract.remoteExpiresAt(
      scheduled,
    );
    final localSafety = FeastReminderNotificationContract.localSafetyAt(
      scheduled,
    );

    return {
      'type': 'feast_reminder',
      'schema': schemaVersion,
      'v': schemaVersion,
      'occurrence_key': key,
      'celebration_date': _dateOnly(celebrationDate),
      'scheduled_for': scheduled.toIso8601String(),
      'remote_expires_at': remoteExpiry.toIso8601String(),
      'local_safety_at': localSafety.toIso8601String(),
      'local_notification_id':
          FeastReminderNotificationContract.stableNotificationId(key),
      if (timeZone != null) 'timezone': timeZone,
      if (liturgicalRegion != null) 'liturgical_region': liturgicalRegion,
      if (scheduleGeneration != null) 'schedule_generation': scheduleGeneration,
      'title': title,
      'rank': rank,
      if (saintProfileId != null) 'saint_id': saintProfileId,
      'timing': dayBefore ? 'eve' : 'on_day',
    };
  }

  String encode() => jsonEncode(toMap());

  static FeastReminderPayload? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map<String, dynamic>) {
          return null;
        }
        return fromMap(decoded);
      } on FormatException {
        return null;
      } on TypeError {
        return null;
      }
    }

    const legacyPrefix = 'feast:';
    if (!value.startsWith(legacyPrefix)) return null;
    final timingSeparator = value.lastIndexOf(':');
    if (timingSeparator <= legacyPrefix.length) return null;
    final date = DateTime.tryParse(
      value.substring(legacyPrefix.length, timingSeparator),
    );
    if (date == null) return null;
    return FeastReminderPayload(
      celebrationDate: DateTime(date.year, date.month, date.day),
      title: '',
      rank: '',
      saintProfileId: null,
      dayBefore: value.substring(timingSeparator + 1) == 'eve',
    );
  }

  static FeastReminderPayload? fromMap(Map<String, dynamic> decoded) {
    try {
      final type = decoded['type'] as String?;
      final hasSchema = decoded.containsKey('schema');
      final hasV = decoded.containsKey('v');
      final parsedSchema = _parseVersion(decoded['schema']);
      final parsedV = _parseVersion(decoded['v']);
      if ((hasSchema && parsedSchema == null) ||
          (hasV && parsedV == null) ||
          (parsedSchema != null &&
              parsedV != null &&
              parsedSchema != parsedV)) {
        return null;
      }
      final version = parsedSchema ?? parsedV;
      if (version == 1 && type == 'feast') {
        final date = DateTime.tryParse(decoded['date'] as String? ?? '');
        final title = decoded['title'] as String? ?? '';
        final rank = decoded['rank'] as String? ?? '';
        final rawSaintId = decoded['saintId'] as String?;
        if (date == null) return null;
        return FeastReminderPayload(
          celebrationDate: DateTime(date.year, date.month, date.day),
          title: title,
          rank: rank,
          saintProfileId: rawSaintId == null || rawSaintId.trim().isEmpty
              ? null
              : rawSaintId,
          dayBefore: decoded['timing'] == 'eve',
          sourceSchemaVersion: 1,
        );
      }

      final isV3 = version == schemaVersion;
      if ((version != 2 && !isV3) ||
          (isV3
              ? type != 'feast_reminder'
              : (type != 'feast_reminder' && type != 'feast'))) {
        return null;
      }
      final date = DateTime.tryParse(
        decoded['celebration_date'] as String? ?? '',
      );
      final key = decoded['occurrence_key'] as String? ?? '';
      final title = decoded['title'] as String? ?? '';
      if (date == null || key.trim().isEmpty || title.trim().isEmpty) {
        return null;
      }
      final rawSaintId = decoded['saint_id'] as String?;
      final scheduledFor = DateTime.tryParse(
        decoded['scheduled_for'] as String? ?? '',
      );
      final remoteExpiresAt = DateTime.tryParse(
        decoded['remote_expires_at'] as String? ?? '',
      );
      final localSafetyAt = DateTime.tryParse(
        decoded['local_safety_at'] as String? ?? '',
      );
      final localNotificationId = decoded['local_notification_id'];

      if (isV3 &&
          !_isValidV3(
            decoded: decoded,
            occurrenceKey: key,
            celebrationDate: date,
            scheduledFor: scheduledFor,
            remoteExpiresAt: remoteExpiresAt,
            localSafetyAt: localSafetyAt,
            localNotificationId: localNotificationId,
          )) {
        return null;
      }

      return FeastReminderPayload(
        celebrationDate: DateTime(date.year, date.month, date.day),
        scheduledFor: scheduledFor,
        occurrenceKey: key,
        timeZone: decoded['timezone'] as String?,
        liturgicalRegion: decoded['liturgical_region'] as String?,
        scheduleGeneration: decoded['schedule_generation'] as String?,
        remoteExpiresAt: isV3 ? remoteExpiresAt : null,
        localSafetyAt: isV3 ? localSafetyAt : null,
        localNotificationId: isV3 ? localNotificationId as int : null,
        title: title,
        rank: decoded['rank'] as String? ?? '',
        saintProfileId: rawSaintId == null || rawSaintId.trim().isEmpty
            ? null
            : rawSaintId,
        dayBefore: decoded['timing'] == 'eve',
        sourceSchemaVersion: version,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static bool _isValidV3({
    required Map<String, dynamic> decoded,
    required String occurrenceKey,
    required DateTime celebrationDate,
    required DateTime? scheduledFor,
    required DateTime? remoteExpiresAt,
    required DateTime? localSafetyAt,
    required dynamic localNotificationId,
  }) {
    if (scheduledFor == null ||
        remoteExpiresAt == null ||
        localSafetyAt == null) {
      return false;
    }
    if (localNotificationId is! int ||
        localNotificationId !=
            FeastReminderNotificationContract.stableNotificationId(
              occurrenceKey,
            )) {
      return false;
    }
    if (remoteExpiresAt.isAfter(localSafetyAt) ||
        !localSafetyAt.isAfter(scheduledFor) ||
        remoteExpiresAt !=
            FeastReminderNotificationContract.remoteExpiresAt(scheduledFor) ||
        localSafetyAt !=
            FeastReminderNotificationContract.localSafetyAt(scheduledFor)) {
      return false;
    }

    final keyParts = occurrenceKey.split(':');
    if (keyParts.length != 5 ||
        keyParts.any((part) => part.trim().isEmpty) ||
        keyParts[0] != 'feast' ||
        keyParts[2] != _dateOnly(celebrationDate)) {
      return false;
    }
    final timing = decoded['timing'] as String?;
    if (timing != 'eve' && timing != 'on_day') return false;
    if (keyParts[3] != timing) return false;

    final region = decoded['liturgical_region'] as String?;
    final saintId = decoded['saint_id'] as String?;
    final expectedIdentity = FeastReminderNotificationContract.identity(
      region: region == null || region.trim().isEmpty ? keyParts[1] : region,
      celebrationDate: celebrationDate,
      dayBefore: timing == 'eve',
      celebrationId: saintId == null || saintId.trim().isEmpty
          ? keyParts.last
          : saintId,
    );
    if (expectedIdentity.occurrenceKey != occurrenceKey) {
      return false;
    }
    return true;
  }

  static int? _parseVersion(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static LiturgicalColor _colorFromTitle(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('martyr') ||
        normalized.contains('apostle') ||
        normalized.contains('holy cross')) {
      return LiturgicalColor.red;
    }
    return LiturgicalColor.white;
  }
}
