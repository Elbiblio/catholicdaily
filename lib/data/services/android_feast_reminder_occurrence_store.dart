import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'feast_reminder_payload.dart';

class AndroidFeastReminderOccurrenceStore {
  const AndroidFeastReminderOccurrenceStore._();

  static const instance = AndroidFeastReminderOccurrenceStore._();
  static const MethodChannel _channel = MethodChannel(
    'com.elbiblio.catholicdaily/feast_reminder_occurrence_store',
  );

  Future<bool> claim(FeastReminderPayload payload) async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final occurrenceKey = payload.occurrenceKey;
    if (occurrenceKey == null || occurrenceKey.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('claim', <String, Object>{
            'occurrenceKey': occurrenceKey,
            'celebrationDate': _dateOnly(payload.celebrationDate),
          }) ??
          false;
    } on PlatformException catch (error) {
      debugPrint('[FeastReminder] Native duplicate claim failed: $error');
      return false;
    } on MissingPluginException catch (error) {
      debugPrint('[FeastReminder] Native duplicate store unavailable: $error');
      return false;
    }
  }

  Future<Set<String>> claimedOccurrenceKeys() async {
    if (defaultTargetPlatform != TargetPlatform.android) return const {};
    try {
      final keys = await _channel.invokeListMethod<String>('claimedKeys');
      return keys?.toSet() ?? const {};
    } on PlatformException catch (error) {
      debugPrint('[FeastReminder] Native presented-key query failed: $error');
      return const {};
    } on MissingPluginException catch (error) {
      debugPrint('[FeastReminder] Native duplicate store unavailable: $error');
      return const {};
    }
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
