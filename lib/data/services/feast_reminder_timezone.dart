import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class FeastReminderTimezone {
  const FeastReminderTimezone._();

  /// Configures timezone's process-local location from the device IANA zone.
  static Future<String> configure() async {
    tzdata.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(timezone.identifier);
      tz.setLocalLocation(location);
      return location.name;
    } catch (error, stackTrace) {
      debugPrint(
        '[FeastReminder] Unable to resolve device timezone; using ${tz.local.name}: '
        '$error\n$stackTrace',
      );
      return tz.local.name;
    }
  }
}
