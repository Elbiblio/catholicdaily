import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/feast_reminder_preferences.dart';
import 'package:catholic_daily/data/services/feast_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a known Saint of the Day is scheduled even with solemnities filter',
    () async {
      final reminders = await FeastReminderService.instance
          .buildScheduledRemindersForTesting(
            now: DateTime(2026, 4, 20),
            monthsAhead: 1,
            rank: FeastReminderRank.solemnities,
            hour: 6,
            minute: 0,
            notifyDayBefore: false,
            region: LiturgicalRegion.generalRoman,
          );

      final saint = reminders.where(
        (event) => event.title.contains('Saint Anselm'),
      );
      expect(saint, hasLength(1));
      expect(saint.single.scheduledTime, DateTime(2026, 4, 21, 6));
      expect(saint.single.daysBefore, 0);
    },
  );

  test(
    'every Feast and Solemnity is announced for eight consecutive days',
    () async {
      final reminders = await FeastReminderService.instance
          .buildScheduledRemindersForTesting(
            now: DateTime(2026, 4, 18),
            monthsAhead: 1,
            rank: FeastReminderRank.feastsDays,
            hour: 9,
            minute: 0,
            notifyDayBefore: false,
            region: LiturgicalRegion.generalRoman,
          );

      final saintMark = reminders
          .where((event) => event.title == 'Saint Mark, Evangelist')
          .toList();
      expect(saintMark, hasLength(8));
      expect(saintMark.map((event) => event.daysBefore).toSet(), {
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      });
      expect(
        saintMark.map((event) => event.scheduledTime),
        containsAll(<DateTime>[
          DateTime(2026, 4, 18, 9),
          DateTime(2026, 4, 19, 9),
          DateTime(2026, 4, 20, 9),
          DateTime(2026, 4, 21, 9),
          DateTime(2026, 4, 22, 9),
          DateTime(2026, 4, 23, 9),
          DateTime(2026, 4, 24, 9),
          DateTime(2026, 4, 25, 9),
        ]),
      );
    },
  );

  test(
    'a saint whose celebration is a Feast still gets its daily reminder',
    () async {
      final reminders = await FeastReminderService.instance
          .buildScheduledRemindersForTesting(
            now: DateTime(2026, 4, 18),
            monthsAhead: 1,
            rank: FeastReminderRank.solemnities,
            hour: 9,
            minute: 0,
            notifyDayBefore: false,
            region: LiturgicalRegion.generalRoman,
          );

      final saintMark = reminders
          .where((event) => event.title == 'Saint Mark, Evangelist')
          .toList();
      expect(saintMark, hasLength(1));
      expect(saintMark.single.scheduledTime, DateTime(2026, 4, 25, 9));
      expect(saintMark.single.daysBefore, 0);
    },
  );
}
