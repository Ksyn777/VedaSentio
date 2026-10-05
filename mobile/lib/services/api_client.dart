import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout =
      Duration(seconds: 10);

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
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

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
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(token),
          body: jsonEncode(
            body ?? <String, dynamic>{},
          ),
        )
        .timeout(_timeout);

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
    final response = await _client
        .get(
          _uri(path),
          headers: _headers(token),
        )
        .timeout(_timeout);

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
    final response = await _client
        .get(
          _uri(path),
          headers: _headers(token),
        )
        .timeout(_timeout);

    final decoded = _decode(response);
    _check(response, decoded);

    if (decoded is! List<dynamic>) {
      throw const ApiException(
        'Nieoczekiwany format odpowiedzi.',
      );
    }

    return decoded;
  }

  void close() => _client.close();
}
