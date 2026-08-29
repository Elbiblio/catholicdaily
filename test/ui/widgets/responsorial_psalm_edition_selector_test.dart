import 'package:catholic_daily/data/services/responsorial_psalm_preference.dart';
import 'package:catholic_daily/ui/widgets/responsorial_psalm_edition_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  testWidgets(
    'selection invalidates before a failed write and reports the failure',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
      final preference = await ResponsorialPsalmPreference.getInstance();
      final attempts = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsorialPsalmEditionSelector(
              onEditionChangeStarted: (editionId) async {
                attempts.add(editionId);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Responsorial Psalm text'));
      await tester.pumpAndSettle();
      SharedPreferencesStorePlatform.instance = _ThrowingPreferencesStore();

      await tester.tap(find.text('Catholic Daily RSVCE database'));
      await tester.pumpAndSettle();

      expect(attempts, <String>['local_rsvce']);
      expect(
        preference.currentEditionId,
        ResponsorialPsalmPreference.defaultEditionId,
      );
      expect(
        find.text('Unable to save responsorial psalm edition.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
    },
  );
}

class _ThrowingPreferencesStore extends InMemorySharedPreferencesStore {
  _ThrowingPreferencesStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    throw StateError('disk unavailable');
  }
}
