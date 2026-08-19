import 'package:catholic_daily/data/models/responsorial_psalm_text_entry.dart';
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:catholic_daily/data/services/nigeria_psalm_usage_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_edition_registry.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_source_pack_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_text_catalog_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_preference.dart';
import 'package:flutter/services.dart';
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

  test(
    'Assumption Day and Vigil remain distinct in every Bible psalm pack',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
      final preference = await ResponsorialPsalmPreference.getInstance();
      for (final editionId in <String>['local_rsvce', 'local_nabre']) {
        await preference.setEditionId(editionId);
        final day = await ReadingsService.instance.resolveResponsorialPsalm(
          'Ps 45:10, 11, 12, 16',
          psalmResponse: 'The queen stands at your right hand.',
          date: DateTime(2026, 8, 15),
          territory: 'NG',
          readingSetKind: 'celebration',
        );
        final vigil = await ReadingsService.instance.resolveResponsorialPsalm(
          'Ps 132:6-7, 9-10, 13-14',
          psalmResponse: 'Lord, go up to the place of your rest.',
          date: DateTime(2026, 8, 14),
          territory: 'NG',
          readingSetKind: 'vigil',
        );
        expect(day.referenceNormalized, 'ps45:10,11,12,16');
        expect(vigil.referenceNormalized, 'ps132:6-7,9-10,13-14');
        expect(day.actualEditionId, editionId);
        expect(vigil.actualEditionId, editionId);
        expect(day.text.trim(), isNotEmpty);
        expect(vigil.text.trim(), isNotEmpty);
      }
    },
  );

  test('Deuteronomy 32 canticle renders in every Bible psalm pack', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ResponsorialPsalmPreference.resetForTest();
    final preference = await ResponsorialPsalmPreference.getInstance();

    for (final editionId in <String>['local_rsvce', 'local_nabre']) {
      await preference.setEditionId(editionId);
      final canticle = await ReadingsService.instance.resolveResponsorialPsalm(
        'Dt 32:18-19, 20, 21',
        psalmResponse: 'You forgot God who gave you birth.',
        date: DateTime(2026, 8, 17),
        territory: 'NG',
        weekdayCycle: 'II',
      );

      expect(canticle.referenceNormalized, 'deut32:18-19,20,21');
      expect(canticle.actualEditionId, editionId);
      expect(canticle.responseText, 'You forgot God who gave you birth.');
      expect(canticle.text, contains('R/. You forgot God who gave you birth.'));
    }
  });

  test(
    'August 18 canticle renders in every installed Nigeria option',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
      final preference = await ResponsorialPsalmPreference.getInstance();

      for (final editionId in <String>[
        'territory_lectionary',
        'nigeria_365_firestore',
        'local_rsvce',
        'local_nabre',
      ]) {
        await preference.setEditionId(editionId);
        final canticle = await ReadingsService.instance
            .resolveResponsorialPsalm(
              'Dt 32:26-27ab, 27cd-28, 30, 35cd-36ab',
              psalmResponse: 'I kill and I make alive.',
              date: DateTime(2026, 8, 18),
              territory: 'NG',
              weekdayCycle: 'II',
            );

        expect(canticle.text, contains('R/. I kill and I make alive.'));
        expect(canticle.text.trim(), isNotEmpty);
        if (editionId == 'territory_lectionary') {
          expect(canticle.actualEditionId, 'nigeria_365_firestore');
        }
      }
    },
  );

  test(
    'every official Nigeria choice renders in every installed option',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
      final preference = await ResponsorialPsalmPreference.getInstance();
      final registry = await ResponsorialPsalmEditionRegistry.load();
      final raw = await rootBundle.loadString(
        'assets/data/psalm_editions/nigeria_365.csv',
      );
      final official = ResponsorialPsalmSourcePackService.parsePackCsv(raw);

      for (final edition in registry.selectable) {
        await preference.setEditionId(edition.id);
        for (final entry in official) {
          final resolved = await ReadingsService.instance
              .resolveResponsorialPsalm(
                entry.referenceDisplay,
                psalmResponse: entry.responseText,
                date: entry.dateRule.isEmpty
                    ? DateTime(2026, 1, 1)
                    : DateTime.parse(entry.dateRule),
                territory: 'NG',
                celebrationId: entry.celebrationId,
                sundayCycle: entry.sundayCycle,
                weekdayCycle: entry.weekdayCycle,
                readingSetKind: entry.readingSetKind,
              );

          expect(
            resolved.referenceNormalized,
            entry.referenceNormalized,
            reason: '${edition.id} ${entry.usageId}',
          );
          expect(
            resolved.responseText,
            entry.responseText,
            reason: '${edition.id} ${entry.usageId}',
          );
          expect(
            resolved.text.trim(),
            isNotEmpty,
            reason: '${edition.id} ${entry.usageId}',
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'every reconciled Nigeria usage renders in every installed option',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
      final preference = await ResponsorialPsalmPreference.getInstance();
      final registry = await ResponsorialPsalmEditionRegistry.load();
      final raw = await rootBundle.loadString(
        'assets/data/nigeria_psalm_usages.csv',
      );
      final usages = NigeriaPsalmUsageService.parseCsv(raw);

      expect(usages, hasLength(2536));
      for (final edition in registry.selectable) {
        await preference.setEditionId(edition.id);
        for (final usage in usages) {
          final resolved = await ReadingsService.instance
              .resolveResponsorialPsalm(
                usage.referenceDisplay,
                psalmResponse: usage.responseText,
                date: usage.sourceDate.isEmpty
                    ? DateTime(2026, 1, 1)
                    : DateTime.parse(usage.sourceDate),
                territory: usage.territory,
                celebrationId: usage.celebrationId,
                sundayCycle: usage.sundayCycle,
                weekdayCycle: usage.weekdayCycle,
              );

          expect(
            resolved.referenceNormalized,
            ResponsorialPsalmSourcePackService.normalizePackReference(
              usage.referenceDisplay,
            ),
            reason: '${edition.id} ${usage.usageId}',
          );
          expect(
            resolved.responseText,
            usage.responseText,
            reason: '${edition.id} ${usage.usageId}',
          );
          expect(
            resolved.text.trim(),
            isNotEmpty,
            reason: '${edition.id} ${usage.usageId}',
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
