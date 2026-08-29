import 'package:catholic_daily/data/services/notification_repair_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationRepairOutbox.resetWriteInterceptorForTesting();
  });

  tearDown(NotificationRepairOutbox.resetWriteInterceptorForTesting);

  test('pending handoff survives a new store instance', () async {
    await NotificationRepairOutbox().markPending(reason: 'settings');

    expect(await NotificationRepairOutbox().hasPendingRepair, isTrue);

    await NotificationRepairOutbox().clear();
    expect(await NotificationRepairOutbox().hasPendingRepair, isFalse);
  });

  test('checked write failure does not claim a durable handoff', () async {
    NotificationRepairOutbox.setWriteInterceptorForTesting(
      (key, write) async => false,
    );

    await expectLater(
      NotificationRepairOutbox().markPending(reason: 'settings'),
      throwsStateError,
    );
    expect(await NotificationRepairOutbox().hasPendingRepair, isFalse);
  });
}
