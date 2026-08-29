import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_payload.dart';

enum NotificationOccurrenceEventType { received, opened, expired, reconciled }

enum NotificationOccurrenceStatus {
  scheduled,
  received,
  opened,
  expired,
  reconciled,
}

class NotificationOccurrenceEvent {
  const NotificationOccurrenceEvent({
    required this.occurrenceKey,
    required this.type,
    required this.occurredAt,
  });

  final String occurrenceKey;
  final NotificationOccurrenceEventType type;
  final DateTime occurredAt;

  String get id =>
      '$occurrenceKey|${type.name}|${occurredAt.toUtc().toIso8601String()}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'occurrence_key': occurrenceKey,
    'type': type.name,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };

  static NotificationOccurrenceEvent? tryFromJson(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final occurrenceKey = map['occurrence_key'];
    final type = map['type'];
    final occurredAt = DateTime.tryParse(map['occurred_at']?.toString() ?? '');
    if (occurrenceKey is! String || occurrenceKey.trim().isEmpty) return null;
    final parsedType = NotificationOccurrenceEventType.values
        .where((candidate) => candidate.name == type)
        .firstOrNull;
    if (parsedType == null || occurredAt == null) return null;
    return NotificationOccurrenceEvent(
      occurrenceKey: occurrenceKey,
      type: parsedType,
      occurredAt: occurredAt,
    );
  }
}

class NotificationOccurrence {
  const NotificationOccurrence({
    required this.occurrenceKey,
    required this.localNotificationId,
    required this.scheduledFor,
    required this.remoteExpiresAt,
    required this.localSafetyAt,
    required this.platform,
    required this.scheduleGeneration,
    required this.timezone,
    required this.configurationFingerprint,
    required this.localArmed,
    required this.payload,
    this.receivedAt,
    this.openedAt,
    this.expiredAt,
    this.reconciledAt,
    this.lastSyncedAt,
  });

  final String occurrenceKey;
  final int localNotificationId;
  final DateTime scheduledFor;
  final DateTime remoteExpiresAt;
  final DateTime localSafetyAt;
  final String platform;
  final String scheduleGeneration;
  final String timezone;
  final String configurationFingerprint;
  final bool localArmed;
  final String payload;
  final DateTime? receivedAt;
  final DateTime? openedAt;
  final DateTime? expiredAt;
  final DateTime? reconciledAt;

  /// Local bookkeeping only. It is intentionally omitted from the API body.
  final DateTime? lastSyncedAt;

  bool get needsSync => lastSyncedAt == null;

  NotificationOccurrenceStatus get status {
    if (openedAt != null) return NotificationOccurrenceStatus.opened;
    if (receivedAt != null) return NotificationOccurrenceStatus.received;
    if (reconciledAt != null) return NotificationOccurrenceStatus.reconciled;
    if (expiredAt != null) return NotificationOccurrenceStatus.expired;
    return NotificationOccurrenceStatus.scheduled;
  }

  NotificationOccurrence copyWith({
    bool? localArmed,
    DateTime? receivedAt,
    DateTime? openedAt,
    DateTime? expiredAt,
    DateTime? reconciledAt,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
  }) => NotificationOccurrence(
    occurrenceKey: occurrenceKey,
    localNotificationId: localNotificationId,
    scheduledFor: scheduledFor,
    remoteExpiresAt: remoteExpiresAt,
    localSafetyAt: localSafetyAt,
    platform: platform,
    scheduleGeneration: scheduleGeneration,
    timezone: timezone,
    configurationFingerprint: configurationFingerprint,
    localArmed: localArmed ?? this.localArmed,
    payload: payload,
    receivedAt: receivedAt ?? this.receivedAt,
    openedAt: openedAt ?? this.openedAt,
    expiredAt: expiredAt ?? this.expiredAt,
    reconciledAt: reconciledAt ?? this.reconciledAt,
    lastSyncedAt: clearLastSyncedAt
        ? null
        : (lastSyncedAt ?? this.lastSyncedAt),
  );

  Map<String, dynamic> toApiJson() => <String, dynamic>{
    'occurrence_key': occurrenceKey,
    'local_notification_id': localNotificationId,
    'scheduled_for': scheduledFor.toUtc().toIso8601String(),
    'remote_expires_at': remoteExpiresAt.toUtc().toIso8601String(),
    'local_safety_at': localSafetyAt.toUtc().toIso8601String(),
    'platform': platform,
    'schedule_generation': scheduleGeneration,
    'timezone': timezone,
    'configuration_fingerprint': configurationFingerprint,
    'local_armed': localArmed,
    'status': status.name,
    'payload': payload,
    if (receivedAt != null)
      'received_at': receivedAt!.toUtc().toIso8601String(),
    if (openedAt != null) 'opened_at': openedAt!.toUtc().toIso8601String(),
    if (expiredAt != null) 'expired_at': expiredAt!.toUtc().toIso8601String(),
    if (reconciledAt != null)
      'reconciled_at': reconciledAt!.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toStorageJson() => <String, dynamic>{
    ...toApiJson(),
    if (lastSyncedAt != null)
      'last_synced_at': lastSyncedAt!.toUtc().toIso8601String(),
  };

  static NotificationOccurrence? tryFromStorageJson(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final key = map['occurrence_key'];
    final id = map['local_notification_id'];
    final scheduledFor = _date(map['scheduled_for']);
    final remoteExpiresAt = _date(map['remote_expires_at']);
    final localSafetyAt = _date(map['local_safety_at']);
    final platform = map['platform'];
    final generation = map['schedule_generation'];
    final timezone = map['timezone'];
    final fingerprint = map['configuration_fingerprint'];
    final localArmed = map['local_armed'];
    final payload = map['payload'];
    if (key is! String ||
        key.trim().isEmpty ||
        id is! int ||
        scheduledFor == null ||
        remoteExpiresAt == null ||
        localSafetyAt == null ||
        platform is! String ||
        generation is! String ||
        timezone is! String ||
        fingerprint is! String ||
        localArmed is! bool ||
        payload is! String) {
      return null;
    }
    return NotificationOccurrence(
      occurrenceKey: key,
      localNotificationId: id,
      scheduledFor: scheduledFor,
      remoteExpiresAt: remoteExpiresAt,
      localSafetyAt: localSafetyAt,
      platform: platform,
      scheduleGeneration: generation,
      timezone: timezone,
      configurationFingerprint: fingerprint,
      localArmed: localArmed,
      payload: payload,
      receivedAt: _date(map['received_at']),
      openedAt: _date(map['opened_at']),
      expiredAt: _date(map['expired_at']),
      reconciledAt: _date(map['reconciled_at']),
      lastSyncedAt: _date(map['last_synced_at']),
    );
  }

  bool hasSameServerState(NotificationOccurrence other) =>
      _canonical(toApiJson()) == _canonical(other.toApiJson());

  static DateTime? _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '');

  static String _canonical(Map<String, dynamic> value) {
    final keys = value.keys.toList()..sort();
    return keys.map((key) => '$key=${value[key]}').join('|');
  }

  @override
  String toString() =>
      'NotificationOccurrence(occurrenceKey: $occurrenceKey, '
      'localArmed: $localArmed, payload: <redacted>)';
}

class NotificationOccurrenceProjection {
  const NotificationOccurrenceProjection._();

  static List<NotificationOccurrence> fromPayloads(
    Iterable<FeastReminderPayload> payloads, {
    required Set<String> locallyArmedKeys,
    required String platform,
    required String configurationFingerprint,
  }) {
    final rows = <NotificationOccurrence>[];
    for (final payload in payloads) {
      final key = payload.occurrenceKey;
      final scheduledFor = payload.scheduledFor;
      final remoteExpiresAt = payload.remoteExpiresAt;
      final localSafetyAt = payload.localSafetyAt;
      final generation = payload.scheduleGeneration;
      final timezone = payload.timeZone;
      if (key == null ||
          key.trim().isEmpty ||
          scheduledFor == null ||
          remoteExpiresAt == null ||
          localSafetyAt == null ||
          generation == null ||
          generation.trim().isEmpty ||
          timezone == null ||
          timezone.trim().isEmpty) {
        continue;
      }
      rows.add(
        NotificationOccurrence(
          occurrenceKey: key,
          localNotificationId:
              FeastReminderNotificationContract.stableNotificationId(key),
          scheduledFor: scheduledFor,
          remoteExpiresAt: remoteExpiresAt,
          localSafetyAt: localSafetyAt,
          platform: platform,
          scheduleGeneration: generation,
          timezone: timezone,
          configurationFingerprint: configurationFingerprint,
          localArmed: locallyArmedKeys.contains(key),
          payload: payload.encode(),
        ),
      );
    }
    return List<NotificationOccurrence>.unmodifiable(rows);
  }
}
