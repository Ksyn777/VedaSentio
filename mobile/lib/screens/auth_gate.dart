import 'package:flutter/material.dart';

import '../models/session_data.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _auth;

  SessionData? _session;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final session = await _auth.restore();

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Nie udało się połączyć z backendem.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.logout();

    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
    });
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_session == null) {
      return LoginScreen(
        auth: _auth,
        startupError: _error,
        onLogin: (session) {
          setState(() {
            _session = session;
            _error = null;
          });
        },
      );
    }

    return DashboardScreen(
      session: _session!,
      auth: _auth,
      onLogout: _logout,
    );
  }
}
