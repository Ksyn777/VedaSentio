/// Remembers every token that may have reached the backend in this session.
///
/// Even when a POST times out, the server may have committed it. The device
/// must therefore attempt to revoke *attempted* registrations at logout.
class PushTokenRevocationRegistry {
  final Set<String> _pending = <String>{};

  void noteAttempt(String token) {
    if (token.trim().isNotEmpty) {
      _pending.add(token);
    }
  }

  Future<bool> revokeAll(
    Future<void> Function(String token) revoke,
  ) async {
    var allRevoked = true;
    for (final token in _pending.toList()) {
      try {
        await revoke(token);
        _pending.remove(token);
      } catch (_) {
        // Keep unsuccessful tokens for an explicit retry before logout.
        allRevoked = false;
      }
    }
    return allRevoked;
  }

  void clear() => _pending.clear();
}
