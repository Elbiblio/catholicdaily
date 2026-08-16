import 'package:catholic_daily/data/models/bible_version.dart';
import 'package:catholic_daily/data/services/offline_bible_service.dart';
import 'package:catholic_daily/data/services/theme_preferences.dart';
import 'package:catholic_daily/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('download failure is explained in the translations dialog', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          versions: const [],
          themeMode: ThemeMode.light,
          themeStyle: AppThemeStyle.standard,
          onThemeModeChanged: (_) {},
          onThemeStyleChanged: (_) {},
          offlineBibleService: _FailingOfflineBibleService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Data & Downloads'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Data & Downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();

    expect(
      find.text('Download failed. Check your connection and try again.'),
      findsOneWidget,
    );
  });
}

class _FailingOfflineBibleService extends OfflineBibleService {
  @override
  Future<List<BibleVersion>> fetchAvailableVersions() async => [
    BibleVersion(
      id: 'rsvce',
      name: 'Revised Standard Version Catholic Edition',
      abbreviation: 'RSVCE',
      isDownloaded: true,
    ),
    BibleVersion(
      id: 'nabre',
      name: 'New American Bible Revised Edition',
      abbreviation: 'NABRE',
      isDownloaded: true,
    ),
    BibleVersion(
      id: 'douay_rheims',
      name: 'Douay-Rheims Bible',
      abbreviation: 'DR',
      downloadUrl: 'https://example.test/engdra.db',
      dbFilename: 'engdra.db',
    ),
  ];

  @override
  Future<void> downloadVersion(
    BibleVersion version,
    Function(double) onProgress,
  ) => Future<void>.error(Exception('network unavailable'));
}
