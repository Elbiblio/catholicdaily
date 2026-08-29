import 'dart:convert';

import 'package:catholic_daily/data/services/narration_preferences.dart';
import 'package:catholic_daily/data/services/speech_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NarrationPreferences.resetWriteInterceptorForTesting();
  });

  tearDown(NarrationPreferences.resetWriteInterceptorForTesting);

  test('uses conservative offline-friendly defaults', () async {
    final settings = await NarrationPreferences().load();

    expect(settings.rate, NarrationPreferences.defaultRate);
    expect(settings.language, NarrationPreferences.defaultLanguage);
    expect(settings.voice, isNull);
  });

  test('persists and restores rate, language, and installed voice', () async {
    const expected = SpeechEngineSettings(
      rate: 0.62,
      language: 'en-NG',
      voice: SpeechVoice(
        name: 'English Nigeria',
        locale: 'en-NG',
        isNetworkRequired: false,
      ),
    );

    await NarrationPreferences().save(expected);
    final restored = await NarrationPreferences().load();

    expect(restored.rate, expected.rate);
    expect(restored.language, expected.language);
    expect(restored.voice, expected.voice);
  });

  test('convenience updates preserve unrelated settings', () async {
    final preferences = NarrationPreferences();
    await preferences.save(
      const SpeechEngineSettings(
        rate: 0.4,
        language: 'en-GB',
        voice: SpeechVoice(name: 'Local', locale: 'en-GB'),
      ),
    );

    await preferences.setRate(0.7);
    await preferences.setLanguage('en-NG');

    final restored = await preferences.load();
    expect(restored.rate, 0.7);
    expect(restored.language, 'en-NG');
    expect(restored.voice?.name, 'Local');
  });

  test('rejects invalid settings before changing durable state', () async {
    final preferences = NarrationPreferences();
    await preferences.save(const SpeechEngineSettings(rate: 0.5));

    await expectLater(
      preferences.save(const SpeechEngineSettings(rate: 1.5)),
      throwsArgumentError,
    );
    await expectLater(preferences.setLanguage('   '), throwsArgumentError);

    expect((await preferences.load()).rate, 0.5);
  });

  test('throws when SharedPreferences rejects the checked write', () async {
    final raw = await SharedPreferences.getInstance();
    await raw.setString(
      NarrationPreferences.storageKey,
      jsonEncode(<String, Object>{
        'version': 1,
        'rate': 0.5,
        'language': 'en-US',
      }),
    );
    NarrationPreferences.setWriteInterceptorForTesting((_, __) async => false);

    await expectLater(
      NarrationPreferences().setRate(0.8),
      throwsA(isA<StateError>()),
    );

    expect((await NarrationPreferences().load()).rate, 0.5);
  });

  test(
    'migrates legacy speech preferences after a successful checked write',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        NarrationPreferences.legacyRateKey: 0.58,
        NarrationPreferences.legacyLanguageKey: 'en-GB',
        NarrationPreferences.legacyVoiceNameKey: 'Legacy Local',
        NarrationPreferences.legacyVoiceLocaleKey: 'en-GB',
      });

      final restored = await NarrationPreferences().load();

      expect(restored.rate, 0.58);
      expect(restored.language, 'en-GB');
      expect(restored.voice?.name, 'Legacy Local');
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString(NarrationPreferences.storageKey), isNotNull);
      expect(raw.containsKey(NarrationPreferences.legacyRateKey), isFalse);
      expect(raw.containsKey(NarrationPreferences.legacyLanguageKey), isFalse);
    },
  );

  test('corrupt or future preference documents fall back safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      NarrationPreferences.storageKey: '{not-json',
    });
    expect(
      (await NarrationPreferences().load()).rate,
      NarrationPreferences.defaultRate,
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      NarrationPreferences.storageKey: jsonEncode(<String, Object>{
        'version': 99,
        'rate': 0.9,
        'language': 'fr-FR',
      }),
    });
    final future = await NarrationPreferences().load();
    expect(future.rate, NarrationPreferences.defaultRate);
    expect(future.language, NarrationPreferences.defaultLanguage);
  });
}
