import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/resolved_responsorial_psalm.dart';
import 'package:catholic_daily/data/services/reading_narration_controller.dart';
import 'package:catholic_daily/ui/screens/mass_flow_screen.dart';
import 'package:catholic_daily/ui/widgets/read_aloud_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'expanded Mass reading has a trailing exact-text speaker action',
    (tester) async {
      final reading = DailyReading(
        reading: 'Jn 1:1-5',
        position: 'Gospel',
        date: DateTime(2026, 8, 29),
      );
      MassFlowReadingContent? spoken;

      Widget card({required bool expanded, NarrationStatus? status}) {
        return MaterialApp(
          home: Scaffold(
            body: MassFlowReadingCard(
              key: const ValueKey<String>('reading-card'),
              reading: reading,
              index: 0,
              isExpanded: expanded,
              onToggle: () {},
              sectionColor: Colors.green,
              narrationStatus: status ?? NarrationStatus.idle,
              readingContentLoader: (_) async => const MassFlowReadingContent(
                text: '1 In the beginning was the Word.',
              ),
              onReadAloud: (content) async => spoken = content,
            ),
          ),
        );
      }

      await tester.pumpWidget(card(expanded: false));
      expect(find.byType(ReadAloudIcon), findsNothing);

      await tester.pumpWidget(card(expanded: true));
      await tester.pumpAndSettle();
      expect(find.byType(ReadAloudIcon), findsOneWidget);
      expect(find.bySemanticsLabel('Read aloud'), findsOneWidget);

      await tester.tap(find.byType(ReadAloudIcon));
      await tester.pump();
      expect(spoken?.text, '1 In the beginning was the Word.');

      await tester.pumpWidget(
        card(expanded: true, status: NarrationStatus.playing),
      );
      expect(find.bySemanticsLabel('Pause reading'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Collapse')), findsOneWidget);
    },
  );

  testWidgets('passes the exact displayed psalm resolution to narration', (
    tester,
  ) async {
    final source = ResolvedResponsorialPsalm(
      text: '1 Blessed are they.\n2 They walk in his ways.',
      responseText: 'Blessed are they who follow the law of the Lord.',
      requestedEditionId: 'ng_lectionary',
      actualEditionId: 'ng_lectionary',
      actualEditionName: 'Nigeria Lectionary',
      referenceNormalized: 'Ps 119:1-2',
      fallbackReason: PsalmFallbackReason.none,
      sourceUrl: 'asset://psalms/ng.json',
    );
    MassFlowReadingContent? spoken;
    final reading = DailyReading(
      reading: 'Ps 119:1-2',
      position: 'Responsorial Psalm',
      date: DateTime(2026, 8, 29),
      psalmResponse: 'Raw response from another edition.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MassFlowReadingCard(
            reading: reading,
            index: 0,
            isExpanded: true,
            onToggle: () {},
            sectionColor: Colors.green,
            readingContentLoader: (_) async =>
                MassFlowReadingContent(text: source.text, psalmSource: source),
            onReadAloud: (content) async => spoken = content,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ReadAloudIcon));
    await tester.pump();

    expect(spoken?.text, source.text);
    expect(spoken?.psalmSource, same(source));
  });
}
