import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
