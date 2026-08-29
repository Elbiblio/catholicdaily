import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter TTS is imported only by its speech engine adapter', () {
    final imports = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains('flutter_tts'))
        .map((file) => file.path.replaceAll('\\', '/'))
        .toList();

    expect(imports, <String>[
      'lib/data/services/flutter_tts_speech_engine.dart',
    ]);
  });

  test('Android manifest queries TTS service without removing receivers', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.intent.action.TTS_SERVICE'));
    expect(manifest, contains('ScheduledNotificationReceiver'));
    expect(manifest, contains('FeastReminderRepairReceiver'));
  });
}
