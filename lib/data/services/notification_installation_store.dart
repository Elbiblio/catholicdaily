import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_installation.dart';
import 'feast_reminder_schedule_lock.dart';

typedef SecureValueRead = Future<String?> Function(String key);
typedef SecureValueWrite = Future<void> Function(String key, String value);
typedef SecureValueDelete = Future<void> Function(String key);

class NotificationInstallationStore {
  NotificationInstallationStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
    SecureValueRead? secureRead,
    SecureValueWrite? secureWrite,
    SecureValueDelete? secureDelete,
    InterprocessFileLock? credentialLock,
  }) : _secureRead = secureRead ?? ((key) => secureStorage.read(key: key)),
       _secureWrite =
           secureWrite ??
           ((key, value) => secureStorage.write(key: key, value: value)),
       _secureDelete =
           secureDelete ?? ((key) => secureStorage.delete(key: key)),
       _credentialLock =
           credentialLock ??
           InterprocessFileLock(
             file: File(
               '${Directory.systemTemp.path}${Platform.pathSeparator}'
               'catholic-daily-notification-installation-credentials.lock',
             ),
           );

  static const _credentialEnvelopeKey =
      'notification_installation_credentials_v1';
  static const _credentialEnvelopeVersion = 1;
  static const _installationIdKey = 'notification_installation_id';
  static const _registrationSecretKey =
      'notification_installation_registration_secret';
  static const _registeredKey = 'notification_installation_registered';
  static const _tokenFingerprintKey =
      'notification_installation_token_fingerprint';
  static const _coverageKey = 'notification_installation_coverage_through';
  static const _lastSyncKey = 'notification_installation_last_sync_at';

  final SecureValueRead _secureRead;
  final SecureValueWrite _secureWrite;
  final SecureValueDelete _secureDelete;
  final InterprocessFileLock _credentialLock;

  Future<NotificationInstallationCredentials> credentials() =>
      _credentialLock.synchronized(() async {
        final envelope = _decodeCredentials(
          await _secureRead(_credentialEnvelopeKey),
        );
        if (envelope != null) return envelope;

        var installationId = await _secureRead(_installationIdKey);
        var registrationSecret = await _secureRead(_registrationSecretKey);
        if (installationId == null || registrationSecret == null) {
          installationId = _uuidV4();
          registrationSecret = _secret();
        }
        final credentials = NotificationInstallationCredentials(
          installationId: installationId,
          registrationSecret: registrationSecret,
        );
        await _secureWrite(
          _credentialEnvelopeKey,
          jsonEncode(<String, dynamic>{
            'version': _credentialEnvelopeVersion,
            'installation_id': credentials.installationId,
            'registration_secret': credentials.registrationSecret,
          }),
        );
        await _secureDelete(_installationIdKey);
        await _secureDelete(_registrationSecretKey);
        return credentials;
      });

  static NotificationInstallationCredentials? _decodeCredentials(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _credentialEnvelopeVersion) {
        return null;
      }
      final installationId = decoded['installation_id'];
      final registrationSecret = decoded['registration_secret'];
      if (installationId is! String ||
          installationId.isEmpty ||
          registrationSecret is! String ||
          registrationSecret.isEmpty) {
        return null;
      }
      return NotificationInstallationCredentials(
        installationId: installationId,
        registrationSecret: registrationSecret,
      );
    } on FormatException {
      return null;
    }
  }

  Future<bool> get isRegistered async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_registeredKey) ?? false;
  }

  Future<void> markRegistered(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_registeredKey, value);

  Future<void> markSynchronized(NotificationInstallationState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tokenFingerprintKey,
      sha256.convert(utf8.encode(state.fcmToken)).toString(),
    );
    final coverage = state.coverageThrough;
    if (coverage == null) {
      await prefs.remove(_coverageKey);
    } else {
      await prefs.setInt(_coverageKey, coverage.millisecondsSinceEpoch);
    }
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  static String _uuidV4() {
    final bytes = _randomBytes(16);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static String _secret() =>
      base64UrlEncode(_randomBytes(32)).replaceAll('=', '');

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
