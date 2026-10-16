import 'package:flutter/material.dart';

import '../models/alarm_notification_target.dart';
import '../models/home.dart';
import '../models/session_data.dart';
import '../services/auth_service.dart';
import '../services/vedasentio_push_notification_service.dart';
import 'dashboard_screen.dart';
import 'home_details_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState
    extends State<AuthGate> {
  late final AuthService _auth;
  late final VedaSentioPushNotificationService
      _pushNotificationService;

  SessionData? _session;
  AlarmNotificationTarget?
      _pendingAlarmNotificationTarget;

  bool _loading = true;
  bool _alarmScreenIsOpening = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _auth = AuthService();

    _pushNotificationService =
        VedaSentioPushNotificationService();

    _initializeApplication();
  }

  Future<void> _initializeApplication() async {
    await _pushNotificationService
        .startAlarmNotificationOpenHandling(
      _handleAlarmNotificationOpened,
    );

    await _restore();
  }

  Future<void> _restore() async {
    try {
      SessionData? session =
          await _auth.restore();

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _loading = false;
        _error = null;
      });

      if (session != null) {
        await _registerMobileDeviceForPushNotifications();
        _openPendingAlarmNotificationIfPossible();
      }
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

  void _handleSuccessfulLogin(
    SessionData session,
  ) {
    setState(() {
      _session = session;
      _error = null;
    });

    _registerMobileDeviceForPushNotifications();
    _openPendingAlarmNotificationIfPossible();
  }

  void _handleAlarmNotificationOpened(
    AlarmNotificationTarget notificationTarget,
  ) {
    _pendingAlarmNotificationTarget =
        notificationTarget;

    _openPendingAlarmNotificationIfPossible();
  }

  void _openPendingAlarmNotificationIfPossible() {
    SessionData? currentSession =
        _session;

    AlarmNotificationTarget?
        notificationTarget =
        _pendingAlarmNotificationTarget;

    if (currentSession == null) {
      return;
    }

    if (notificationTarget == null) {
      return;
    }

    if (_loading) {
      return;
    }

    if (_alarmScreenIsOpening) {
      return;
    }

    Home? selectedHome;

    for (Home home in currentSession.homes) {
      if (home.id ==
          notificationTarget.homeId) {
        selectedHome = home;
        break;
      }
    }

    if (selectedHome == null) {
      _pendingAlarmNotificationTarget =
          null;

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Nie masz dostępu do gospodarstwa z tego powiadomienia.',
              ),
            ),
          );
        },
      );

      return;
    }

    int selectedAlarmId =
        notificationTarget.alarmId;

    _pendingAlarmNotificationTarget =
        null;

    _alarmScreenIsOpening = true;

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) async {
        if (!mounted) {
          _alarmScreenIsOpening = false;
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) =>
                HomeDetailsScreen(
              home: selectedHome!,
              authService: _auth,
              onSessionExpired: _logout,
              openedAlarmId:
                  selectedAlarmId,
            ),
          ),
        );

        _alarmScreenIsOpening = false;

        if (mounted) {
          _openPendingAlarmNotificationIfPossible();
        }
      },
    );
  }

  Future<void>
      _registerMobileDeviceForPushNotifications() async {
    await _pushNotificationService
        .registerCurrentMobileDevice(
      _auth,
    );
  }

  Future<void> _logout() async {
    await _auth.logout();

    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
      _pendingAlarmNotificationTarget =
          null;
      _alarmScreenIsOpening = false;
    });
  }

  @override
  void dispose() {
    _pushNotificationService.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_session == null) {
      return LoginScreen(
        auth: _auth,
        startupError: _error,
        onLogin:
            _handleSuccessfulLogin,
      );
    }

    return DashboardScreen(
      session: _session!,
      auth: _auth,
      onLogout: _logout,
    );
  }
}
