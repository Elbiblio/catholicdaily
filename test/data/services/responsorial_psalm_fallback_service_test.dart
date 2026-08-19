import 'package:catholic_daily/data/models/responsorial_psalm_text_entry.dart';
import 'package:catholic_daily/data/models/resolved_responsorial_psalm.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_edition_registry.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_fallback_service.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_source_pack_service.dart';
import 'package:flutter_test/flutter_test.dart';

ResponsorialPsalmTextEntry entry(String edition, String text) =>
    ResponsorialPsalmTextEntry(
      usageId: 'ps45_10_11_12_16',
      territory: edition == 'nigeria_365_firestore' ? 'NG' : 'WORLD',
      celebrationId: '',
      dateRule: '',
      sundayCycle: '',
      weekdayCycle: '',
      lectionaryNumber: '',
      readingSetKind: 'generic',
      referenceNormalized: 'ps45:10,11,12,16',
      responseText: edition == 'nigeria_365_firestore'
          ? 'Nigerian response.'
          : '',
      stanzas: <String>[text],
      sourceId: edition,
      sourceEdition: edition,
      sourceUrl: 'repo://$edition',
      displayPriority: 100,
    );

ResponsorialPsalmEditionRegistry registry() =>
    ResponsorialPsalmEditionRegistry.fromJson(<String, dynamic>{
      'editions': <Map<String, dynamic>>[
        for (final id in <String>[
          'modern_psalter_us',
          'nigeria_365_firestore',
          'local_nabre',
          'local_rsvce',
        ])
          <String, dynamic>{
            'id': id,
            'displayName': id,
            'abbreviation': id,
            'sourceKind': id.startsWith('local_') ? 'bible' : 'lectionary',
            'territories': <String>[
              id == 'nigeria_365_firestore' ? 'NG' : 'WORLD',
            ],
            'coverageStatus': id == 'modern_psalter_us'
                ? 'unavailable'
                : 'complete',
            'packAsset': id == 'modern_psalter_us' ? '' : '$id.csv',
            'installed': id != 'modern_psalter_us',
            'downloadable': false,
            'sourceUrl': 'repo://$id',
          },
      ],
    });

void main() {
  test(
    'territory selection identifies a non-territory edition as fallback',
    () async {
      final resolver = ResponsorialPsalmFallbackService(
        registry: registry(),
        packs: ResponsorialPsalmSourcePackService.fromEntries(
          <String, List<ResponsorialPsalmTextEntry>>{
            'local_rsvce': <ResponsorialPsalmTextEntry>[
              entry('local_rsvce', 'RSVCE stanza.'),
            ],
          },
        ),
      );

      final result = await resolver.resolve(
        request: ResponsorialPsalmRequest(
          selectedEditionId: 'territory_lectionary',
          reference: 'Ps 45:10, 11, 12, 16',
          responseText: 'Reviewed response.',
          date: DateTime(2026, 8, 15),
          territory: 'NG',
        ),
        territoryEditionId: 'nigeria_365_firestore',
        bibleEditionId: 'local_rsvce',
      );

      expect(result.actualEditionId, 'local_rsvce');
      expect(result.actualEditionName, 'local_rsvce');
      expect(result.didFallback, isTrue);
      expect(
        result.fallbackReason,
        PsalmFallbackReason.territoryEditionMissing,
      );
    },
  );

  test(
    'territory selection is not a fallback when Nigeria text exists',
    () async {
      final resolver = ResponsorialPsalmFallbackService(
        registry: registry(),
        packs: ResponsorialPsalmSourcePackService.fromEntries(
          <String, List<ResponsorialPsalmTextEntry>>{
            'nigeria_365_firestore': <ResponsorialPsalmTextEntry>[
              entry('nigeria_365_firestore', 'Nigerian stanza.'),
            ],
          },
        ),
      );

      final result = await resolver.resolve(
        request: ResponsorialPsalmRequest(
          selectedEditionId: 'territory_lectionary',
          reference: 'Ps 45:10, 11, 12, 16',
          responseText: 'Reviewed response.',
          date: DateTime(2026, 8, 15),
          territory: 'NG',
        ),
        territoryEditionId: 'nigeria_365_firestore',
        bibleEditionId: 'local_rsvce',
      );

      expect(result.actualEditionId, 'nigeria_365_firestore');
      expect(result.didFallback, isFalse);
    },
  );

  test('fallback order preserves the stable liturgical response', () async {
    final packs = ResponsorialPsalmSourcePackService.fromEntries(
      <String, List<ResponsorialPsalmTextEntry>>{
        'nigeria_365_firestore': <ResponsorialPsalmTextEntry>[
          entry('nigeria_365_firestore', 'Nigeria stanza.'),
        ],
        'local_nabre': <ResponsorialPsalmTextEntry>[
          entry('local_nabre', 'NABRE stanza.'),
        ],
        'local_rsvce': <ResponsorialPsalmTextEntry>[
          entry('local_rsvce', 'RSVCE stanza.'),
        ],
      },
    );
    final resolver = ResponsorialPsalmFallbackService(
      registry: registry(),
      packs: packs,
    );
    final result = await resolver.resolve(
      request: ResponsorialPsalmRequest(
        selectedEditionId: 'modern_psalter_us',
        reference: 'Ps 45:10, 11, 12, 16',
        responseText: 'Reviewed response.',
        date: DateTime(2026, 8, 15),
        territory: 'NG',
      ),
      territoryEditionId: 'nigeria_365_firestore',
      bibleEditionId: 'local_nabre',
    );
    expect(result.actualEditionId, 'nigeria_365_firestore');
    expect(result.didFallback, isTrue);
    expect(result.fallbackReason, PsalmFallbackReason.selectedEditionMissing);
    expect(result.responseText, 'Reviewed response.');
  });

  test('fallback never changes the authoritative selection', () async {
    final resolver = ResponsorialPsalmFallbackService(
      registry: registry(),
      packs: ResponsorialPsalmSourcePackService.fromEntries(
        <String, List<ResponsorialPsalmTextEntry>>{
          'local_nabre': <ResponsorialPsalmTextEntry>[
            entry('local_nabre', 'Assumption Psalm 45 text.'),
          ],
        },
      ),
    );
    final result = await resolver.resolve(
      request: ResponsorialPsalmRequest(
        selectedEditionId: 'local_nabre',
        reference: 'Ps 45:10, 11, 12, 16',
        responseText: 'Reviewed response.',
        date: DateTime(2026, 8, 15),
        territory: 'NG',
      ),
      territoryEditionId: 'nigeria_365_firestore',
      bibleEditionId: 'local_nabre',
    );
    expect(result.referenceNormalized, 'ps45:10,11,12,16');
    expect(result.text, isNot(contains('ps132')));
    expect(result.responseText, 'Reviewed response.');
  });
}
