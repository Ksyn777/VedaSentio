import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vedasentio_mobile/services/api_client.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';

void main() {
  test('offline failures become an ApiException for every HTTP method', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        throw const SocketException('offline');
      }),
    );

    final requests = <Future<dynamic> Function()>[
      () => api.post('/api/auth/login', {'email': 'ci@example.invalid'}),
      () => api.postAuthorized('/api/mobile-devices/push-token', 'token'),
      () => api.getObject('/api/me', 'token'),
      () => api.getList('/api/homes', 'token'),
    ];

    for (final request in requests) {
      await expectLater(
        request(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having((e) => e.message, 'message', contains('Brak połączenia')),
        ),
      );
    }
    api.close();
  });

  test('timeout produces a retryable error without an HTTP status', () async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      api.getList('/api/homes', 'token'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', contains('Przekroczono czas'))
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
    api.close();
  });

  test('HTTP client failures do not become false successful responses', () async {
    final api = ApiClient(
      client: MockClient((_) async {
        throw http.ClientException('cannot reach server');
      }),
    );

    await expectLater(
      api.getObject('/api/me', 'token'),
      throwsA(isA<ApiException>().having(
        (e) => e.message,
        'message',
        contains('Nie udało się połączyć'),
      )),
    );
    api.close();
  });

  test('401 and 403 preserve their status for session and permission logic', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/me') {
          return http.Response('{"error":"Session expired."}', 401);
        }
        return http.Response('{"error":"Access denied."}', 403);
      }),
    );

    await expectLater(
      api.getObject('/api/me', 'expired'),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', isTrue)),
    );
    await expectLater(
      api.getList('/api/homes/foreign/events', 'valid'),
      throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', isTrue)),
    );
    api.close();
  });

  test('retry after network restoration works with the same client', () async {
    var attempts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          throw const SocketException('offline');
        }
        expect(request.headers['authorization'], 'Bearer valid-token');
        return http.Response('[{"id":"home_ci"}]', 200);
      }),
    );

    await expectLater(
      api.getList('/api/homes', 'valid-token'),
      throwsA(isA<ApiException>()),
    );
    final homes = await api.getList('/api/homes', 'valid-token');
    expect(homes.single['id'], 'home_ci');
    expect(attempts, 2);
    api.close();
  });
}
