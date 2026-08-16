import 'package:catholic_daily/data/models/responsorial_psalm_text_entry.dart';
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_text_catalog_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  test(
    'reviewed liturgical psalm does not change with Bible preference',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
      const entry = ResponsorialPsalmTextEntry(
        usageId: 'ng:2026-08-15:responsorial-psalm:1',
        territory: 'NG',
        celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
        dateRule: '08-15',
        sundayCycle: 'A/B/C',
        weekdayCycle: 'I/II',
        lectionaryNumber: '',
        readingSetKind: 'celebration',
        referenceNormalized: 'ps45:10,11,12,16',
        responseText: 'Reviewed response.',
        stanzas: <String>['Reviewed lectionary stanza.'],
        sourceId: 'reviewed_source',
        sourceEdition: 'reviewed edition',
        sourceUrl: 'https://example.invalid/reviewed',
        displayPriority: 1,
      );
      final catalog = ResponsorialPsalmTextCatalogService.instance;
      catalog.setEntriesForTesting(<ResponsorialPsalmTextEntry>[entry]);
      addTearDown(() => catalog.setEntriesForTesting(null));

      final preference = await BibleVersionPreference.getInstance();
      await preference.setVersion(BibleVersionType.rsvce);
      final rsvce = await ReadingsService.instance.getReadingText(
        'Ps 45:10, 11, 12, 16',
        psalmResponse: 'Reviewed response.',
        readingType: 'Responsorial Psalm',
        date: DateTime(2026, 8, 15),
        territory: 'NG',
        celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
        readingSetKind: 'celebration',
      );
      await preference.setVersion(BibleVersionType.nabre);
      final nabre = await ReadingsService.instance.getReadingText(
        'Ps 45:10, 11, 12, 16',
        psalmResponse: 'Reviewed response.',
        readingType: 'Responsorial Psalm',
        date: DateTime(2026, 8, 15),
        territory: 'NG',
        celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
        readingSetKind: 'celebration',
      );

      expect(nabre, rsvce);
      expect(rsvce, contains('Reviewed lectionary stanza.'));
    },
  );

  test(
    'selected psalm edition changes stanza text without changing Bible',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
      final bible = await BibleVersionPreference.getInstance();
      await bible.setVersion(BibleVersionType.rsvce);
      final psalm = await ResponsorialPsalmPreference.getInstance();

      await psalm.setEditionId('local_rsvce');
      final rsvce = await ReadingsService.instance.resolveResponsorialPsalm(
        'Ps 45:10, 11, 12, 16',
        psalmResponse: 'The queen stands at your right hand.',
        date: DateTime(2026, 8, 15),
        territory: 'NG',
      );
      await psalm.setEditionId('local_nabre');
      final nabre = await ReadingsService.instance.resolveResponsorialPsalm(
        'Ps 45:10, 11, 12, 16',
        psalmResponse: 'The queen stands at your right hand.',
        date: DateTime(2026, 8, 15),
        territory: 'NG',
      );

      expect(rsvce.text, isNot(nabre.text));
      expect(nabre.actualEditionId, 'local_nabre');
      expect(bible.currentVersion, BibleVersionType.rsvce);
    },
  );
}
