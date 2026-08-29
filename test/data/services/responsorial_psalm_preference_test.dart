import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ResponsorialPsalmPreference.resetForTest();
  });

  test('psalm preference defaults to territory lectionary', () async {
    final preference = await ResponsorialPsalmPreference.getInstance();
    expect(preference.currentEditionId, 'territory_lectionary');
  });

  test('preference is independent from BibleVersionPreference', () async {
    final psalm = await ResponsorialPsalmPreference.getInstance();
    final bible = await BibleVersionPreference.getInstance();
    await psalm.setEditionId('nigeria_365_firestore');

    expect(psalm.currentEditionId, 'nigeria_365_firestore');
    expect(bible.currentVersion, BibleVersionType.rsvce);
  });

  test(
    'failed persistence leaves the effective psalm edition unchanged',
    () async {
      final preference = await ResponsorialPsalmPreference.getInstance();
      SharedPreferencesStorePlatform.instance = _ThrowingPreferencesStore();

      await expectLater(
        preference.setEditionId('local_rsvce'),
        throwsStateError,
      );

      expect(
        preference.currentEditionId,
        ResponsorialPsalmPreference.defaultEditionId,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
    },
  );
}

class _ThrowingPreferencesStore extends InMemorySharedPreferencesStore {
  _ThrowingPreferencesStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    throw StateError('disk unavailable');
  }
}
