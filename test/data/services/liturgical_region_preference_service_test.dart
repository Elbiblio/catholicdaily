import 'dart:ui' show Locale;
import 'package:flutter/services.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LiturgicalRegionPreferenceService.resetInstanceForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => <String, Object>{'identifier': 'Africa/Lagos'},
        );
  });

  test('persists the supplied locale region when no region exists', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = LiturgicalRegionPreferenceService.forTesting(
      prefs,
      localeRegion: () => LiturgicalRegion.nigeria,
    );

    expect(await service.detectAndSetIfUnset(), LiturgicalRegion.nigeria);
    expect(service.currentRegion, LiturgicalRegion.nigeria);
  });

  test(
    'keeps an existing region instead of replacing it with the locale',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'liturgical_region': 'US',
      });
      LiturgicalRegionPreferenceService.resetInstanceForTesting();
      final prefs = await SharedPreferences.getInstance();
      final service = LiturgicalRegionPreferenceService.forTesting(
        prefs,
        localeRegion: () => LiturgicalRegion.nigeria,
      );

      expect(
        await service.detectAndSetIfUnset(),
        LiturgicalRegion.unitedStates,
      );
    },
  );

  test('Nigeria timezone repairs an auto-detected US calendar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'liturgical_region': 'US',
      'liturgical_region_auto_detected': true,
    });
    final service = LiturgicalRegionPreferenceService.forTesting(
      await SharedPreferences.getInstance(),
      localeRegion: () => LiturgicalRegion.unitedStates,
    );
    expect(await service.detectAndSetIfUnset(), LiturgicalRegion.nigeria);
    expect(service.hasUserSelection, isFalse);
  });

  test('Nigeria timezone does not replace an explicit calendar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'liturgical_region': 'US',
      'liturgical_region_auto_detected': false,
    });
    final service = LiturgicalRegionPreferenceService.forTesting(
      await SharedPreferences.getInstance(),
      localeRegion: () => LiturgicalRegion.nigeria,
    );
    expect(await service.detectAndSetIfUnset(), LiturgicalRegion.unitedStates);
  });

  test('first calendar lookup resolves the locale before returning', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = const Locale('en', 'NG');
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    final service = await LiturgicalRegionPreferenceService.getInstance();
    expect(service.currentRegion, LiturgicalRegion.nigeria);
  });

  testWidgets(
    'cached calendar completes in the caller execution context',
    (tester) async {
      final initialized = await tester.runAsync(
        LiturgicalRegionPreferenceService.getInstance,
      );
      final cached = await LiturgicalRegionPreferenceService.getInstance();
      expect(identical(cached, initialized), isTrue);
      expect(cached.currentRegion, LiturgicalRegion.nigeria);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}
