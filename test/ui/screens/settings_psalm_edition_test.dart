import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_preference.dart';
import 'package:catholic_daily/data/services/theme_preferences.dart';
import 'package:catholic_daily/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings selects psalm edition independently of Bible', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ResponsorialPsalmPreference.resetForTest();
    const packageInfoChannel = MethodChannel(
      'dev.fluttercommunity.plus/package_info',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (_) async {
          return <String, dynamic>{
            'appName': 'Catholic Daily',
            'packageName': 'com.elbiblio.catholicdaily',
            'version': '1.0.0',
            'buildNumber': '1',
            'buildSignature': '',
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(packageInfoChannel, null);
    });

    final bible = await BibleVersionPreference.getInstance();
    await bible.setVersion(BibleVersionType.rsvce);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          versions: const [],
          themeMode: ThemeMode.light,
          themeStyle: AppThemeStyle.standard,
          onThemeModeChanged: (_) {},
          onThemeStyleChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.text('Responsorial Psalm text');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    final nigeria = find.text('Catholic Missal for Nigeria');
    await tester.ensureVisible(nigeria);
    await tester.tap(nigeria);
    await tester.pumpAndSettle();

    final psalm = await ResponsorialPsalmPreference.getInstance();
    expect(psalm.currentEditionId, 'nigeria_365_firestore');
    expect(bible.currentVersion, BibleVersionType.rsvce);
  });
}
