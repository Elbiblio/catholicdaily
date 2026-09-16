import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boot notification receivers are private and receive system actions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
      ),
    );
    expect(
      manifest,
      contains(
        '<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">',
      ),
    );
    expect(manifest, contains('android:name=".FeastReminderRepairReceiver"'));
    expect(
      RegExp(
        r'<receiver\s+android:name="\.FeastReminderRepairReceiver"[\s\S]*?android:exported="false"',
      ).hasMatch(manifest),
      isTrue,
    );
    for (final action in <String>[
      'android.intent.action.BOOT_COMPLETED',
      'android.intent.action.MY_PACKAGE_REPLACED',
      'android.intent.action.TIMEZONE_CHANGED',
      'android.intent.action.TIME_SET',
      'android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED',
    ]) {
      expect(manifest, contains(action));
    }
  });
}
