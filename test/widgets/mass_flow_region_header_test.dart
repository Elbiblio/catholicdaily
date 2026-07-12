import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/ui/screens/mass_flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  testWidgets(
    'Mass flow header uses the selected regional ordo',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(LiturgicalRegion.nigeria);

      await tester.pumpWidget(
        MaterialApp(home: MassFlowScreen(date: DateTime(2026, 10, 1))),
      );
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        if (find.textContaining('Introductory Rites').evaluate().isNotEmpty ||
            find.textContaining('Our Lady').evaluate().isNotEmpty ||
            find.textContaining('No mass content').evaluate().isNotEmpty) {
          break;
        }
      }

      final visibleTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | ');

      expect(
        find.textContaining('Solemnity: Our Lady, Queen of Nigeria'),
        findsOneWidget,
        reason: visibleTexts,
      );
      expect(find.textContaining('Queen of Nigeria'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
