import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_payload.dart';

/// Separates the intended server delivery time from the local OS safety net.
class FeastReminderSafetySchedule {
  const FeastReminderSafetySchedule._({
    required this.scheduledFor,
    required this.remoteExpiresAt,
    required this.localSafetyAt,
  });

  factory FeastReminderSafetySchedule.fromIntendedTime(DateTime scheduledFor) {
    return FeastReminderSafetySchedule._(
      scheduledFor: scheduledFor,
      remoteExpiresAt: FeastReminderNotificationContract.remoteExpiresAt(
        scheduledFor,
      ),
      localSafetyAt: FeastReminderNotificationContract.localSafetyAt(
        scheduledFor,
      ),
    );
  }

  final DateTime scheduledFor;
  final DateTime remoteExpiresAt;
  final DateTime localSafetyAt;

  /// Returns the trigger persisted in the payload, never the intended time.
  static DateTime localTriggerFor(FeastReminderPayload payload) {
    final localSafetyAt = payload.localSafetyAt;
    if (localSafetyAt == null) {
      throw ArgumentError.value(
        payload,
        'payload',
        'must include a local safety trigger',
      );
    }
    return localSafetyAt;
  }
}

class FeastReminderSchedulePolicy {
  static const replenishmentLeadTime = Duration(days: 30);

  const FeastReminderSchedulePolicy();

  bool needsReschedule({
    required DateTime now,
    required DateTime? scheduledThrough,
    required bool schemaMatches,
  }) {
    if (!schemaMatches || scheduledThrough == null) return true;
    return !scheduledThrough.isAfter(now.add(replenishmentLeadTime));
  }

  AndroidScheduleMode androidMode({required bool exactAllowed}) {
    return exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}

class FeastReminderScheduleResult {
  final int eligibleCount;
  final int scheduledCount;
  final int failureCount;
  final DateTime? scheduledThrough;
  final bool usedExactDelivery;

  const FeastReminderScheduleResult({
    required this.eligibleCount,
    required this.scheduledCount,
    required this.failureCount,
    required this.scheduledThrough,
    required this.usedExactDelivery,
  });

  bool get shouldPersistHorizon =>
      (eligibleCount == 0 && failureCount == 0 && scheduledThrough != null) ||
      (scheduledCount > 0 && scheduledThrough != null);
}
