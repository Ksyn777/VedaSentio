import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  })  : _client = client ?? http.Client(),
        _timeout = timeout;

  final http.Client _client;
  final Duration _timeout;

  // HTTP 401/403 responses stay intact; only transport failures are mapped.
  Future<http.Response> _request(
    Future<http.Response> Function() send,
  ) async {
    try {
      return await send().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'Przekroczono czas połączenia. Spróbuj ponownie.',
      );
    } on SocketException {
      throw const ApiException(
        'Brak połączenia z serwerem. Sprawdź sieć i spróbuj ponownie.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Nie udało się połączyć z serwerem. Spróbuj ponownie.',
      );
    }
  }

  Uri _uri(String path) =>
      Uri.parse(
        '${AppConfig.apiBaseUrl}$path',
      );

  Map<String, String> _headers([
    String? token,
  ]) =>
      {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null &&
            token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  dynamic _decode(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'Nieprawidłowa odpowiedź serwera.',
        statusCode: response.statusCode,
      );
    }
  }

  void _check(
    http.Response response,
    dynamic body,
  ) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }

    var message =
        'Błąd komunikacji z serwerem.';

    if (body is Map<String, dynamic> &&
        body['error'] is String) {
      message = body['error'] as String;
    }

    throw ApiException(
      message,
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _request(
      () => _client.post(
        _uri(path),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );

    final decoded = _decode(response);
    _check(response, decoded);

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        'Nieoczekiwany format odpowiedzi.',
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>>
      postAuthorized(
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _request(
      () => _client.post(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );

    final decoded = _decode(response);
    _check(response, decoded);

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        'Nieoczekiwany format odpowiedzi.',
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getObject(
    String path,
    String token,
  ) async {
    final response = await _request(
      () => _client.get(
        _uri(path),
        headers: _headers(token),
      ),
    );

    final decoded = _decode(response);
    _check(response, decoded);

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        'Nieoczekiwany format odpowiedzi.',
      );
    }

    return decoded;
  }

  Future<List<dynamic>> getList(
    String path,
    String token,
  ) async {
    final response = await _request(
      () => _client.get(
        _uri(path),
        headers: _headers(token),
      ),
    );

    final decoded = _decode(response);
    _check(response, decoded);

    if (decoded is! List<dynamic>) {
      throw const ApiException(
        'Nieoczekiwany format odpowiedzi.',
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> deleteAuthorized(
    String path,
    String token, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _request(
      () => _client.delete(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );

    final decoded = _decode(response);
    _check(response, decoded);

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Nieoczekiwany format odpowiedzi.');
    }
    return decoded;
  }

  void close() => _client.close();
}
