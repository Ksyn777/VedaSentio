import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vedasentio_mobile/services/api_client.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';
import 'package:vedasentio_mobile/services/token_storage.dart';

class MemoryTokenStorage extends TokenStorage {
  MemoryTokenStorage(this.token);
  String? token;
  int clearCount = 0;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
    clearCount++;
  }
}

void main() {
  test('expired token on restore removes the saved session', () async {
    final storage = MemoryTokenStorage('expired');
    final api = ApiClient(client: MockClient((_) async {
      return http.Response('{"error":"expired"}', 401);
    }));
    final auth = AuthService(apiClient: api, tokenStorage: storage);

    expect(await auth.restore(), isNull);
    expect(storage.token, isNull);
    expect(storage.clearCount, 1);
    auth.dispose();
  });

  test('403 remains a permission error and does not remove the session', () async {
    final storage = MemoryTokenStorage('valid');
    final auth = AuthService(
      apiClient: ApiClient(client: MockClient((_) async {
        return http.Response('{"error":"Access denied."}', 403);
      })),
      tokenStorage: storage,
    );

    await expectLater(
      auth.loadHomeEvents('foreign'),
      throwsA(isA<ApiException>().having(
        (e) => e.isForbidden,
        'forbidden',
        isTrue,
      )),
    );
    expect(storage.token, 'valid');
    expect(storage.clearCount, 0);
    auth.dispose();
  });

  test('offline refresh preserves stored session for retry', () async {
    final storage = MemoryTokenStorage('valid');
    final auth = AuthService(
      apiClient: ApiClient(client: MockClient((_) async {
        throw const SocketException('offline');
      })),
      tokenStorage: storage,
    );

    await expectLater(
      auth.loadHomeDetails('home_ci'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'status', isNull),
      ),
    );
    expect(storage.token, 'valid');
    expect(storage.clearCount, 0);
    auth.dispose();
  });

  test('401 during home refresh clears the session', () async {
    final storage = MemoryTokenStorage('expired');
    final auth = AuthService(
      apiClient: ApiClient(client: MockClient((_) async {
        return http.Response('{"error":"Invalid token"}', 401);
      })),
      tokenStorage: storage,
    );

    await expectLater(
      auth.loadHomeDetails('home_ci'),
      throwsA(isA<ApiException>().having(
        (e) => e.isUnauthorized,
        'unauthorized',
        isTrue,
      )),
    );
    expect(storage.token, isNull);
    expect(storage.clearCount, 1);
    auth.dispose();
  });
}
