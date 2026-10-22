import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'session_store.dart';

typedef Json = Map<String, dynamic>;

/// Something the server refused, or a request that never reached it.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.status,
    this.code,
    this.unreachable = false,
  });

  /// Ready to show to the user.
  final String message;

  /// The HTTP status, when the server answered.
  final int? status;

  /// The server's name for the refusal, when it gave one:
  /// "account_read_only" while the owner's Kodi bill is unpaid.
  final String? code;

  bool get accountReadOnly => code == 'account_read_only';

  /// True when there was no answer at all: no connection, or the server is down.
  final bool unreachable;

  @override
  String toString() => message;
}

/// Every request to the server goes through here.
///
/// It adds the signed-in session, renews it when it has run out, and turns
/// every failure into an [ApiException] with a message for the user. Screens
/// never use the network directly, so saving without a connection can later
/// be added in this one layer.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.session,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  static const _timeout = Duration(seconds: 25);
  static final _random = Random.secure();

  final String baseUrl;
  final SessionStore session;
  final http.Client _http;

  /// Called when the session can no longer be renewed, so the app can
  /// return to the sign-in screen.
  void Function()? onSessionExpired;

  /// One renewal shared by every request that found the session run out at
  /// the same moment: the server accepts each renewal token only once.
  Future<bool>? _renewing;

  /// A new key for one thing being saved. Sent again with the same key, the
  /// server answers with the first result and saves nothing twice.
  static String newSaveKey() {
    const hex = '0123456789abcdef';

    return List.generate(32, (_) => hex[_random.nextInt(16)]).join();
  }

  Future<Json> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request('GET', path, query: query, auth: auth);
  }

  Future<Json> post(
    String path, {
    Object? body,
    bool auth = true,
    String? saveKey,
  }) {
    return _request(
      'POST',
      path,
      body: body ?? const {},
      auth: auth,
      saveKey: saveKey,
    );
  }

  Future<Json> put(String path, {Object? body, String? saveKey}) {
    return _request('PUT', path, body: body ?? const {}, saveKey: saveKey);
  }

  Future<Json> delete(String path, {Object? body}) {
    return _request('DELETE', path, body: body ?? const {});
  }

  Future<Json> patch(String path, {Object? body, String? saveKey}) {
    return _request('PATCH', path, body: body ?? const {}, saveKey: saveKey);
  }

  /// Called when the server refuses a change because the account is
  /// read-only, so the banner can show at once.
  void Function()? onReadOnly;

  /// A file from the server (a statement PDF). -> its bytes.
  Future<List<int>> download(String path, {Map<String, String>? query}) async {
    final response = await _exchange(
      'GET',
      path,
      query: query,
      auth: true,
      accept: '*/*',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail(response);
    }

    return response.bodyBytes;
  }

  /// Sends a file as the request body (a photo or a PDF), with what it
  /// belongs to in the address.
  Future<Json> upload(
    String path, {
    required Map<String, String> query,
    required List<int> bytes,
    required String contentType,
    String? saveKey,
  }) {
    return _request(
      'POST',
      path,
      query: query,
      bytes: bytes,
      contentType: contentType,
      saveKey: saveKey,
    );
  }

  Future<Json> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
    String? saveKey,
    List<int>? bytes,
    String? contentType,
  }) async {
    final response = await _exchange(
      method,
      path,
      body: body,
      query: query,
      auth: auth,
      saveKey: saveKey,
      bytes: bytes,
      contentType: contentType,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail(response);
    }

    return _decode(response) ?? const {};
  }

  /// Turns a refusal into an [ApiException] with the server's words.
  Never _fail(http.Response response) {
    final payload = _decode(response);
    final code = payload?['code'];
    final failure = ApiException(
      _errorMessage(payload, response.statusCode),
      status: response.statusCode,
      code: code is String ? code : null,
    );

    if (failure.accountReadOnly) onReadOnly?.call();

    throw failure;
  }

  /// Sends a request with the session, renewing the session once if it
  /// has run out.
  Future<http.Response> _exchange(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
    String? saveKey,
    List<int>? bytes,
    String? contentType,
    String accept = 'application/json',
  }) async {
    var response = await _send(
      method,
      path,
      body: body,
      query: query,
      auth: auth,
      saveKey: saveKey,
      bytes: bytes,
      contentType: contentType,
      accept: accept,
    );

    if (response.statusCode == 401 && auth) {
      if (!await _renewSession()) {
        await session.clear();
        onSessionExpired?.call();

        throw const ApiException(
          'You have been signed out. Sign in again.',
          status: 401,
        );
      }

      response = await _send(
        method,
        path,
        body: body,
        query: query,
        auth: auth,
        saveKey: saveKey,
        bytes: bytes,
        contentType: contentType,
        accept: accept,
      );
    }

    return response;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    required bool auth,
    String? saveKey,
    List<int>? bytes,
    String? contentType,
    String accept = 'application/json',
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);

    final request = http.Request(method, uri);

    request.headers['Accept'] = accept;

    if (bytes != null) {
      request.headers['Content-Type'] =
          contentType ?? 'application/octet-stream';
      request.bodyBytes = bytes;
    } else if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    if (auth && session.accessToken != null) {
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    if (saveKey != null) {
      request.headers['Idempotency-Key'] = saveKey;
    }

    try {
      return await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to answer. Check your connection and try again.',
        unreachable: true,
      );
    } catch (_) {
      throw const ApiException(
        'Cannot reach the server. Check your connection and try again.',
        unreachable: true,
      );
    }
  }

  Future<bool> _renewSession() {
    return _renewing ??= _renew().whenComplete(() => _renewing = null);
  }

  Future<bool> _renew() async {
    final refresh = session.refreshToken;

    if (refresh == null) return false;

    final response = await _send(
      'POST',
      '/api/auth/refresh-token',
      body: {'refresh_token': refresh},
      auth: false,
    );

    if (response.statusCode != 200) return false;

    final payload = _decode(response);
    final access = payload?['access_token'];
    final renewed = payload?['refresh_token'];

    if (access is! String || renewed is! String) return false;

    await session.save(access: access, refresh: renewed);

    return true;
  }

  Json? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// The server's own words, with the fields it named: "Tenant data is
  /// invalid. Phone: Enter a valid phone number."
  String _errorMessage(Json? payload, int status) {
    final parts = <String>[];
    final error = payload?['error'];

    parts.add(
      error is String && error.isNotEmpty
          ? error
          : 'The request failed ($status).',
    );

    final details = payload?['details'];

    if (details is List) {
      for (final detail in details) {
        if (detail is Map && detail['message'] is String) {
          parts.add(detail['message'] as String);
        }
      }
    }

    return parts.join(' ');
  }
}
