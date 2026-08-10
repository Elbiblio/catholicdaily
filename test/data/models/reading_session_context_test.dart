import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/navigable_item.dart';
import 'package:catholic_daily/data/models/reading_session.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith retains the liturgical day for reading navigation', () {
    final day = LiturgicalDay(
      date: DateTime(2026, 8, 10),
      title: 'Saint Lawrence',
      rank: 'Feast',
      color: LiturgicalColor.red,
      season: LiturgicalSeason.ordinaryTime,
      weekNumber: 19,
      dayOfWeek: DayOfWeek.monday,
    );
    final readings = [
      DailyReading(
        reading: '2 Cor 9:6-10',
        position: 'First Reading',
        date: day.date,
      ),
      DailyReading(reading: 'Jn 12:24-26', position: 'Gospel', date: day.date),
    ];

    final session = ReadingSession(
      readings: readings,
      readingTexts: const {},
      currentIndex: 0,
      liturgicalDay: day,
    );

    final next = session.copyWith(currentIndex: 1);

    expect(next.liturgicalDay, same(day));
  });

  test('same references on different dates are different sessions', () {
    final first = [
      DailyReading(
        reading: 'John 3:16',
        position: 'Gospel',
        date: DateTime(2026, 8, 10),
      ),
    ];
    final second = [
      DailyReading(
        reading: 'John 3:16',
        position: 'Gospel',
        date: DateTime(2026, 8, 11),
      ),
    ];

    expect(ReadingSession.sameReadingSet(first, second), isFalse);
  });

  test('selectReading keeps reading and navigable indices synchronized', () {
    final date = DateTime(2026, 8, 10);
    final readings = [
      DailyReading(reading: 'First', position: 'First Reading', date: date),
      DailyReading(reading: 'Psalm', position: 'Psalm', date: date),
      DailyReading(reading: 'Gospel', position: 'Gospel', date: date),
    ];
    final session = ReadingSession(
      readings: readings,
      readingTexts: const {},
      currentIndex: 0,
      navigableItems: readings
          .map((reading) => NavigableItem.fromReading(reading))
          .toList(),
      navigableIndex: 0,
    );

    final selected = session.selectReading(2);

    expect(selected.currentIndex, 2);
    expect(selected.navigableIndex, 2);
    expect(selected.currentReading?.reading, 'Gospel');
  });
}
