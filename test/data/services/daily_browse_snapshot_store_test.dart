import 'package:catholic_daily/data/services/daily_browse_snapshot_store.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/data/services/ordo_resolver_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  DailyBrowseSnapshotKey key({
    DateTime? date,
    String region = 'nigeria',
    String bibleVersion = 'rsvce',
    String generation = 'feast-reminders-v6',
  }) => DailyBrowseSnapshotKey(
    date: date ?? DateTime(2026, 9, 16),
    region: region,
    bibleVersion: bibleVersion,
    generation: generation,
  );

  DailyBrowseSnapshot snapshot({DateTime? date, String region = 'nigeria'}) =>
      DailyBrowseSnapshot(
        key: key(date: date, region: region),
        payload: const {'title': 'The Exaltation of the Holy Cross'},
      );

  test('returns a snapshot only for its exact startup key', () async {
    final store = DailyBrowseSnapshotStore.forTesting(
      preferences: () async => preferences,
      now: () => DateTime(2026, 9, 16),
    );
    await store.save(snapshot());

    expect(await store.read(key()), isNotNull);
    expect(await store.read(key(region: 'generalRoman')), isNull);
  });

  test('discards malformed persisted JSON', () async {
    SharedPreferences.setMockInitialValues({
      DailyBrowseSnapshotStore.storageKey: '{invalid',
    });
    preferences = await SharedPreferences.getInstance();
    final store = DailyBrowseSnapshotStore.forTesting(
      preferences: () async => preferences,
      now: () => DateTime(2026, 9, 16),
    );

    expect(await store.read(key()), isNull);
    expect(preferences.getString(DailyBrowseSnapshotStore.storageKey), isNull);
  });

  test('does not retain snapshots outside the seven-day warm window', () async {
    final store = DailyBrowseSnapshotStore.forTesting(
      preferences: () async => preferences,
      now: () => DateTime(2026, 9, 16),
    );
    await store.save(snapshot(date: DateTime(2026, 9, 24)));

    expect(await store.read(key(date: DateTime(2026, 9, 24))), isNull);
  });

  test('round-trips a complete daily browse payload', () {
    final reading = DailyReading(
      reading: 'John 3:16',
      position: 'Gospel',
      date: DateTime(2026, 9, 16),
    );
    final payload = DailyBrowseSnapshotPayload(
      liturgicalDay: LiturgicalDay(
        date: DateTime(2026, 9, 16),
        title: 'Wednesday of the Twenty-Fourth Week',
        rank: 'Weekday',
        color: LiturgicalColor.green,
        season: LiturgicalSeason.ordinaryTime,
        weekNumber: 24,
        dayOfWeek: DayOfWeek.wednesday,
      ),
      ordoYearVariables: const OrdoYearVariables(
        year: 2026,
        goldenNumber: 13,
        epact: 'XXIV',
        solarCycle: 11,
        indiction: 4,
        julianPeriodYear: 6739,
        yearsSinceIgnatius: 470,
        sundayCycle: 'A',
        weekdayCycle: 'II',
      ),
      celebrationsSuppressed: false,
      saintCelebrations: const [
        OptionalCelebration(
          id: 'saint-cornelius',
          title: 'Saint Cornelius',
          rank: CelebrationRank.obligatoryMemorial,
          color: LiturgicalColor.red,
          month: 9,
          day: 16,
        ),
      ],
      readingSets: [
        CelebrationReadingSet(
          label: 'Wednesday of the Twenty-Fourth Week',
          readings: [reading],
          isFerial: true,
        ),
      ],
      selectedReadingSetIndex: 0,
      readings: [reading],
      readingTexts: const {'John 3:16': 'For God so loved the world.'},
      readingPreviews: const {'John 3:16': 'For God so loved…'},
    );

    final restored = DailyBrowseSnapshotPayload.tryFromJson(payload.toJson());

    expect(restored, isNotNull);
    expect(restored!.liturgicalDay.title, payload.liturgicalDay.title);
    expect(restored.readings.single.reading, 'John 3:16');
    expect(restored.readingSets.single.isFerial, isTrue);
    expect(restored.saintCelebrations.single.id, 'saint-cornelius');
  });
}
