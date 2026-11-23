import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vedasentio_mobile/services/api_client.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';
import 'package:vedasentio_mobile/services/push_token_revocation_registry.dart';
import 'package:vedasentio_mobile/services/token_storage.dart';

class _MemoryTokens extends TokenStorage {
  String? value = 'ci-jwt';
  var cleared = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> clear() async {
    value = null;
    cleared++;
  }
}

void main() {
  test('authenticated DELETE contains own FCM token and correct JWT', () async {
    final storage = _MemoryTokens();
    var requests = 0;
    final auth = AuthService(
      tokenStorage: storage,
      apiClient: ApiClient(
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/mobile-devices/push-token');
          expect(request.headers['authorization'], 'Bearer ci-jwt');
          expect(request.body, '{"fcm_token":"ci-device-token"}');
          return http.Response('{"status":"unregistered"}', 200);
        }),
      ),
    );
    addTearDown(auth.dispose);

    await auth.unregisterMobilePushNotificationToken('ci-device-token');
    await auth.unregisterMobilePushNotificationToken('ci-device-token');
    expect(requests, 2); // Server endpoint is idempotent.
    expect(storage.value, 'ci-jwt');
    expect(storage.cleared, 0);
  });

  test('missing server confirmation cannot be mistaken for revocation', () async {
    final storage = _MemoryTokens();
    final auth = AuthService(
      tokenStorage: storage,
      apiClient: ApiClient(
        client: MockClient(
          (_) async => http.Response('{"status":"registered"}', 200),
        ),
      ),
    );
    addTearDown(auth.dispose);

    await expectLater(
      auth.unregisterMobilePushNotificationToken('ci-token'),
      throwsA(isA<ApiException>().having(
        (e) => e.message, 'message', contains('nie potwierdził'),
      )),
    );
    expect(storage.value, 'ci-jwt');
  });

  test('401 clears expired JWT when revocation is rejected', () async {
    final storage = _MemoryTokens();
    final auth = AuthService(
      tokenStorage: storage,
      apiClient: ApiClient(
        client: MockClient(
          (_) async => http.Response('{"error":"Unauthorized"}', 401),
        ),
      ),
    );
    addTearDown(auth.dispose);

    await expectLater(
      auth.unregisterMobilePushNotificationToken('ci-token'),
      throwsA(isA<ApiException>().having(
        (e) => e.isUnauthorized, 'unauthorized', isTrue,
      )),
    );
    expect(storage.value, isNull);
    expect(storage.cleared, 1);
  });

  test('403 does not clear JWT and is not silent success', () async {
    final storage = _MemoryTokens();
    final auth = AuthService(
      tokenStorage: storage,
      apiClient: ApiClient(
        client: MockClient(
          (_) async => http.Response('{"error":"Denied"}', 403),
        ),
      ),
    );
    addTearDown(auth.dispose);

    await expectLater(
      auth.unregisterMobilePushNotificationToken('ci-token'),
      throwsA(isA<ApiException>().having(
        (e) => e.isForbidden, 'forbidden', isTrue,
      )),
    );
    expect(storage.value, 'ci-jwt');
    expect(storage.cleared, 0);
  });

  test('offline DELETE does not clear JWT or claim server revocation', () async {
    final storage = _MemoryTokens();
    final auth = AuthService(
      tokenStorage: storage,
      apiClient: ApiClient(
        client: MockClient(
          (_) async => throw const SocketException('offline CI'),
        ),
      ),
    );
    addTearDown(auth.dispose);

    await expectLater(
      auth.unregisterMobilePushNotificationToken('ci-token'),
      throwsA(isA<ApiException>().having(
        (e) => e.statusCode, 'no HTTP status', isNull,
      )),
    );
    expect(storage.value, 'ci-jwt');
    expect(storage.cleared, 0);
  });

  test('timeout DELETE preserves JWT and cannot confirm revocation', () async {
    final storage = _MemoryTokens();
    final pendingResponse = Completer<http.Response>();
    final auth = AuthService(
      tokenStorage: storage,
      apiClient: ApiClient(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) => pendingResponse.future),
      ),
    );
    addTearDown(auth.dispose);

    await expectLater(
      auth.unregisterMobilePushNotificationToken('ci-token'),
      throwsA(isA<ApiException>().having(
        (error) => error.statusCode, 'no HTTP response', isNull,
      )),
    );
    expect(storage.value, 'ci-jwt');
    expect(storage.cleared, 0);
  });

  test('registry revokes every attempted token after rotation', () async {
    final registry = PushTokenRevocationRegistry();
    registry.noteAttempt('token-old');
    registry.noteAttempt('token-new');
    registry.noteAttempt('token-new');

    final revoked = <String>[];
    expect(await registry.revokeAll((token) async {
      revoked.add(token);
    }), isTrue);
    expect(revoked, ['token-old', 'token-new']);
    expect(await registry.revokeAll((_) async {
      fail('Already revoked tokens must not be sent twice');
    }), isTrue);
  });

  test('timed-out registration is still revoked after backend recovery',
      () async {
    final registry = PushTokenRevocationRegistry();
    // A prior POST may have committed despite no HTTP response.
    registry.noteAttempt('uncertain-fcm-token');
    var tries = 0;
    expect(await registry.revokeAll((token) async {
      tries++;
      throw const SocketException('offline');
    }), isFalse);
    expect(tries, 1);

    expect(await registry.revokeAll((token) async {
      expect(token, 'uncertain-fcm-token');
      tries++;
    }), isTrue);
    expect(tries, 2);
  });

  test('logout failure on one token retains only failed token for retry',
      () async {
    final registry = PushTokenRevocationRegistry();
    registry.noteAttempt('old');
    registry.noteAttempt('new');

    expect(await registry.revokeAll((token) async {
      if (token == 'new') throw const SocketException('offline');
    }), isFalse);

    final retry = <String>[];
    expect(await registry.revokeAll((token) async {
      retry.add(token);
    }), isTrue);
    expect(retry, ['new']);
  });

  test('forced local logout clears pending tokens before next account',
      () async {
    final registry = PushTokenRevocationRegistry();
    registry.noteAttempt('old-account-token');
    registry.clear();

    var calls = 0;
    expect(await registry.revokeAll((token) async {
      calls++;
    }), isTrue);
    expect(calls, 0);
  });
}
