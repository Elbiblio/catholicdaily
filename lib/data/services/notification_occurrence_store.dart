import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_occurrence.dart';
import 'feast_reminder_schedule_lock.dart';

class NotificationOccurrenceLedgerException implements Exception {
  const NotificationOccurrenceLedgerException(this.reason);

  final String reason;

  @override
  String toString() => 'NotificationOccurrenceLedgerException: $reason';
}

class NotificationOccurrenceStore {
  NotificationOccurrenceStore({
    Future<SharedPreferences> Function()? preferences,
    InterprocessFileLock? lock,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _lock =
           lock ??
           InterprocessFileLock(
             file: File(
               '${Directory.systemTemp.path}${Platform.pathSeparator}'
               'catholic-daily-notification-occurrences.lock',
             ),
           );

  static const _storageKey = 'notification_occurrences_v1';
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

  Future<List<NotificationOccurrence>> allOccurrences() async =>
      List<NotificationOccurrence>.unmodifiable((await _read()).occurrences);

  Future<List<NotificationOccurrence>> pendingOccurrences() async =>
      List<NotificationOccurrence>.unmodifiable(
        (await _read()).occurrences.where((row) => row.needsSync),
      );

  Future<List<NotificationOccurrenceEvent>> pendingEvents() async =>
      List<NotificationOccurrenceEvent>.unmodifiable((await _read()).events);

  Future<void> upsertAll(Iterable<NotificationOccurrence> rows) =>
      _mutate((document) {
        final byKey = <String, NotificationOccurrence>{
          for (final row in document.occurrences) row.occurrenceKey: row,
        };
        for (final incoming in rows) {
          final existing = byKey[incoming.occurrenceKey];
          byKey[incoming.occurrenceKey] = _mergeOccurrence(existing, incoming);
        }
        return document.copyWith(occurrences: byKey.values.toList());
      });

  Future<void> replaceSchedule(
    Iterable<NotificationOccurrence> rows, {
    required DateTime reconciledAt,
  }) => _mutate((document) {
    final incoming = <String, NotificationOccurrence>{
      for (final row in rows) row.occurrenceKey: row,
    };
    final events = <String, NotificationOccurrenceEvent>{
      for (final event in document.events) event.id: event,
    };
    final updated = <String, NotificationOccurrence>{};
    for (final existing in document.occurrences) {
      final replacement = incoming.remove(existing.occurrenceKey);
      if (replacement != null) {
        if (existing.reconciledAt != null) {
          events.removeWhere(
            (_, event) => event.occurrenceKey == existing.occurrenceKey,
          );
          updated[existing.occurrenceKey] = replacement.copyWith(
            clearLastSyncedAt: true,
          );
        } else {
          updated[existing.occurrenceKey] = _mergeOccurrence(
            existing,
            replacement,
          );
        }
      } else if (existing.reconciledAt == null) {
        final event = NotificationOccurrenceEvent(
          occurrenceKey: existing.occurrenceKey,
          type: NotificationOccurrenceEventType.reconciled,
          occurredAt: reconciledAt,
        );
        events[event.id] = event;
        updated[existing.occurrenceKey] = existing.copyWith(
          localArmed: false,
          reconciledAt: reconciledAt,
          clearLastSyncedAt: true,
        );
      } else {
        updated[existing.occurrenceKey] = existing;
      }
    }
    for (final row in incoming.values) {
      updated[row.occurrenceKey] = row.copyWith(clearLastSyncedAt: true);
    }
    return document.copyWith(
      occurrences: updated.values.toList(growable: false),
      events: events.values.toList(growable: false),
    );
  });

  Future<void> recordEvent(NotificationOccurrenceEvent event) =>
      _mutate((document) {
        final events = <String, NotificationOccurrenceEvent>{
          for (final item in document.events) item.id: item,
          event.id: event,
        };
        final occurrences = document.occurrences
            .map((row) {
              if (row.occurrenceKey != event.occurrenceKey) return row;
              return switch (event.type) {
                NotificationOccurrenceEventType.received => row.copyWith(
                  receivedAt: event.occurredAt,
                  clearLastSyncedAt: true,
                ),
                NotificationOccurrenceEventType.opened => row.copyWith(
                  openedAt: event.occurredAt,
                  clearLastSyncedAt: true,
                ),
                NotificationOccurrenceEventType.expired => row.copyWith(
                  expiredAt: event.occurredAt,
                  clearLastSyncedAt: true,
                ),
                NotificationOccurrenceEventType.reconciled => row.copyWith(
                  localArmed: false,
                  reconciledAt: event.occurredAt,
                  clearLastSyncedAt: true,
                ),
              };
            })
            .toList(growable: false);
        return document.copyWith(
          occurrences: occurrences,
          events: events.values.toList(growable: false),
        );
      });

  Future<void> markSynchronized({
    required Iterable<NotificationOccurrence> occurrences,
    required Iterable<String> eventIds,
    required DateTime synchronizedAt,
  }) => _mutate((document) {
    final sentByKey = <String, NotificationOccurrence>{
      for (final row in occurrences) row.occurrenceKey: row,
    };
    final sentEventIds = eventIds.toSet();
    return document.copyWith(
      occurrences: document.occurrences
          .map(
            (row) =>
                sentByKey[row.occurrenceKey]?.hasSameServerState(row) == true
                ? row.copyWith(lastSyncedAt: synchronizedAt)
                : row,
          )
          .toList(growable: false),
      events: document.events
          .where((event) => !sentEventIds.contains(event.id))
          .toList(growable: false),
    );
  });

  Future<void> reconcileExpired({required DateTime now}) => _mutate((document) {
    final events = <String, NotificationOccurrenceEvent>{
      for (final event in document.events) event.id: event,
    };
    final occurrences = document.occurrences
        .map((row) {
          var updated = row;
          if (!row.remoteExpiresAt.isAfter(now) && row.expiredAt == null) {
            final event = NotificationOccurrenceEvent(
              occurrenceKey: row.occurrenceKey,
              type: NotificationOccurrenceEventType.expired,
              occurredAt: now,
            );
            events[event.id] = event;
            updated = updated.copyWith(expiredAt: now, clearLastSyncedAt: true);
          }
          if (!row.localSafetyAt.isAfter(now) && row.reconciledAt == null) {
            final event = NotificationOccurrenceEvent(
              occurrenceKey: row.occurrenceKey,
              type: NotificationOccurrenceEventType.reconciled,
              occurredAt: now,
            );
            events[event.id] = event;
            updated = updated.copyWith(
              localArmed: false,
              reconciledAt: now,
              clearLastSyncedAt: true,
            );
          }
          return updated;
        })
        .toList(growable: false);
    return document.copyWith(
      occurrences: occurrences,
      events: events.values.toList(growable: false),
    );
  });

  Future<void> reconcileLocalArming({
    required Set<String> pendingOccurrenceKeys,
    required DateTime reconciledAt,
  }) => _mutate((document) {
    final events = <String, NotificationOccurrenceEvent>{
      for (final event in document.events) event.id: event,
    };
    final occurrences = document.occurrences
        .map((row) {
          if (!row.localArmed ||
              row.reconciledAt != null ||
              pendingOccurrenceKeys.contains(row.occurrenceKey)) {
            return row;
          }
          final event = NotificationOccurrenceEvent(
            occurrenceKey: row.occurrenceKey,
            type: NotificationOccurrenceEventType.reconciled,
            occurredAt: reconciledAt,
          );
          events[event.id] = event;
          return row.copyWith(
            localArmed: false,
            reconciledAt: reconciledAt,
            clearLastSyncedAt: true,
          );
        })
        .toList(growable: false);
    return document.copyWith(
      occurrences: occurrences,
      events: events.values.toList(growable: false),
    );
  });

  Future<void> prune({
    required DateTime now,
    Duration retention = const Duration(days: 7),
  }) => _mutate((document) {
    final cutoff = now.subtract(retention);
    final keysWithPendingEvents = document.events
        .map((event) => event.occurrenceKey)
        .toSet();
    final retained = document.occurrences
        .where(
          (row) =>
              row.reconciledAt == null ||
              row.needsSync ||
              keysWithPendingEvents.contains(row.occurrenceKey) ||
              !row.remoteExpiresAt.isBefore(cutoff),
        )
        .toList(growable: false);
    final retainedKeys = retained.map((row) => row.occurrenceKey).toSet();
    return document.copyWith(
      occurrences: retained,
      events: document.events
          .where((event) => retainedKeys.contains(event.occurrenceKey))
          .toList(growable: false),
    );
  });

  Future<_OccurrenceDocument> _read() => _lock.synchronized(() async {
    final preferences = await _preferences();
    await preferences.reload();
    return _decode(preferences.getString(_storageKey));
  });

  _OccurrenceDocument _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const _OccurrenceDocument();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const NotificationOccurrenceLedgerException(
          'ledger root must be an object',
        );
      }
      if (decoded['version'] != _version) {
        throw const NotificationOccurrenceLedgerException(
          'unsupported ledger version',
        );
      }
      final occurrenceValues = decoded['occurrences'];
      final eventValues = decoded['events'];
      if (occurrenceValues is! List || eventValues is! List) {
        throw const NotificationOccurrenceLedgerException(
          'ledger rows and events must be lists',
        );
      }
      final occurrences = <NotificationOccurrence>[];
      for (final value in occurrenceValues) {
        final occurrence = NotificationOccurrence.tryFromStorageJson(value);
        if (occurrence == null) {
          throw const NotificationOccurrenceLedgerException(
            'ledger contains an invalid occurrence',
          );
        }
        occurrences.add(occurrence);
      }
      final events = <NotificationOccurrenceEvent>[];
      for (final value in eventValues) {
        final event = NotificationOccurrenceEvent.tryFromJson(value);
        if (event == null) {
          throw const NotificationOccurrenceLedgerException(
            'ledger contains an invalid event',
          );
        }
        events.add(event);
      }
      return _OccurrenceDocument(occurrences: occurrences, events: events);
    } on NotificationOccurrenceLedgerException {
      rethrow;
    } on FormatException {
      throw const NotificationOccurrenceLedgerException('malformed ledger');
    } on TypeError {
      throw const NotificationOccurrenceLedgerException(
        'ledger contains invalid field types',
      );
    }
  }

  Future<void> _mutate(
    _OccurrenceDocument Function(_OccurrenceDocument document) change,
  ) => _lock.synchronized(() async {
    final prefs = await _preferences();
    await prefs.reload();
    final next = change(_decode(prefs.getString(_storageKey)));
    final encoded = jsonEncode(next.toJson());
    final succeeded =
        await (_writeInterceptor?.call(
              _storageKey,
              () => prefs.setString(_storageKey, encoded),
            ) ??
            prefs.setString(_storageKey, encoded));
    if (!succeeded) throw StateError('Unable to persist $_storageKey');
  });
}

NotificationOccurrence _mergeOccurrence(
  NotificationOccurrence? existing,
  NotificationOccurrence incoming,
) {
  if (existing == null) return incoming.copyWith(clearLastSyncedAt: true);
  final merged = NotificationOccurrence(
    occurrenceKey: incoming.occurrenceKey,
    localNotificationId: incoming.localNotificationId,
    scheduledFor: incoming.scheduledFor,
    remoteExpiresAt: incoming.remoteExpiresAt,
    localSafetyAt: incoming.localSafetyAt,
    platform: incoming.platform,
    scheduleGeneration: incoming.scheduleGeneration,
    timezone: incoming.timezone,
    configurationFingerprint: incoming.configurationFingerprint,
    localArmed: incoming.localArmed,
    payload: incoming.payload,
    receivedAt: incoming.receivedAt ?? existing.receivedAt,
    openedAt: incoming.openedAt ?? existing.openedAt,
    expiredAt: incoming.expiredAt ?? existing.expiredAt,
    reconciledAt: incoming.reconciledAt ?? existing.reconciledAt,
    lastSyncedAt: existing.lastSyncedAt,
  );
  return merged.hasSameServerState(existing)
      ? merged
      : merged.copyWith(clearLastSyncedAt: true);
}

class _OccurrenceDocument {
  const _OccurrenceDocument({
    this.occurrences = const [],
    this.events = const [],
  });

  final List<NotificationOccurrence> occurrences;
  final List<NotificationOccurrenceEvent> events;

  _OccurrenceDocument copyWith({
    List<NotificationOccurrence>? occurrences,
    List<NotificationOccurrenceEvent>? events,
  }) => _OccurrenceDocument(
    occurrences: occurrences ?? this.occurrences,
    events: events ?? this.events,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': NotificationOccurrenceStore._version,
    'occurrences': occurrences
        .map((row) => row.toStorageJson())
        .toList(growable: false),
    'events': events.map((event) => event.toJson()).toList(growable: false),
  };
}
