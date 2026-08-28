import 'package:catholic_daily/data/services/feast_reminder_notification_contract.dart';
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
  });
}
