import 'package:catholic_daily/data/services/feast_reminder_background_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = FeastReminderAuditPolicy(
    expectedSchemaVersion: 6,
    expectedScheduleGeneration: 'feast-reminders-v5',
    minimumCoverage: Duration(days: 30),
  );
  final now = DateTime(2026, 8, 28, 12);

  FeastReminderAuditSnapshot healthy() => FeastReminderAuditSnapshot(
    enabled: true,
    permissionGranted: true,
    schemaVersion: 6,
    scheduleGeneration: 'feast-reminders-v5',
    scheduledTimezone: 'Africa/Lagos',
    currentTimezone: 'Africa/Lagos',
    scheduledThrough: DateTime(2026, 10, 1),
    scheduleInProgress: false,
    hasCancellationState: false,
    scheduledConfigurationFingerprint: 'v1|nigeria|feasts|9|0|false',
    currentConfigurationFingerprint: 'v1|nigeria|feasts|9|0|false',
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

  test('cleans interrupted or cancellable schedules before disabled skip', () {
    expect(
      policy.decide(
        healthy().copyWith(enabled: false, scheduleInProgress: true),
        now: now,
      ),
      FeastReminderAuditDecision.cleanup,
    );
    expect(
      policy.decide(
        healthy().copyWith(
          permissionGranted: false,
          hasCancellationState: true,
        ),
        now: now,
      ),
      FeastReminderAuditDecision.cleanup,
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

  test(
    'repairs an interrupted schedule even when freshness markers look current',
    () {
      expect(
        policy.decide(healthy().copyWith(scheduleInProgress: true), now: now),
        FeastReminderAuditDecision.repair,
      );
    },
  );

  test('repairs when settings differ from the scheduled configuration', () {
    expect(
      policy.decide(
        healthy().copyWith(
          currentConfigurationFingerprint: 'v1|nigeria|all|21|15|true',
        ),
        now: now,
      ),
      FeastReminderAuditDecision.repair,
    );
  });
}
