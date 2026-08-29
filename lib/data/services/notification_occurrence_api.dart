import 'dart:convert';

import 'package:http/http.dart' as http;

import 'notification_installation.dart';
import 'notification_occurrence.dart';

enum NotificationOccurrenceApiResult { success, reRegister, invalid, retry }

typedef NotificationOccurrenceBatchResultHandler =
    Future<void> Function(
      List<NotificationOccurrence> occurrences,
      List<NotificationOccurrenceEvent> events,
      NotificationOccurrenceApiResult result,
    );

class NotificationOccurrenceApi {
  NotificationOccurrenceApi({
    http.Client? client,
    Uri? installationsEndpoint,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       installationsEndpoint =
           installationsEndpoint ??
           Uri.parse(
             'https://api.elbiblio.com/api/mobile/notification-installations',
           );

  static const maximumBatchSize = 100;

  final http.Client _client;
  final Uri installationsEndpoint;
  final Duration timeout;

  Future<NotificationOccurrenceApiResult> putAll(
    NotificationInstallationCredentials credentials,
    List<NotificationOccurrence> occurrences, {
    List<NotificationOccurrenceEvent> events = const [],
    NotificationOccurrenceBatchResultHandler? onBatchResult,
  }) async {
    if (occurrences.isEmpty && events.isEmpty) {
      return NotificationOccurrenceApiResult.success;
    }
    var occurrenceOffset = 0;
    var eventOffset = 0;
    while (occurrenceOffset < occurrences.length ||
        eventOffset < events.length) {
      final occurrenceEnd = (occurrenceOffset + maximumBatchSize).clamp(
        0,
        occurrences.length,
      );
      final remaining = maximumBatchSize - (occurrenceEnd - occurrenceOffset);
      final eventEnd = (eventOffset + remaining).clamp(0, events.length);
      final result = await _putBatch(
        credentials,
        occurrences.sublist(occurrenceOffset, occurrenceEnd),
        events.sublist(eventOffset, eventEnd),
      );
      await onBatchResult?.call(
        occurrences.sublist(occurrenceOffset, occurrenceEnd),
        events.sublist(eventOffset, eventEnd),
        result,
      );
      if (result != NotificationOccurrenceApiResult.success) return result;
      occurrenceOffset = occurrenceEnd;
      eventOffset = eventEnd;
    }
    return NotificationOccurrenceApiResult.success;
  }

  Future<NotificationOccurrenceApiResult> _putBatch(
    NotificationInstallationCredentials credentials,
    List<NotificationOccurrence> occurrences,
    List<NotificationOccurrenceEvent> events,
  ) async {
    final uri = installationsEndpoint.resolve(
      '${installationsEndpoint.pathSegments.last}/'
      '${credentials.installationId}/occurrences',
    );
    try {
      final response = await _client
          .put(
            uri,
            headers: <String, String>{
              'accept': 'application/json',
              'content-type': 'application/json',
              'authorization': credentials.authorization,
            },
            body: jsonEncode(<String, dynamic>{
              'occurrences': occurrences
                  .map((occurrence) => occurrence.toApiJson())
                  .toList(growable: false),
              'events': events
                  .map((event) => event.toJson())
                  .toList(growable: false),
            }),
          )
          .timeout(timeout);
      return _mapStatus(response.statusCode);
    } catch (_) {
      return NotificationOccurrenceApiResult.retry;
    }
  }

  static NotificationOccurrenceApiResult _mapStatus(int status) {
    if (status == 200 || status == 201 || status == 204) {
      return NotificationOccurrenceApiResult.success;
    }
    if (status == 401 || status == 404) {
      return NotificationOccurrenceApiResult.reRegister;
    }
    if (status == 422 ||
        (status >= 400 && status < 500 && status != 408 && status != 429)) {
      return NotificationOccurrenceApiResult.invalid;
    }
    return NotificationOccurrenceApiResult.retry;
  }
}
