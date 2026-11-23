import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/services/push_token_registration_coordinator.dart';

void main() {
  test('initial and refreshed FCM tokens register once per value', () async {
    final updates = StreamController<String>.broadcast(sync: true);
    addTearDown(updates.close);
    final sent = <String>[];
    final registration = PushTokenRegistrationCoordinator((token) async {
      sent.add(token);
    });
    addTearDown(registration.stop);

    registration.start(updates.stream);
    expect(await registration.register(' token-first '), isTrue);
    updates.add('token-first');
    updates.add('token-second');
    updates.add('token-second');
    await registration.idle;

    expect(sent, ['token-first', 'token-second']);
  });

  test('failed registration is retryable with the same token', () async {
    var calls = 0;
    final registration = PushTokenRegistrationCoordinator((token) async {
      calls++;
      if (calls == 1) {
        throw StateError('Simulated HTTP failure');
      }
    });
    addTearDown(registration.stop);
    registration.start(const Stream<String>.empty());

    expect(await registration.register('token-ci'), isFalse);
    expect(await registration.register('token-ci'), isTrue);
    expect(await registration.register('token-ci'), isTrue);
    expect(calls, 2);
  });

  test('empty tokens are not sent to backend', () async {
    var count = 0;
    final registration = PushTokenRegistrationCoordinator((token) async {
      count++;
    });
    addTearDown(registration.stop);
    registration.start(const Stream<String>.empty());

    expect(await registration.register(null), isFalse);
    expect(await registration.register('   '), isFalse);
    expect(count, 0);
  });

  test('logout ignores queued refreshes and stops listener', () async {
    final updates = StreamController<String>.broadcast(sync: true);
    addTearDown(updates.close);
    final held = Completer<void>();
    final sent = <String>[];
    final registration = PushTokenRegistrationCoordinator((token) async {
      sent.add(token);
      if (token == 'token-first') {
        await held.future;
      }
    });
    addTearDown(registration.stop);
    registration.start(updates.stream);

    final pending = registration.register('token-first');
    await Future<void>.delayed(Duration.zero);
    updates.add('token-second');
    registration.stop();
    updates.add('token-third');
    held.complete();

    expect(await pending, isFalse);
    await registration.idle;
    expect(sent, ['token-first']);
    expect(await registration.register('token-fourth'), isFalse);
  });

  test('new login re-registers the same token in a new session', () async {
    final sent = <String>[];
    final registration = PushTokenRegistrationCoordinator((token) async {
      sent.add(token);
    });
    addTearDown(registration.stop);
    registration.start(const Stream<String>.empty());
    expect(await registration.register('shared-device-token'), isTrue);
    registration.stop();

    registration.start(const Stream<String>.empty());
    expect(await registration.register('shared-device-token'), isTrue);
    expect(sent, ['shared-device-token', 'shared-device-token']);
  });

  test('stream errors are observed without exposing token contents', () async {
    final updates = StreamController<String>.broadcast(sync: true);
    addTearDown(updates.close);
    var errors = 0;
    final registration = PushTokenRegistrationCoordinator(
      (token) async {},
      onStreamError: () => errors++,
    );
    addTearDown(registration.stop);
    registration.start(updates.stream);

    updates.addError(StateError('Synthetic stream failure'));
    expect(errors, 1);
    expect(await registration.register('token-valid'), isTrue);
  });
}
