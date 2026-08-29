import 'dart:async';
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

  test('wrongly typed current and legacy values migrate safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      NarrationPreferences.storageKey: 7,
      NarrationPreferences.legacyRateKey: 'fast',
      NarrationPreferences.legacyLanguageKey: 42,
      NarrationPreferences.legacyVoiceNameKey: true,
      NarrationPreferences.legacyVoiceLocaleKey: <String>['en-US'],
    });

    final settings = await NarrationPreferences().load();

    expect(settings.rate, NarrationPreferences.defaultRate);
    expect(settings.language, NarrationPreferences.defaultLanguage);
    expect(settings.voice, isNull);
    final raw = await SharedPreferences.getInstance();
    expect(raw.get(NarrationPreferences.storageKey), isA<String>());
    expect(raw.containsKey(NarrationPreferences.legacyRateKey), isFalse);
    expect(raw.containsKey(NarrationPreferences.legacyLanguageKey), isFalse);
    expect(raw.containsKey(NarrationPreferences.legacyVoiceNameKey), isFalse);
    expect(raw.containsKey(NarrationPreferences.legacyVoiceLocaleKey), isFalse);
  });

  test(
    'concurrent instances do not lose rate language or voice updates',
    () async {
      final first = NarrationPreferences();
      final second = NarrationPreferences();
      final third = NarrationPreferences();
      await first.save(const SpeechEngineSettings());
      final firstWriteEntered = Completer<void>();
      final releaseFirstWrite = Completer<void>();
      var interceptedWrites = 0;
      NarrationPreferences.setWriteInterceptorForTesting((_, write) async {
        interceptedWrites++;
        if (interceptedWrites == 1) {
          firstWriteEntered.complete();
          await releaseFirstWrite.future;
        }
        return write();
      });

      final rate = first.setRate(0.72);
      await firstWriteEntered.future;
      final language = second.setLanguage('en-NG');
      final voice = third.setVoice(
        const SpeechVoice(name: 'English Nigeria', locale: 'en-NG'),
      );
      releaseFirstWrite.complete();
      await Future.wait<void>(<Future<void>>[rate, language, voice]);

      final restored = await NarrationPreferences().load();
      expect(restored.rate, 0.72);
      expect(restored.language, 'en-NG');
      expect(restored.voice?.name, 'English Nigeria');
    },
  );
}
