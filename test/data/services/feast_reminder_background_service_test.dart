import 'package:catholic_daily/data/services/feast_reminder_background_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = FeastReminderAuditPolicy(
    expectedSchemaVersion: 5,
    expectedScheduleGeneration: 'feast-reminders-v5',
    minimumCoverage: Duration(days: 30),
  );
  final now = DateTime(2026, 8, 28, 12);

  FeastReminderAuditSnapshot healthy() => FeastReminderAuditSnapshot(
    enabled: true,
    permissionGranted: true,
    schemaVersion: 5,
    scheduleGeneration: 'feast-reminders-v5',
    scheduledTimezone: 'Africa/Lagos',
    currentTimezone: 'Africa/Lagos',
    scheduledThrough: DateTime(2026, 10, 1),
  );

  test('skips disabled and permission-denied installations successfully', () {
    expect(
      policy.decide(healthy().copyWith(enabled: false), now: now),
      FeastReminderAuditDecision.skip,
    );
    expect(
      policy.decide(healthy().copyWith(permissionGranted: false), now: now),
      FeastReminderAuditDecision.skip,
    );
  });

  test('repairs schema, generation, timezone, and short coverage drift', () {
    expect(
      policy.decide(healthy().copyWith(schemaVersion: 4), now: now),
      FeastReminderAuditDecision.repair,
    );
    expect(
      policy.decide(
        healthy().copyWith(scheduleGeneration: 'feast-reminders-v4'),
        now: now,
      ),
      FeastReminderAuditDecision.repair,
    );
    expect(
      policy.decide(
        healthy().copyWith(currentTimezone: 'Europe/London'),
        now: now,
      ),
      FeastReminderAuditDecision.repair,
    );
    expect(
      policy.decide(
        healthy().copyWith(scheduledThrough: DateTime(2026, 9, 20)),
        now: now,
      ),
      FeastReminderAuditDecision.repair,
    );
  });

  test('keeps a current schedule untouched', () {
    expect(
      policy.decide(healthy(), now: now),
      FeastReminderAuditDecision.current,
    );
  });
}
