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
