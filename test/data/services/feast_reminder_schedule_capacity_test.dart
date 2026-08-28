import 'package:catholic_daily/data/services/feast_reminder_schedule_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeastReminderScheduleCapacity', () {
    test('ios keeps a conservative pending budget', () {
      expect(FeastReminderScheduleCapacity.forIos().maximumPending, 60);
    });

    test('android does not inherit the ios cap', () {
      expect(FeastReminderScheduleCapacity.forAndroid().maximumPending, isNull);
    });

    test('ios coverage ends at the last completely selected date', () {
      final dates = List.generate(61, (index) => DateTime(2026, 9, 1 + index));

      final result = FeastReminderScheduleCapacity.forIos().select(
        dates,
        celebrationDate: (date) => date,
      );

      expect(result.selected, hasLength(60));
      expect(result.coverageThrough, dates[59]);
    });

    test('drops a date when the cap would split its occurrences', () {
      final dates = <DateTime>[
        ...List.generate(59, (index) => DateTime(2026, 9, 1 + index)),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
      ];

      final result = FeastReminderScheduleCapacity.forIos().select(
        dates,
        celebrationDate: (date) => date,
      );

      expect(result.selected, hasLength(59));
      expect(result.coverageThrough, dates[58]);
      expect(result.selected, isNot(contains(DateTime(2026, 11, 1))));
    });

    test('never splits an interleaved celebration date at the iOS boundary', () {
      final dates = <DateTime>[
        ...List.generate(59, (index) => DateTime(2026, 9, 1 + index)),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 1),
      ];

      final result = FeastReminderScheduleCapacity.forIos().select(
        dates,
        celebrationDate: (date) => date,
      );

      expect(result.selected, hasLength(59));
      expect(result.selected, isNot(contains(DateTime(2026, 11, 1))));
      expect(result.coverageThrough, dates[58]);
    });

    test('unbounded selection includes the complete horizon', () {
      final dates = <DateTime>[DateTime(2026, 8, 15), DateTime(2027, 1, 1)];

      final result = FeastReminderScheduleCapacity.forAndroid().select(
        dates,
        celebrationDate: (date) => date,
      );

      expect(result.selected, dates);
      expect(result.coverageThrough, DateTime(2027, 1, 1));
    });
  });
}
