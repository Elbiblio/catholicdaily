import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'feast_reminder_payload.dart';

class FeastReminderOccurrenceStoreUnavailable implements Exception {
  const FeastReminderOccurrenceStoreUnavailable(this.reason, [this.cause]);

  final String reason;
  final Object? cause;

  @override
  String toString() => 'FeastReminderOccurrenceStoreUnavailable: $reason';
}

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
      final response = await _channel
          .invokeMethod<Object?>('claim', <String, Object>{
            'occurrenceKey': occurrenceKey,
            'celebrationDate': _dateOnly(payload.celebrationDate),
          });
      if (response is! bool) {
        throw const FeastReminderOccurrenceStoreUnavailable(
          'Malformed native claim response',
        );
      }
      return response;
    } on PlatformException catch (error) {
      debugPrint('[FeastReminder] Native duplicate claim failed: $error');
      throw FeastReminderOccurrenceStoreUnavailable(
        'Native duplicate claim failed',
        error,
      );
    } on MissingPluginException catch (error) {
      debugPrint('[FeastReminder] Native duplicate store unavailable: $error');
      throw FeastReminderOccurrenceStoreUnavailable(
        'Native duplicate store unavailable',
        error,
      );
    }
  }

  Future<Set<String>> claimedOccurrenceKeys() async {
    if (defaultTargetPlatform != TargetPlatform.android) return const {};
    try {
      final response = await _channel.invokeMethod<Object?>('claimedKeys');
      if (response is! List || response.any((key) => key is! String)) {
        throw const FeastReminderOccurrenceStoreUnavailable(
          'Malformed native claimed-key response',
        );
      }
      return response.cast<String>().toSet();
    } on PlatformException catch (error) {
      debugPrint('[FeastReminder] Native presented-key query failed: $error');
      throw FeastReminderOccurrenceStoreUnavailable(
        'Native presented-key query failed',
        error,
      );
    } on MissingPluginException catch (error) {
      debugPrint('[FeastReminder] Native duplicate store unavailable: $error');
      throw FeastReminderOccurrenceStoreUnavailable(
        'Native duplicate store unavailable',
        error,
      );
    }
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class FeastReminderScheduleClaimGuard<T> {
  const FeastReminderScheduleClaimGuard({
    required Future<Set<String>> Function() readClaimedOccurrenceKeys,
    required String Function(T occurrence) occurrenceKey,
    required Future<void> Function() onUnavailable,
  }) : _readClaimedOccurrenceKeys = readClaimedOccurrenceKeys,
       _occurrenceKey = occurrenceKey,
       _onUnavailable = onUnavailable;

  final Future<Set<String>> Function() _readClaimedOccurrenceKeys;
  final String Function(T occurrence) _occurrenceKey;
  final Future<void> Function() _onUnavailable;

  Future<FeastReminderScheduleClaimResult<T>> unclaimed(
    Iterable<T> occurrences,
  ) async {
    try {
      final claimed = await _readClaimedOccurrenceKeys();
      return FeastReminderScheduleClaimResult(
        storeAvailable: true,
        claimedOccurrenceKeys: claimed,
        retainedOccurrences: occurrences
            .where(
              (occurrence) => !claimed.contains(_occurrenceKey(occurrence)),
            )
            .toList(growable: false),
      );
    } on Object {
      await _onUnavailable();
      return FeastReminderScheduleClaimResult(
        storeAvailable: false,
        claimedOccurrenceKeys: const {},
        retainedOccurrences: const [],
      );
    }
  }

  Future<FeastReminderScheduleClaimResult<T>> cancelClaimed(
    Iterable<T> scheduledOccurrences, {
    required Future<void> Function(String occurrenceKey) cancelOccurrence,
  }) async {
    late final Set<String> claimed;
    try {
      claimed = await _readClaimedOccurrenceKeys();
    } on Object {
      final failedCancellations = <T>[];
      for (final occurrence in scheduledOccurrences) {
        final key = _occurrenceKey(occurrence);
        try {
          await cancelOccurrence(key);
        } on Object catch (error) {
          failedCancellations.add(occurrence);
          debugPrint(
            '[FeastReminder] Failed to cancel $key after native claim-store '
            'failure: $error',
          );
        }
      }
      await _onUnavailable();
      return FeastReminderScheduleClaimResult(
        storeAvailable: false,
        claimedOccurrenceKeys: const {},
        retainedOccurrences: const [],
        failedCancellationOccurrences: failedCancellations,
      );
    }
    final retained = <T>[];
    for (final occurrence in scheduledOccurrences) {
      final key = _occurrenceKey(occurrence);
      if (claimed.contains(key)) {
        await cancelOccurrence(key);
      } else {
        retained.add(occurrence);
      }
    }
    return FeastReminderScheduleClaimResult(
      storeAvailable: true,
      claimedOccurrenceKeys: claimed,
      retainedOccurrences: retained,
    );
  }
}

class FeastReminderScheduleClaimResult<T> {
  const FeastReminderScheduleClaimResult({
    required this.storeAvailable,
    required this.claimedOccurrenceKeys,
    required this.retainedOccurrences,
    this.failedCancellationOccurrences = const [],
  });

  final bool storeAvailable;
  final Set<String> claimedOccurrenceKeys;
  final List<T> retainedOccurrences;
  final List<T> failedCancellationOccurrences;
}
