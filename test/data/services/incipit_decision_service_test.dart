import 'package:catholic_daily/data/services/incipit_decision_service.dart';
import 'package:catholic_daily/data/services/incipit_processing_service.dart';
import 'package:catholic_daily/data/services/incipit_rules_service.dart';
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
