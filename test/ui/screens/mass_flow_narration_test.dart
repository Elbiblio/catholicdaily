import 'package:catholic_daily/data/models/daily_reading.dart';
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
      String? spoken;

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
              readingTextLoader: (_) async =>
                  '1 In the beginning was the Word.',
              onReadAloud: (text) async => spoken = text,
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
      expect(spoken, '1 In the beginning was the Word.');

      await tester.pumpWidget(
        card(expanded: true, status: NarrationStatus.playing),
      );
      expect(find.bySemanticsLabel('Pause reading'), findsOneWidget);
    },
  );
}
