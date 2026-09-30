import 'package:catholic_daily/data/services/reading_text_size_preference.dart';
import 'package:catholic_daily/data/services/theme_preferences.dart';
import 'package:catholic_daily/ui/screens/reading_screen.dart';
import 'package:catholic_daily/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ReadingTextSizePreference.resetForTest();
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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
  });

  testWidgets('Settings exposes the saved reading text size', (tester) async {
    final preference = await ReadingTextSizePreference.getInstance();

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
    await tester.scrollUntilVisible(
      find.text('Reading Text Size'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Standard · 100%'), findsOneWidget);
    await tester.tap(find.text('Reading Text Size'));
    await tester.pumpAndSettle();
    expect(find.text('Extra large'), findsOneWidget);

    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(preference.currentSize, ReadingTextSize.large);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Large · 130%'), findsOneWidget);
  });

  testWidgets('reading menu changes scripture size immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingScreen(
          reference: 'Jn 1:1',
          content: '1 In the beginning was the Word.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bodyFinder = find.text('In the beginning was the Word.');
    final initial = tester.widget<Text>(bodyFinder);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Text size'), findsOneWidget);
    await tester.tap(find.text('Text size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra large'));
    await tester.pumpAndSettle();

    final enlarged = tester.widget<Text>(bodyFinder);
    expect(enlarged.style!.fontSize, greaterThan(initial.style!.fontSize!));
  });
}
