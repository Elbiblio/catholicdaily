import 'package:catholic_daily/data/services/feast_reminder_notification_contract.dart';
import 'package:catholic_daily/data/services/feast_reminder_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeastReminderNotificationContract', () {
    test('on-day copy cannot become falsely current', () {
      final content = FeastReminderNotificationContract.content(
        celebrationDate: DateTime(2026, 8, 29),
        title: 'The Passion of Saint John the Baptist',
        rank: 'Memorial',
        dayBefore: false,
        locale: 'en',
      );

      expect(content.title, 'Saturday, 29 August — A Memorial');
      expect(content.body, 'The Passion of Saint John the Baptist');
      expect(content.expandedBody, contains('Saturday, 29 August'));
      expect(content.title, isNot(contains('Today')));
      expect(content.expandedBody, isNot(contains('Today')));
    });

    test('eve copy names the absolute target date', () {
      final content = FeastReminderNotificationContract.content(
        celebrationDate: DateTime(2026, 8, 15),
        title: 'The Assumption of the Blessed Virgin Mary',
        rank: 'Solemnity',
        dayBefore: true,
        locale: 'en',
      );

      expect(content.title, 'Saturday, 15 August — A Solemnity');
      expect(content.subtitle, 'Tomorrow\'s celebration · Saturday, 15 August');
      expect(content.expandedBody, contains('Saturday, 15 August'));
    });

    test('countdown copy names the remaining days and absolute date', () {
      final content = FeastReminderNotificationContract.content(
        celebrationDate: DateTime(2026, 8, 15),
        title: 'The Assumption of the Blessed Virgin Mary',
        rank: 'Solemnity',
        dayBefore: true,
        daysBefore: 7,
        locale: 'en',
      );

      expect(content.subtitle, 'In 7 days · Saturday, 15 August');
      expect(
        content.expandedBody,
        contains('In 7 days, on Saturday, 15 August'),
      );
    });

    test('identity is stable, regional, and date scoped', () {
      final value = FeastReminderNotificationContract.identity(
        region: 'nigeria',
        celebrationDate: DateTime(2026, 8, 29),
        dayBefore: false,
        celebrationId: 'passion-john-baptist',
      );
      final repeated = FeastReminderNotificationContract.identity(
        region: 'nigeria',
        celebrationDate: DateTime(2026, 8, 29),
        dayBefore: false,
        celebrationId: 'passion-john-baptist',
      );
      final nextDate = FeastReminderNotificationContract.identity(
        region: 'nigeria',
        celebrationDate: DateTime(2026, 8, 30),
        dayBefore: false,
        celebrationId: 'passion-john-baptist',
      );

      expect(
        value.occurrenceKey,
        'feast:nigeria:2026-08-29:on_day:passion-john-baptist',
      );
      expect(value.notificationId, greaterThan(0));
      expect(value.notificationId, repeated.notificationId);
      expect(value.groupKey, 'feast_reminders:2026-08-29');
      expect(value.sortKey, startsWith('2026-08-29:'));
      expect(nextDate.groupKey, isNot(value.groupKey));
      expect(nextDate.notificationId, isNot(value.notificationId));
    });

    test('fallback celebration identity is canonically slugged', () {
      final value = FeastReminderNotificationContract.identity(
        region: 'NG',
        celebrationDate: DateTime(2026, 11, 1),
        dayBefore: true,
        celebrationId: '  All Saints!  ',
      );

      expect(value.occurrenceKey, 'feast:ng:2026-11-01:eve:all-saints');
    });

    test('countdown identities are stable and distinct for every day', () {
      final keys = <String>{
        for (var days = 0; days <= 7; days++)
          FeastReminderNotificationContract.identity(
            region: 'NG',
            celebrationDate: DateTime(2026, 11, 1),
            dayBefore: days > 0,
            daysBefore: days,
            celebrationId: 'All Saints',
          ).occurrenceKey,
      };

      expect(keys, hasLength(8));
      expect(keys, contains('feast:ng:2026-11-01:advance_7d:all-saints'));
      expect(keys, contains('feast:ng:2026-11-01:eve:all-saints'));
      expect(keys, contains('feast:ng:2026-11-01:on_day:all-saints'));
    });

    test('derives the remote expiry exactly two minutes after scheduling', () {
      final scheduled = DateTime.parse('2026-08-29T07:00:00+01:00');

      expect(
        FeastReminderNotificationContract.remoteExpiresAt(scheduled),
        DateTime.parse('2026-08-29T07:02:00+01:00'),
      );
    });

    test('derives local safety exactly three minutes after scheduling', () {
      final scheduled = DateTime.parse('2026-08-29T07:00:00+01:00');

      expect(
        FeastReminderNotificationContract.localSafetyAt(scheduled),
        DateTime.parse('2026-08-29T07:03:00+01:00'),
      );
    });

    test('v3 payload serializes the stable local notification ID', () {
      final identity = FeastReminderNotificationContract.identity(
        region: 'nigeria',
        celebrationDate: DateTime(2026, 8, 29),
        dayBefore: false,
        celebrationId: 'passion-john-baptist',
      );
      final payload = FeastReminderPayload(
        celebrationDate: DateTime(2026, 8, 29),
        scheduledFor: DateTime.parse('2026-08-29T07:00:00+01:00'),
        occurrenceKey: identity.occurrenceKey,
        title: 'The Passion of Saint John the Baptist',
        rank: 'Memorial',
        saintProfileId: 'passion-john-baptist',
        dayBefore: false,
      );

      final map = payload.toMap();
      expect(map['schema'], 3);
      expect(
        map['local_notification_id'],
        FeastReminderNotificationContract.stableNotificationId(
          identity.occurrenceKey,
        ),
      );
      expect(
        DateTime.parse(map['remote_expires_at'] as String),
        DateTime.parse('2026-08-29T07:02:00+01:00'),
      );
      expect(
        DateTime.parse(map['local_safety_at'] as String),
        DateTime.parse('2026-08-29T07:03:00+01:00'),
      );
    });
  });
}
