import 'dart:async';

/// Serializes FCM token registrations and ignores stale events after logout.
///
/// Firebase and HTTP are injected through a Stream and callback so this logic
/// can be tested without a real Firebase project or a physical phone.
class PushTokenRegistrationCoordinator {
  PushTokenRegistrationCoordinator(
    this._sendToken, {
    this.onStreamError,
  });

  final Future<void> Function(String token) _sendToken;
  final void Function()? onStreamError;

  StreamSubscription<String>? _subscription;
  Future<void> _pending = Future<void>.value();
  String? _lastRegisteredToken;
  bool _active = false;
  int _generation = 0;

  void start(Stream<String> refreshedTokens) {
    stop();
    _active = true;
    _subscription = refreshedTokens.listen(
      (token) {
        unawaited(register(token));
      },
      onError: (Object error, StackTrace trace) {
        onStreamError?.call();
      },
    );
  }

  Future<bool> register(String? rawToken) {
    final token = rawToken?.trim();
    if (token == null || token.isEmpty) {
      return Future<bool>.value(false);
    }

    final generation = _generation;
    final result = _pending.then((_) async {
      if (!_active || generation != _generation) {
        return false;
      }
      if (_lastRegisteredToken == token) {
        return true;
      }

      try {
        await _sendToken(token);
      } catch (_) {
        // A failed HTTP registration is retryable on the next token update.
        return false;
      }

      if (!_active || generation != _generation) {
        return false;
      }
      _lastRegisteredToken = token;
      return true;
    });

    // A failed registration must not block subsequent token rotations.
    _pending = result.then<void>((_) {});
    return result;
  }

  /// Stops listening immediately. No new requests are started after stop().
  void stop() {
    _generation++;
    _active = false;
    _lastRegisteredToken = null;

    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  /// Helpful for waiting for already-queued registrations during tests.
  Future<void> get idle => _pending;
}
