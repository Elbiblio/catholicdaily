import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_installation.dart';

class NotificationInstallationStore {
  NotificationInstallationStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  static const _installationIdKey = 'notification_installation_id';
  static const _registrationSecretKey =
      'notification_installation_registration_secret';
  static const _registeredKey = 'notification_installation_registered';
  static const _tokenFingerprintKey =
      'notification_installation_token_fingerprint';
  static const _coverageKey = 'notification_installation_coverage_through';
  static const _lastSyncKey = 'notification_installation_last_sync_at';

  final FlutterSecureStorage _secureStorage;

  Future<NotificationInstallationCredentials> credentials() async {
    var installationId = await _secureStorage.read(key: _installationIdKey);
    var registrationSecret = await _secureStorage.read(
      key: _registrationSecretKey,
    );
    if (installationId == null || registrationSecret == null) {
      installationId = _uuidV4();
      registrationSecret = _secret();
      await _secureStorage.write(
        key: _installationIdKey,
        value: installationId,
      );
      await _secureStorage.write(
        key: _registrationSecretKey,
        value: registrationSecret,
      );
    }
    return NotificationInstallationCredentials(
      installationId: installationId,
      registrationSecret: registrationSecret,
    );
  }

  Future<bool> get isRegistered async =>
      (await SharedPreferences.getInstance()).getBool(_registeredKey) ?? false;

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
