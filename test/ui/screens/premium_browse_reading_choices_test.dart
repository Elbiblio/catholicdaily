import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/ui/screens/premium_browse_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  testWidgets(
    'Assumption proper readings render first and choices are usable',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(LiturgicalRegion.nigeria);

      await tester.pumpWidget(
        MaterialApp(
          home: PremiumBrowseScreen(
            initialDate: DateTime(2026, 8, 15),
            onReadingSelected: (_, __, ___, [____, _____, ______]) {},
          ),
        ),
      );
      for (
        var i = 0;
        i < 40 &&
            find.byKey(const ValueKey('reading-choice-0')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }

      expect(find.byKey(const ValueKey('reading-choice-0')), findsOneWidget);
      expect(find.textContaining('Assumption'), findsWidgets);
      expect(find.textContaining('Primary'), findsOneWidget);

      final primaryReference = find.text('Rev 11:19a; 12:1-6a, 10ab');
      for (var i = 0; i < 10 && primaryReference.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(primaryReference, findsWidgets);

      final vigilChoice = find.byKey(const ValueKey('reading-choice-1'));
      expect(vigilChoice, findsOneWidget);
      await tester.ensureVisible(vigilChoice);
      await tester.tap(vigilChoice);
      for (
        var i = 0;
        i < 40 &&
            find
                .text('1 Chr 15:3-4, 15-16; 16:1-2', skipOffstage: false)
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }

      final vigilReference = find.text('1 Chr 15:3-4, 15-16; 16:1-2');
      for (var i = 0; i < 10 && vigilReference.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(vigilReference, findsWidgets);
    },
  );
}
