import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feast_reminder_schedule_lock.dart';

/// A durable handoff proving notification repair remains pending after exit.
class NotificationRepairOutbox {
  NotificationRepairOutbox({
    Future<SharedPreferences> Function()? preferences,
    InterprocessFileLock? lock,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _lock =
           lock ??
           InterprocessFileLock(
             file: File(
               '${Directory.systemTemp.path}${Platform.pathSeparator}'
               'catholic-daily-notification-repair-outbox.lock',
             ),
           );

  static final instance = NotificationRepairOutbox();
  static const _storageKey = 'notification_repair_outbox_v1';
  static const _version = 1;
  static Future<bool> Function(String key, Future<bool> Function() write)?
  _writeInterceptor;

  final Future<SharedPreferences> Function() _preferences;
  final InterprocessFileLock _lock;

  @visibleForTesting
  static void setWriteInterceptorForTesting(
    Future<bool> Function(String key, Future<bool> Function() write) value,
  ) => _writeInterceptor = value;

  @visibleForTesting
  static void resetWriteInterceptorForTesting() => _writeInterceptor = null;

  Future<bool> get hasPendingRepair => _lock.synchronized(() async {
    final prefs = await _preferences();
    await prefs.reload();
    return prefs.getString(_storageKey) != null;
  });

  Future<String?> get pendingToken => _lock.synchronized(() async {
    final prefs = await _preferences();
    await prefs.reload();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> &&
          decoded['version'] == _version &&
          decoded['token'] is String) {
        return decoded['token'] as String;
      }
    } on FormatException {
      // A malformed marker stays pending and cannot be cleared implicitly.
    }
    return null;
  });

  Future<String> markPending({required String reason}) =>
      _lock.synchronized(() async {
        final prefs = await _preferences();
        await prefs.reload();
        final token = _newToken();
        final value = jsonEncode(<String, dynamic>{
          'version': _version,
          'token': token,
          'reason': reason,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        final succeeded =
            await (_writeInterceptor?.call(
                  _storageKey,
                  () => prefs.setString(_storageKey, value),
                ) ??
                prefs.setString(_storageKey, value));
        if (!succeeded) throw StateError('Unable to persist $_storageKey');
        return token;
      });

  Future<void> clear({String? ifToken}) => _lock.synchronized(() async {
    final prefs = await _preferences();
    await prefs.reload();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    if (ifToken != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> ||
            decoded['version'] != _version ||
            decoded['token'] != ifToken) {
          return;
        }
      } on FormatException {
        return;
      }
    }
    final succeeded =
        await (_writeInterceptor?.call(
              _storageKey,
              () => prefs.remove(_storageKey),
            ) ??
            prefs.remove(_storageKey));
    if (!succeeded) throw StateError('Unable to clear $_storageKey');
  });

  static String _newToken() {
    final random = Random.secure();
    final suffix = List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}
