import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/incipit_decision_service.dart';
import 'package:catholic_daily/data/services/incipit_preference_service.dart';
import 'package:catholic_daily/data/services/incipit_processing_service.dart';
import 'package:catholic_daily/data/services/incipit_rules_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  setUp(() {
    IncipitRulesService().resetCache();
  });

  final decisionService = IncipitDecisionService();
  final processor = IncipitProcessingService();

  test(
    'incipit locale follows liturgical region unless explicitly overridden',
    () async {
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      final incipitPrefs = IncipitPreferenceService();

      await incipitPrefs.clearLocaleOverride();
      await regionPrefs.setRegion(LiturgicalRegion.englandWales);
      incipitPrefs.resetCache();
      expect(await incipitPrefs.getLocale(), 'en-GB');

      await regionPrefs.setRegion(LiturgicalRegion.nigeria);
      incipitPrefs.resetCache();
      expect(await incipitPrefs.getLocale(), 'en-NG');

      await regionPrefs.setRegion(LiturgicalRegion.unitedStates);
      incipitPrefs.resetCache();
      expect(await incipitPrefs.getLocale(), 'en-US');

      await regionPrefs.setRegion(LiturgicalRegion.brazil);
      incipitPrefs.resetCache();
      expect(await incipitPrefs.getLocale(), 'en');

      await regionPrefs.setRegion(LiturgicalRegion.mexico);
      incipitPrefs.resetCache();
      expect(await incipitPrefs.getLocale(), 'en');

      await incipitPrefs.setLocale('en-GB');
      await regionPrefs.setRegion(LiturgicalRegion.nigeria);
      incipitPrefs.resetCache();
      expect(await incipitPrefs.getLocale(), 'en-GB');

      await incipitPrefs.clearLocaleOverride();
      incipitPrefs.resetCache();
      expect(await incipitPrefs.getLocale(), 'en-NG');

      await regionPrefs.setRegion(LiturgicalRegion.generalRoman);
      await incipitPrefs.clearLocaleOverride();
      incipitPrefs.resetCache();
    },
  );

  test(
    'Brazil and Mexico source evidence captures local incipit patterns',
    () async {
      final aparecidaGospel = await decisionService.decide(
        reference: 'John 2:1-11',
        fullText:
            '1. houve um casamento em Caná da Galileia. '
            'A mãe de Jesus estava presente.',
        locale: 'pt-BR',
        readingType: 'gospel',
      );
      expect(
        aparecidaGospel.opening,
        'Naquele tempo, houve um casamento em Caná da Galileia',
      );
      expect(aparecidaGospel.joinStyle, 'comma');
      expect(aparecidaGospel.sourceIds.single, 'cnbb_aparecida_john2');

      final aparecidaFirst = await decisionService.decide(
        reference: 'Esth 5:1b-2; 7:2b-3',
        fullText:
            '1b. Ester revestiu-se com vestes de rainha e foi colocar-se '
            'no vestíbulo interno do palácio real.',
        locale: 'pt-BR',
        readingType: 'first reading',
      );
      expect(aparecidaFirst.opening, 'Ester revestiu-se com vestes de rainha');
      expect(aparecidaFirst.sourceIds.single, 'cnbb_aparecida_esth5');

      final guadalupeGospel = await decisionService.decide(
        reference: 'Luke 1:26-38',
        fullText:
            '26. el ángel Gabriel fue enviado por Dios a una ciudad '
            'de Galilea, llamada Nazaret.',
        locale: 'es-MX',
        readingType: 'gospel',
      );
      expect(
        guadalupeGospel.opening,
        'En aquel tiempo, el ángel Gabriel fue enviado por Dios',
      );
      expect(guadalupeGospel.joinStyle, 'comma');
      expect(guadalupeGospel.sourceIds.single, 'cem_guadalupe_luke1_26');

      final guadalupeAlternative = await decisionService.decide(
        reference: 'Luke 1:39-47',
        fullText:
            '39. María se encaminó presurosa a un pueblo de las montañas '
            'de Judea.',
        locale: 'es-MX',
        readingType: 'gospel',
      );
      expect(
        guadalupeAlternative.opening,
        'En aquellos días, María se encaminó presurosa',
      );
      expect(guadalupeAlternative.sourceIds.single, 'cem_guadalupe_luke1_39');
    },
  );

  test('John 16:12-15 uses locale-specific source-backed openings', () async {
    const raw =
        '12. "I have yet many things to say to you, '
        'but you cannot bear them now.';

    final gb = await decisionService.decide(
      reference: 'John 16:12-15',
      fullText: raw,
      locale: 'en-GB',
      readingType: 'gospel',
    );
    expect(gb.operation, 'sourceOpening');
    expect(gb.opening, 'At that time: Jesus said to his disciples');
    expect(gb.joinStyle, 'comma');
    expect(
      processor.processWithAuthoritativeIncipit(
        'John 16:12-15',
        raw,
        gb.opening,
        joinStyle: gb.joinStyle,
      ),
      startsWith('At that time: Jesus said to his disciples, "I have'),
    );

    final us = await decisionService.decide(
      reference: 'John 16:12-15',
      fullText: raw,
      locale: 'en-US',
      readingType: 'gospel',
    );
    expect(us.opening, 'Jesus said to his disciples');
    expect(us.joinStyle, 'colon');
    expect(
      processor.processWithAuthoritativeIncipit(
        'John 16:12-15',
        raw,
        us.opening,
        joinStyle: us.joinStyle,
      ),
      startsWith('Jesus said to his disciples: "I have'),
    );

    final ng = await decisionService.decide(
      reference: 'John 16:12-15',
      fullText: raw,
      locale: 'en-NG',
      readingType: 'gospel',
    );
    expect(ng.opening, 'Jesus said to his disciples');
    expect(ng.sourceIds.single, startsWith('universalis_ng'));
  });

  test('Acts 17 uses In those days for GB source evidence', () async {
    const raw =
        '15. Those who conducted Paul brought him as far as Athens; '
        'and receiving a command for Silas and Timothy to come to him as '
        'soon as possible, they departed.';

    final decision = await decisionService.decide(
      reference: 'Acts 17:15, 22-18:1',
      fullText: raw,
      locale: 'en-GB',
      readingType: 'first reading',
    );

    expect(decision.opening, 'In those days');
    expect(decision.joinStyle, 'colon');
    expect(
      processor.processWithAuthoritativeIncipit(
        'Acts 17:15, 22-18:1',
        raw,
        decision.opening,
        joinStyle: decision.joinStyle,
      ),
      startsWith('In those days: Those who conducted Paul'),
    );
  });

  test('Acts 5 source evidence overrides incomplete CSV incipit', () async {
    const raw =
        '17. But the high priest rose up and all who were with him, '
        'that is, the party of the Sadducees, and filled with jealousy';

    final decision = await decisionService.decide(
      reference: 'Acts 5:17-26',
      fullText: raw,
      csvIncipit: 'The high priest and all who were with him',
      locale: 'en',
      readingType: 'first reading',
    );

    expect(decision.opening, 'In those days');
    expect(decision.sourceIds.single, 'local_easter2_wed_acts5');
    expect(
      processor.processWithAuthoritativeIncipit(
        'Acts 5:17-26',
        raw,
        decision.opening,
        joinStyle: decision.joinStyle,
      ),
      startsWith('In those days: The high priest rose up'),
    );
  });

  test(
    'Matthew 4 keeps contextual biblical opening instead of adding formula',
    () async {
      const raw =
          '12. Now when Jesus heard that John had been arrested, '
          'he withdrew into Galilee.';

      final decision = await decisionService.decide(
        reference: 'Matthew 4:12-17, 23-25',
        fullText: raw,
        locale: 'en',
        readingType: 'gospel',
      );

      expect(decision.operation, 'rawText');
      expect(decision.usesOpening, isFalse);
    },
  );

  test('Mark 4 resolves source-backed he began to Jesus began', () async {
    const raw =
        '1. Again he began to teach beside the sea. '
        'And a very large crowd gathered about him.';

    final decision = await decisionService.decide(
      reference: 'Mark 4:1-20',
      fullText: raw,
      locale: 'en',
      readingType: 'gospel',
    );

    expect(decision.opening, 'Jesus began to teach beside the sea');
    final rendered = processor.processWithAuthoritativeIncipit(
      'Mark 4:1-20',
      raw,
      decision.opening,
      joinStyle: decision.joinStyle,
    );
    expect(rendered, startsWith('Jesus began to teach beside the sea,'));
    expect(rendered, isNot(contains('At that time: He began')));
  });

  test(
    'Acts 9 keeps Saul as the speaker/actor and never rewrites to Jesus',
    () async {
      const raw =
          '1. But Saul, still breathing threats and murder against '
          'the disciples of the Lord, went to the high priest.';

      final decision = await decisionService.decide(
        reference: 'Acts 9:1-20',
        fullText: raw,
        locale: 'en',
        readingType: 'first reading',
      );

      expect(decision.opening, startsWith('Saul, still breathing'));
      final rendered = processor.processWithAuthoritativeIncipit(
        'Acts 9:1-20',
        raw,
        decision.opening,
        joinStyle: decision.joinStyle,
      );
      expect(rendered, startsWith('Saul, still breathing'));
      expect(rendered, isNot(startsWith('Jesus')));
    },
  );

  test(
    'Catholic epistle evidence joins Beloved without verse/conjunction leak',
    () async {
      const raw =
          '22. and we receive from him whatever we ask, because we '
          'keep his commandments and do what pleases him.';

      final decision = await decisionService.decide(
        reference: '1 John 3:22-4:6',
        fullText: raw,
        locale: 'en',
        readingType: 'second reading',
      );

      expect(decision.opening, 'Beloved');
      expect(
        processor.processWithAuthoritativeIncipit(
          '1 John 3:22-4:6',
          raw,
          decision.opening,
          joinStyle: decision.joinStyle,
        ),
        startsWith('Beloved: We receive from him whatever we ask'),
      );
    },
  );

  test('contaminated Matthew 5 legacy rule is quarantined', () async {
    const raw =
        '1. Seeing the crowds, he went up on the mountain, '
        'and when he sat down his disciples came to him.';

    final decision = await decisionService.decide(
      reference: 'Matthew 5:1-12',
      fullText: raw,
      locale: 'en',
      readingType: 'gospel',
    );

    expect(decision.operation, 'rawText');
    expect(
      decision.warnings.join('|'),
      contains('legacy_rule_quarantined:gt_081'),
    );
    expect(
      decision.warnings.join('|'),
      contains('known_contaminated_evidence'),
    );
  });

  test(
    'CSV contamination is rejected when formula contradicts reading type',
    () async {
      final decision = await decisionService.decide(
        reference: 'Isaiah 1:1',
        fullText: '1. The vision of Isaiah the son of Amoz.',
        csvIncipit: 'At that time: Jesus said to his disciples',
        locale: 'en',
        readingType: 'first reading',
      );

      expect(decision.operation, 'rawText');
      expect(decision.warnings.join('|'), contains('csv_incipit_rejected'));
      expect(
        decision.warnings.join('|'),
        contains('gospel_formula_on_non_gospel'),
      );
    },
  );
}
