import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_payload.dart';
import 'notification_occurrence.dart';

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

  static bool isLocallySchedulable({
    required DateTime scheduledFor,
    required DateTime now,
  }) => localSafetyAtFor(scheduledFor).isAfter(now);

  static DateTime localSafetyAtFor(DateTime scheduledFor) =>
      FeastReminderNotificationContract.localSafetyAt(scheduledFor);
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

class FeastReminderScheduleReconciliation {
  const FeastReminderScheduleReconciliation._();

  static List<T> retainBeforeFailure<T>(
    Iterable<T> items, {
    required DateTime failedDate,
    required DateTime Function(T item) celebrationDate,
  }) {
    final boundary = _dateOnly(failedDate);
    return items
        .where((item) => _dateOnly(celebrationDate(item)).isBefore(boundary))
        .toList(growable: false);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class FeastReminderScheduleResult {
  final int eligibleCount;
  final int scheduledCount;
  final int failureCount;
  final DateTime? scheduledThrough;
  final bool usedExactDelivery;
  final List<NotificationOccurrence> occurrences;
  final bool occurrenceQueuePersisted;

  const FeastReminderScheduleResult({
    required this.eligibleCount,
    required this.scheduledCount,
    required this.failureCount,
    required this.scheduledThrough,
    required this.usedExactDelivery,
    this.occurrences = const [],
    this.occurrenceQueuePersisted = true,
  });

  bool get shouldPersistHorizon =>
      (eligibleCount == 0 && failureCount == 0 && scheduledThrough != null) ||
      (scheduledCount > 0 && scheduledThrough != null);
}
