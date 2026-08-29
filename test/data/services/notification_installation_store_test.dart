import 'dart:io';

import 'package:catholic_daily/data/services/feast_reminder_schedule_lock.dart';
import 'package:catholic_daily/data/services/notification_installation_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent first use returns one atomic credential pair', () async {
    final values = <String, String>{};
    final lockFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'notification-installation-store-${DateTime.now().microsecondsSinceEpoch}.lock',
    );
    Future<String?> read(String key) async => values[key];
    Future<void> write(String key, String value) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      values[key] = value;
    }

    Future<void> delete(String key) async => values.remove(key);
    NotificationInstallationStore store() => NotificationInstallationStore(
      secureRead: read,
      secureWrite: write,
      secureDelete: delete,
      credentialLock: InterprocessFileLock(file: lockFile),
    );

    final credentials = await Future.wait([
      store().credentials(),
      store().credentials(),
    ]);

    expect(credentials[0].installationId, credentials[1].installationId);
    expect(
      credentials[0].registrationSecret,
      credentials[1].registrationSecret,
    );
    expect(values.keys, contains('notification_installation_credentials_v1'));
    expect(values.keys, isNot(contains('notification_installation_id')));
    expect(
      values.keys,
      isNot(contains('notification_installation_registration_secret')),
    );
  });

  test('migrates a complete legacy credential pair into one envelope', () async {
    final values = <String, String>{
      'notification_installation_id': '123e4567-e89b-42d3-a456-426614174000',
      'notification_installation_registration_secret': 'legacy-secret',
    };
    final store = NotificationInstallationStore(
      secureRead: (key) async => values[key],
      secureWrite: (key, value) async => values[key] = value,
      secureDelete: (key) async => values.remove(key),
      credentialLock: InterprocessFileLock(
        file: File(
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'notification-installation-migrate-${DateTime.now().microsecondsSinceEpoch}.lock',
        ),
      ),
    );

    final credentials = await store.credentials();

    expect(credentials.installationId, '123e4567-e89b-42d3-a456-426614174000');
    expect(credentials.registrationSecret, 'legacy-secret');
    expect(values.keys, contains('notification_installation_credentials_v1'));
    expect(values.keys, isNot(contains('notification_installation_id')));
    expect(
      values.keys,
      isNot(contains('notification_installation_registration_secret')),
    );
  });
}
