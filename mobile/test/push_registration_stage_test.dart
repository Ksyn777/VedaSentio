import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vedasentio_mobile/services/api_client.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';
import 'package:vedasentio_mobile/services/token_storage.dart';

class _MemoryTokens extends TokenStorage {
  String? value = 'synthetic-ci-jwt';
  var clearCount = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> clear() async {
    value = null;
    clearCount++;
  }
}

void main() {
  test('token registration sends bearer auth and platform to API', () async {
    final tokens = _MemoryTokens();
    var writes = 0;
    final auth = AuthService(
      apiClient: ApiClient(
        client: MockClient((request) async {
          writes++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile-devices/push-token');
          expect(request.headers['authorization'], 'Bearer synthetic-ci-jwt');
          expect(request.body, contains('"platform":"android"'));
          expect(request.body, contains('"fcm_token":"ci-not-real-fcm"'));
          return http.Response('{"status":"registered"}', 200);
        }),
      ),
      tokenStorage: tokens,
    );
    addTearDown(auth.dispose);

    await auth.registerMobilePushNotificationToken('ci-not-real-fcm', 'android');
    expect(writes, 1);
    expect(tokens.value, 'synthetic-ci-jwt');
  });

  test('401 during token registration clears expired session', () async {
    final tokens = _MemoryTokens();
    final auth = AuthService(
      apiClient: ApiClient(
        client: MockClient((request) async =>
            http.Response('{"error":"Unauthorized"}', 401)),
      ),
      tokenStorage: tokens,
    );
    addTearDown(auth.dispose);

    await expectLater(
      auth.registerMobilePushNotificationToken('ci-token', 'ios'),
      throwsA(
        isA<ApiException>().having((e) => e.isUnauthorized, '401', isTrue),
      ),
    );
    expect(tokens.value, isNull);
    expect(tokens.clearCount, 1);
  });

  test('403 does not clear the login token', () async {
    final tokens = _MemoryTokens();
    final auth = AuthService(
      apiClient: ApiClient(
        client: MockClient((request) async =>
            http.Response('{"error":"Access denied"}', 403)),
      ),
      tokenStorage: tokens,
    );
    addTearDown(auth.dispose);

    await expectLater(
      auth.registerMobilePushNotificationToken('ci-token', 'android'),
      throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', isTrue)),
    );
    expect(tokens.value, 'synthetic-ci-jwt');
    expect(tokens.clearCount, 0);
  });

  test('network errors do not clear the login token', () async {
    final tokens = _MemoryTokens();
    final auth = AuthService(
      apiClient: ApiClient(
        client: MockClient((request) async {
          throw const SocketException('No test server');
        }),
      ),
      tokenStorage: tokens,
    );
    addTearDown(auth.dispose);

    await expectLater(
      auth.registerMobilePushNotificationToken('ci-token', 'android'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'no HTTP status', isNull),
      ),
    );
    expect(tokens.value, 'synthetic-ci-jwt');
    expect(tokens.clearCount, 0);
  });
}
