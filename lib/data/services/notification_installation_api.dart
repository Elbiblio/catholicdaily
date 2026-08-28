import 'dart:convert';

import 'package:http/http.dart' as http;

import 'notification_installation.dart';

enum NotificationInstallationApiResult { success, reRegister, invalid, retry }

class NotificationInstallationApi {
  NotificationInstallationApi({
    http.Client? client,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       endpoint =
           endpoint ??
           Uri.parse(
             'https://api.elbiblio.com/api/mobile/notification-installations',
           );

  final http.Client _client;
  final Uri endpoint;
  final Duration timeout;

  Future<NotificationInstallationApiResult> create(
    NotificationInstallationCredentials credentials,
    NotificationInstallationState state,
  ) => _send(
    'POST',
    endpoint,
    body: <String, dynamic>{...credentials.toCreateJson(), ...state.toJson()},
  );

  Future<NotificationInstallationApiResult> update(
    NotificationInstallationCredentials credentials,
    NotificationInstallationState state,
  ) => _send(
    'PUT',
    endpoint.resolve(
      '${endpoint.pathSegments.last}/${credentials.installationId}',
    ),
    authorization: credentials.authorization,
    body: state.toJson(),
  );

  Future<NotificationInstallationApiResult> disable(
    NotificationInstallationCredentials credentials,
  ) => _send(
    'DELETE',
    endpoint.resolve(
      '${endpoint.pathSegments.last}/${credentials.installationId}',
    ),
    authorization: credentials.authorization,
  );

  Future<NotificationInstallationApiResult> _send(
    String method,
    Uri uri, {
    String? authorization,
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = http.Request(method, uri)
        ..headers['accept'] = 'application/json';
      if (authorization != null) {
        request.headers['authorization'] = authorization;
      }
      if (body != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await _client.send(request).timeout(timeout);
      return _mapStatus(response.statusCode);
    } catch (_) {
      return NotificationInstallationApiResult.retry;
    }
  }

  static NotificationInstallationApiResult _mapStatus(int status) {
    if (status == 200 || status == 201 || status == 204) {
      return NotificationInstallationApiResult.success;
    }
    if (status == 401 || status == 404 || status == 409) {
      return NotificationInstallationApiResult.reRegister;
    }
    if (status == 422 || (status >= 400 && status < 500 && status != 429)) {
      return NotificationInstallationApiResult.invalid;
    }
    return NotificationInstallationApiResult.retry;
  }
}
