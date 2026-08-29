import 'dart:async';

import 'package:catholic_daily/data/services/android_feast_reminder_occurrence_store.dart';
import 'package:catholic_daily/data/services/feast_reminder_messaging_service.dart';
import 'package:catholic_daily/data/services/feast_reminder_notification_contract.dart';
import 'package:catholic_daily/data/services/feast_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const occurrenceKey = 'feast:nigeria:2026-08-15:on_day:assumption';
  final payload = _validV3Data(occurrenceKey);

  test(
    'scheduler postcheck removes a local scheduled after the remote second cancel',
    () async {
      final harness = _InterleavingHarness(occurrenceKey);
      final eligible = await harness.guard.unclaimed(<String>[occurrenceKey]);

      expect(
        await harness.remote.process(payload),
        RemoteFeastMessageOutcome.shown,
      );
      await harness.schedule(eligible.single);
      final postcheck = await harness.guard.cancelClaimed(
        eligible,
        cancelOccurrence: harness.cancelLocal,
      );
      harness.persistPostcheck(postcheck);

      expect(postcheck.claimedOccurrenceKeys, <String>{occurrenceKey});
      expect(postcheck.retainedOccurrences, isEmpty);
      expect(harness.remoteCancelCount, 2);
      expect(harness.localScheduled, isFalse);
      expect(harness.localArmed, isFalse);
      expect(harness.remoteShown, isTrue);
    },
  );

  test(
    'remote second cancel removes a local scheduled between first cancel and claim',
    () async {
      final firstCancel = Completer<void>();
      final allowClaim = Completer<void>();
      final harness = _InterleavingHarness(
        occurrenceKey,
        afterFirstRemoteCancel: () {
          firstCancel.complete();
          return allowClaim.future;
        },
      );
      final eligible = await harness.guard.unclaimed(<String>[occurrenceKey]);

      final remote = harness.remote.process(payload);
      await firstCancel.future;
      await harness.schedule(eligible.single);
      allowClaim.complete();
      expect(await remote, RemoteFeastMessageOutcome.shown);
      final postcheck = await harness.guard.cancelClaimed(
        eligible,
        cancelOccurrence: harness.cancelLocal,
      );
      harness.persistPostcheck(postcheck);

      expect(postcheck.retainedOccurrences, isEmpty);
      expect(harness.remoteCancelCount, 2);
      expect(harness.localScheduled, isFalse);
      expect(harness.localArmed, isFalse);
      expect(harness.remoteShown, isTrue);
    },
  );

  test(
    'remote second cancel removes a local retained by a pre-claim postcheck',
    () async {
      final firstCancel = Completer<void>();
      final allowClaim = Completer<void>();
      final harness = _InterleavingHarness(
        occurrenceKey,
        afterFirstRemoteCancel: () {
          firstCancel.complete();
          return allowClaim.future;
        },
      );
      final eligible = await harness.guard.unclaimed(<String>[occurrenceKey]);

      final remote = harness.remote.process(payload);
      await firstCancel.future;
      await harness.schedule(eligible.single);
      final postcheck = await harness.guard.cancelClaimed(
        eligible,
        cancelOccurrence: harness.cancelLocal,
      );
      harness.persistPostcheck(postcheck);
      expect(postcheck.claimedOccurrenceKeys, isEmpty);
      expect(postcheck.retainedOccurrences, <String>[occurrenceKey]);
      expect(harness.localScheduled, isTrue);
      allowClaim.complete();

      expect(await remote, RemoteFeastMessageOutcome.shown);
      expect(harness.remoteCancelCount, 2);
      expect(harness.localScheduled, isFalse);
      expect(harness.localArmed, isFalse);
      expect(harness.remoteShown, isTrue);
    },
  );
}

class _InterleavingHarness {
  _InterleavingHarness(this.occurrenceKey, {this.afterFirstRemoteCancel}) {
    guard = FeastReminderScheduleClaimGuard(
      readClaimedOccurrenceKeys: () async =>
          claimed ? <String>{occurrenceKey} : const <String>{},
      occurrenceKey: (key) => key,
    );
    remote = RemoteFeastMessageProcessor(
      now: () => DateTime.parse('2026-08-15T06:01:00+01:00'),
      cancelOccurrence: (_) async {
        remoteCancelCount++;
        await cancelLocal(occurrenceKey);
        if (remoteCancelCount == 1 && afterFirstRemoteCancel != null) {
          await afterFirstRemoteCancel!();
        }
      },
      claimOccurrence: (_) async {
        if (claimed) return false;
        claimed = true;
        return true;
      },
      removeDeliveredOccurrence: (_) async {
        deliveredTags.remove(
          FeastReminderService.remotePresentationTag(occurrenceKey),
        );
      },
      showReminder: (_) async {
        deliveredTags.add(
          FeastReminderService.remotePresentationTag(occurrenceKey),
        );
      },
      recordReceived: (_, _) async => localArmed = false,
      recordExpired: (_, _) async {},
      enqueueReconciliation: () async {},
    );
  }

  final String occurrenceKey;
  final Future<void> Function()? afterFirstRemoteCancel;
  late FeastReminderScheduleClaimGuard<String> guard;
  late RemoteFeastMessageProcessor remote;
  final Set<String> deliveredTags = <String>{};
  bool claimed = false;
  bool localScheduled = false;
  bool localArmed = false;
  int remoteCancelCount = 0;

  bool get remoteShown => deliveredTags.contains(
    FeastReminderService.remotePresentationTag(occurrenceKey),
  );

  Future<void> schedule(String key) async {
    localScheduled = true;
    localArmed = true;
    deliveredTags.add(key);
  }

  void persistPostcheck(FeastReminderScheduleClaimResult<String> result) {
    localArmed = result.retainedOccurrences.contains(occurrenceKey);
  }

  Future<void> cancelLocal(String key) async {
    localScheduled = false;
    deliveredTags.remove(key);
  }
}

Map<String, String> _validV3Data(String occurrenceKey) => <String, String>{
  'type': 'feast_reminder',
  'schema': '3',
  'v': '3',
  'occurrence_key': occurrenceKey,
  'celebration_date': '2026-08-15',
  'scheduled_for': '2026-08-15T06:00:00+01:00',
  'remote_expires_at': '2026-08-15T06:02:00+01:00',
  'local_safety_at': '2026-08-15T06:03:00+01:00',
  'local_notification_id':
      '${FeastReminderNotificationContract.stableNotificationId(occurrenceKey)}',
  'timezone': 'Africa/Lagos',
  'liturgical_region': 'nigeria',
  'schedule_generation': FeastReminderNotificationContract.scheduleGeneration,
  'title': 'The Assumption of the Blessed Virgin Mary',
  'rank': 'Solemnity',
  'saint_id': 'assumption',
  'timing': 'on_day',
};
