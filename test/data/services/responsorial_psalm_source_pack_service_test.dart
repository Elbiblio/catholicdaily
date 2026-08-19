import 'package:catholic_daily/data/models/responsorial_psalm_text_entry.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_edition_registry.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_source_pack_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pack lookup preserves the authoritative normalized selection',
    () async {
      const entry = ResponsorialPsalmTextEntry(
        usageId: 'ps45_10_11_12_16',
        territory: 'WORLD',
        celebrationId: '',
        dateRule: '',
        sundayCycle: '',
        weekdayCycle: '',
        lectionaryNumber: '',
        readingSetKind: 'generic',
        referenceNormalized: 'ps45:10,11,12,16',
        responseText: 'The queen stands at your right hand.',
        stanzas: <String>['Complete edition stanza.'],
        sourceId: 'local_rsvce',
        sourceEdition: 'RSVCE',
        sourceUrl: 'repo://rsvce',
        displayPriority: 100,
      );
      final service = ResponsorialPsalmSourcePackService.fromEntries(
        <String, List<ResponsorialPsalmTextEntry>>{
          'local_rsvce': <ResponsorialPsalmTextEntry>[entry],
        },
      );
      final result = await service.lookup(
        editionId: 'local_rsvce',
        request: ResponsorialPsalmRequest(
          selectedEditionId: 'local_rsvce',
          reference: 'Ps 45:10, 11, 12, 16',
          responseText: 'Reviewed response.',
          date: DateTime(2026, 8, 15),
          territory: 'NG',
        ),
      );
      expect(result?.referenceNormalized, 'ps45:10,11,12,16');
      expect(result?.stanzas.single, 'Complete edition stanza.');
    },
  );

  test(
    'resolved Nigerian text lookup uses the selected response, not source date',
    () async {
      const wrongDate = ResponsorialPsalmTextEntry(
        usageId: 'wrong-date',
        territory: 'NG',
        celebrationId: '',
        dateRule: '2026-08-18',
        sundayCycle: '',
        weekdayCycle: '',
        lectionaryNumber: '',
        readingSetKind: 'resolved-day',
        referenceNormalized: 'ps23:1-3a,3b-4,5,6',
        responseText: 'Another lectionary response.',
        stanzas: <String>['Wrong date stanza.'],
        sourceId: 'nigeria_365_firestore',
        sourceEdition: 'Nigeria Lectionary',
        sourceUrl: 'https://example.invalid/wrong',
        displayPriority: 1,
      );
      const exactDate = ResponsorialPsalmTextEntry(
        usageId: 'exact-date',
        territory: 'NG',
        celebrationId: '',
        dateRule: '2026-08-19',
        sundayCycle: '',
        weekdayCycle: '',
        lectionaryNumber: '',
        readingSetKind: 'resolved-day',
        referenceNormalized: 'ps23:1-3a,3b-4,5,6',
        responseText: 'The Lord is my shepherd; there is nothing I shall want.',
        stanzas: <String>['The Lord is my shepherd.'],
        sourceId: 'nigeria_365_firestore',
        sourceEdition: 'Nigeria Lectionary',
        sourceUrl: 'https://example.invalid/exact',
        displayPriority: 1,
      );
      final service = ResponsorialPsalmSourcePackService.fromEntries(
        const <String, List<ResponsorialPsalmTextEntry>>{
          'nigeria_365_firestore': <ResponsorialPsalmTextEntry>[
            wrongDate,
            exactDate,
          ],
        },
      );

      final result = await service.lookup(
        editionId: 'nigeria_365_firestore',
        request: ResponsorialPsalmRequest(
          selectedEditionId: 'nigeria_365_firestore',
          reference: 'Ps 23:1-3a, 3b-4, 5, 6',
          responseText:
              'The Lord is my shepherd; there is nothing I shall want.',
          date: DateTime(2030, 8, 21),
          territory: 'NG',
        ),
      );

      expect(result?.usageId, 'exact-date');
    },
  );

  test(
    'normalization preserves the chapter separator in dotted references',
    () {
      expect(
        ResponsorialPsalmSourcePackService.normalizePackReference(
          'Ps 23.1-3a. 3b-4. 5. 6',
        ),
        'ps23:1-3a,3b-4,5,6',
      );
    },
  );

  test('pack parser preserves a canonical display reference', () {
    const raw =
        '''edition_id,selection_id,territory,celebration_id,date_rule,reading_set_kind,sunday_cycle,weekday_cycle,lectionary_number,reference_normalized,response_text,stanzas_text,source_url,source_edition,raw_sha256,normalized_sha256,display_priority
nigeria_365_firestore,ng:2026-08-18:responsorial-psalm:1,NG,,2026-08-18,resolved-day,,,,"Dt 32:26-27ab, 27cd-28, 30, 35cd-36ab",I kill and I make alive.,Complete stanza.,https://example.invalid,Nigeria Lectionary,raw,normalized,1
''';

    final entry = ResponsorialPsalmSourcePackService.parsePackCsv(raw).single;

    expect(entry.referenceDisplay, 'Dt 32:26-27ab, 27cd-28, 30, 35cd-36ab');
    expect(entry.referenceNormalized, 'deut32:26-27ab,27cd-28,30,35cd-36ab');
  });

  test(
    'bundled RSVCE pack resolves the accurate Assumption selection',
    () async {
      final registry = await ResponsorialPsalmEditionRegistry.load();
      final service = ResponsorialPsalmSourcePackService(registry: registry);
      final result = await service.lookup(
        editionId: 'local_rsvce',
        request: ResponsorialPsalmRequest(
          selectedEditionId: 'local_rsvce',
          reference: 'Ps 45:10, 11, 12, 16',
          responseText: 'The queen stands at your right hand.',
          date: DateTime(2026, 8, 15),
          territory: 'NG',
        ),
      );
      expect(result, isNotNull);
      expect(result!.referenceNormalized, 'ps45:10,11,12,16');
      expect(result.stanzas.first, contains('queen in gold'));
      expect(result.stanzas.first, isNot(startsWith('Hear, O daughter')));
    },
  );
}
