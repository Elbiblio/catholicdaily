import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/ui/widgets/bible_version_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  testWidgets('switcher follows an externally recovered Bible preference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.rsvce);
    var changeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BibleVersionSwitcher(onVersionChanged: () => changeCount += 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(BibleVersionType.rsvce.fullName), findsOneWidget);

    await preference.setVersion(BibleVersionType.nabre);
    await tester.pump();

    expect(find.text(BibleVersionType.nabre.fullName), findsOneWidget);
    expect(changeCount, 1);
  });

  test(
    'failed persistence leaves the effective Bible version unchanged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preference = await BibleVersionPreference.getInstance();
      await preference.setVersion(BibleVersionType.rsvce);
      SharedPreferencesStorePlatform.instance = _ThrowingPreferencesStore();

      await expectLater(
        preference.setVersion(BibleVersionType.nabre),
        throwsStateError,
      );

      expect(preference.currentVersion, BibleVersionType.rsvce);
      SharedPreferences.setMockInitialValues({});
    },
  );

  testWidgets(
    'selection invalidates before a failed write and reports the failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preference = await BibleVersionPreference.getInstance();
      await preference.setVersion(BibleVersionType.rsvce);
      final attempts = <BibleVersionType>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BibleVersionSwitcher(
              installedSourceIdsLoader: () async => const <String>{
                'rsvce',
                'nabre',
              },
              onVersionChangeStarted: (version) async {
                attempts.add(version);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BibleVersionSwitcher));
      await tester.pumpAndSettle();
      SharedPreferencesStorePlatform.instance = _ThrowingPreferencesStore();

      await tester.tap(find.text(BibleVersionType.nabre.fullName));
      await tester.pumpAndSettle();

      expect(attempts, <BibleVersionType>[BibleVersionType.nabre]);
      expect(preference.currentVersion, BibleVersionType.rsvce);
      expect(find.text('Unable to save Bible version.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      SharedPreferences.setMockInitialValues({});
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
