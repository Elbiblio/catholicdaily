import 'package:catholic_daily/data/services/daily_browse_snapshot_store.dart';
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
}
