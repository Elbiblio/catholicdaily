import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/theme_preferences.dart';
import 'package:catholic_daily/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings follows an externally recovered Bible preference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.douayRheims);

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
    expect(find.text(BibleVersionType.douayRheims.fullName), findsWidgets);

    await preference.setVersion(BibleVersionType.rsvce);
    await tester.pump();

    expect(find.text(BibleVersionType.rsvce.fullName), findsWidgets);
    expect(find.text(BibleVersionType.douayRheims.fullName), findsNothing);
  });
}
