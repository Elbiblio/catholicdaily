import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/ui/widgets/bible_version_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
