import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vedasentio_mobile/services/api_client.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';
import 'package:vedasentio_mobile/services/push_token_registration.dart';
import 'package:vedasentio_mobile/services/token_storage.dart';

class MemoryTokens extends TokenStorage {
  MemoryTokens(this.value);
  String? value;
  int clearCount = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String token) async {
    value = token;
  }

  @override
  Future<void> clear() async {
    value = null;
    clearCount++;
  }
}

void main() {
  test('Android FCM registration sends a protected real HTTP API request',
      () async {
    final calls = <http.Request>[];
    final storage = MemoryTokens('ci-jwt');
    final api = ApiClient(client: MockClient((request) async {
      calls.add(request);
      return http.Response('{"status":"registered"}', 200);
    }));
    final auth = AuthService(apiClient: api, tokenStorage: storage);
    addTearDown(auth.dispose);

    final result = await PushTokenRegistration.register(
      auth: auth,
      fcmToken: ' ci-synthetic-fcm ',
      platform: 'android',
    );
    expect(result, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'POST');
    expect(calls.single.url.path, '/api/mobile-devices/push-token');
    expect(calls.single.headers['authorization'], 'Bearer ci-jwt');
    expect(jsonDecode(calls.single.body), {
      'fcm_token': 'ci-synthetic-fcm',
      'platform': 'android',
    });
    expect(storage.value, 'ci-jwt');
    expect(storage.clearCount, 0);
  });

  test('iOS token registration sends ios platform', () async {
    final calls = <http.Request>[];
    final auth = AuthService(
      apiClient: ApiClient(client: MockClient((request) async {
        calls.add(request);
        return http.Response('{"status":"registered"}', 200);
      })),
      tokenStorage: MemoryTokens('jwt-ios'),
    );
    addTearDown(auth.dispose);

    expect(await PushTokenRegistration.register(
      auth: auth,
      fcmToken: 'ios-ci-token',
      platform: 'ios',
    ), isTrue);
    expect(jsonDecode(calls.single.body)['platform'], 'ios');
  });

  test('no token or unsupported platform never contacts the API', () async {
    var calls = 0;
    final auth = AuthService(
      apiClient: ApiClient(client: MockClient((_) async {
        calls++;
        return http.Response('{"status":"registered"}', 200);
      })),
      tokenStorage: MemoryTokens('jwt'),
    );
    addTearDown(auth.dispose);

    for (final token in [null, '', '    ']) {
      expect(await PushTokenRegistration.register(
        auth: auth,
        fcmToken: token,
        platform: 'android',
      ), isFalse);
    }
    expect(await PushTokenRegistration.register(
      auth: auth,
      fcmToken: 'synthetic',
      platform: 'windows',
    ), isFalse);
    expect(calls, 0);
  });

  test('401 during token registration clears expired stored session', () async {
    final storage = MemoryTokens('expired-jwt');
    final auth = AuthService(
      apiClient: ApiClient(client: MockClient((_) async {
        return http.Response('{"error":"expired"}', 401);
      })),
      tokenStorage: storage,
    );
    addTearDown(auth.dispose);

    await expectLater(
      PushTokenRegistration.register(
        auth: auth,
        fcmToken: 'synthetic',
        platform: 'android',
      ),
      throwsA(isA<ApiException>().having(
        (error) => error.isUnauthorized, '401', isTrue,
      )),
    );
    expect(storage.value, isNull);
    expect(storage.clearCount, 1);
  });

  test('403 retains session; token registration must not claim success',
      () async {
    final storage = MemoryTokens('valid-jwt');
    final auth = AuthService(
      apiClient: ApiClient(client: MockClient((_) async {
        return http.Response('{"error":"Forbidden"}', 403);
      })),
      tokenStorage: storage,
    );
    addTearDown(auth.dispose);

    await expectLater(
      PushTokenRegistration.register(
        auth: auth,
        fcmToken: 'synthetic',
        platform: 'android',
      ),
      throwsA(isA<ApiException>().having(
        (error) => error.isForbidden, '403', isTrue,
      )),
    );
    expect(storage.value, 'valid-jwt');
    expect(storage.clearCount, 0);
  });

  test('offline registration does not erase a valid session', () async {
    final storage = MemoryTokens('valid-jwt');
    final auth = AuthService(
      apiClient: ApiClient(client: MockClient((_) async {
        throw const SocketException('offline');
      })),
      tokenStorage: storage,
    );
    addTearDown(auth.dispose);

    await expectLater(
      PushTokenRegistration.register(
        auth: auth,
        fcmToken: 'synthetic',
        platform: 'android',
      ),
      throwsA(isA<ApiException>().having(
        (error) => error.statusCode, 'statusCode', isNull,
      )),
    );
    expect(storage.value, 'valid-jwt');
    expect(storage.clearCount, 0);
  });
}
