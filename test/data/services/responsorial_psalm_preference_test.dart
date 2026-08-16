import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
