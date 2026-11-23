import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vedasentio_mobile/services/api_client.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';
import 'package:vedasentio_mobile/services/token_storage.dart';
import 'package:vedasentio_mobile/services/vedasentio_push_notification_service.dart';

class _Tokens extends TokenStorage {
  @override
  Future<String?> read() async => 'ci-session-jwt';
}

void main() {
  test('previously registered token is revoked even without this-session POST',
      () async {
    final sent = <String>[];
    final auth = AuthService(
      tokenStorage: _Tokens(),
      apiClient: ApiClient(client: MockClient((req) async {
        sent.add(req.body);
        expect(req.method, 'DELETE');
        expect(req.url.path, '/api/mobile-devices/push-token');
        expect(req.headers['authorization'], 'Bearer ci-session-jwt');
        return http.Response('{"status":"unregistered"}', 200);
      })),
    );
    final push = VedaSentioPushNotificationService(
      currentTokenReader: () async => 'ci-token-from-previous-launch',
    );
    addTearDown(auth.dispose);
    addTearDown(push.dispose);

    expect(await push.unregisterCurrentMobileDeviceForLogout(auth), isTrue);
    expect(sent, ['{"fcm_token":"ci-token-from-previous-launch"}']);
  });

  test('failed retrieval of old token cannot be treated as safe logout',
      () async {
    var writes = 0;
    final auth = AuthService(
      tokenStorage: _Tokens(),
      apiClient: ApiClient(client: MockClient((req) async {
        writes++;
        return http.Response('{"status":"unregistered"}', 200);
      })),
    );
    final push = VedaSentioPushNotificationService(
      currentTokenReader: () async {
        throw const SocketException('offline');
      },
    );
    addTearDown(auth.dispose);
    addTearDown(push.dispose);

    expect(await push.unregisterCurrentMobileDeviceForLogout(auth), isFalse);
    expect(writes, 0);
  });

  test('missing FCM token cannot produce a false confirmation', () async {
    final auth = AuthService(
      tokenStorage: _Tokens(),
      apiClient: ApiClient(client: MockClient((req) async =>
          http.Response('{"status":"unregistered"}', 200))),
    );
    final push = VedaSentioPushNotificationService(
      currentTokenReader: () async => null,
    );
    addTearDown(auth.dispose);
    addTearDown(push.dispose);

    expect(await push.unregisterCurrentMobileDeviceForLogout(auth), isFalse);
  });
}
