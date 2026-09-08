import 'package:catholic_daily/ui/screens/premium_browse_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(cleanup);

  testWidgets('observances appear alongside the appointed readings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Keep SQLite callbacks in one test zone while navigating between dates.
    for (final sample in [
      (DateTime(2026, 1, 1), 'World Day of Peace', 'Mary'),
      (DateTime(2026, 4, 22), 'Earth Day', 'Easter'),
      (
        DateTime(2026, 9, 1),
        'World Day of Prayer for the Care of Creation',
        'Ordinary Time',
      ),
      (DateTime(2026, 9, 8), 'Nativity', 'Mic 5:1-4a'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumBrowseScreen(
            key: ValueKey(sample.$1),
            initialDate: sample.$1,
            onReadingSelected: (_, __, ___, [____, _____, ______]) {},
          ),
        ),
      );
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text("Loading Today's Readings").evaluate().isEmpty) break;
      }
      expect(find.textContaining(sample.$2), findsWidgets);
      expect(find.textContaining(sample.$3), findsWidgets);
      expect(find.text('Responsorial Psalm'), findsWidgets);
      expect(find.textContaining('Reading text unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
