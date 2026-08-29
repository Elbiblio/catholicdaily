import 'dart:io';

import 'package:catholic_daily/data/services/feast_reminder_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('iOS advertises and registers durable repair processing tasks', () {
    final plist = XmlDocument.parse(
      File('ios/Runner/Info.plist').readAsStringSync(),
    );
    final plistText = plist.toXmlString();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final backgroundService = File(
      'lib/data/services/feast_reminder_background_service.dart',
    ).readAsStringSync();
    final messagingService = File(
      'lib/data/services/feast_reminder_messaging_service.dart',
    ).readAsStringSync();

    expect(plistText, contains('<string>processing</string>'));
    expect(
      plistText,
      contains(FeastReminderBackgroundService.iosRepairTaskIdentifier),
    );
    expect(
      plistText,
      contains(FeastReminderBackgroundService.iosForcedRepairTaskIdentifier),
    );
    expect(appDelegate, contains('import workmanager_apple'));
    expect(appDelegate, contains('setPluginRegistrantCallback'));
    expect(backgroundService, contains('registerProcessingTask('));
    expect(backgroundService, contains('registerOneOffTask('));
    expect(backgroundService, contains('throw UnsupportedError('));
    expect(messagingService, contains('NotificationScheduleSyncCoordinator('));
    expect(
      appDelegate,
      contains(
        'registerBGProcessingTask(withIdentifier: "${FeastReminderBackgroundService.iosRepairTaskIdentifier}")',
      ),
    );
    expect(
      appDelegate,
      contains(
        'registerBGProcessingTask(withIdentifier: "${FeastReminderBackgroundService.iosForcedRepairTaskIdentifier}")',
      ),
    );
  });

  test('iOS repair identifiers map to the intended force policy', () {
    expect(
      FeastReminderRepairRequest.fromWorkmanager(
        FeastReminderBackgroundService.iosRepairTaskIdentifier,
        null,
      ).forceReschedule,
      isFalse,
    );
    expect(
      FeastReminderRepairRequest.fromWorkmanager(
        FeastReminderBackgroundService.iosForcedRepairTaskIdentifier,
        null,
      ).forceReschedule,
      isTrue,
    );
  });
}
