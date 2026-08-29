import 'package:catholic_daily/data/services/reading_narration_controller.dart';
import 'package:catholic_daily/ui/widgets/read_aloud_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final testCase
      in <({NarrationStatus status, IconData icon, String label})>[
        (
          status: NarrationStatus.idle,
          icon: Icons.volume_up_outlined,
          label: 'Read aloud',
        ),
        (
          status: NarrationStatus.playing,
          icon: Icons.pause_rounded,
          label: 'Pause reading',
        ),
        (
          status: NarrationStatus.paused,
          icon: Icons.play_arrow_rounded,
          label: 'Resume reading',
        ),
      ]) {
    testWidgets('${testCase.status.name} has one compact semantic action', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: <Widget>[
                ReadAloudIcon(status: testCase.status, onPressed: () => taps++),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(testCase.icon), findsOneWidget);
      expect(find.bySemanticsLabel(testCase.label), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);

      final size = tester.getSize(find.byType(ReadAloudIcon));
      expect(size.width, 48);
      expect(size.height, 48);
      final icon = tester.widget<Icon>(find.byIcon(testCase.icon));
      expect(icon.size, lessThanOrEqualTo(24));

      await tester.tap(find.byType(ReadAloudIcon));
      expect(taps, 1);
    });
  }
}
