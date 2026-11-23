import 'package:flutter/material.dart';

import '../models/alarm_notification_target.dart';
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

    final selectedHome = notificationTarget.findAccessibleHome(
      currentSession.homes,
    );

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
              home: selectedHome,
              authService: _auth,
              onSessionExpired: _handleSessionExpired,
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

  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    _loggingOut = true;

    try {
      var revoked = await _pushNotificationService
          .unregisterCurrentMobileDeviceForLogout(_auth);
      if (!mounted) return;

      // Do not silently claim a shared device is safe when the backend
      // was unreachable. The user must explicitly choose what to do.
      while (!revoked) {
        final choice = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Nie wyłączono powiadomień'),
            content: const Text(
              'Nie udało się potwierdzić wyrejestrowania tego telefonu '
              'z serwera. Po wylogowaniu mogą nadal przychodzić alarmy '
              'poprzedniego konta. Połącz się z Internetem i spróbuj ponownie. '
              'Jeśli wylogujesz się mimo to, skontaktuj się '
              'z administratorem, aby unieważnić token urządzenia.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Anuluj'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'force'),
                child: const Text('Wyloguj mimo to'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'retry'),
                child: const Text('Ponów'),
              ),
            ],
          ),
        );
        if (!mounted) return;

        if (choice == 'cancel' || choice == null) {
          // Keep the login session and resume token refresh handling.
          _registerMobileDeviceForPushNotifications();
          return;
        }
        if (choice == 'force') break;

        revoked = await _pushNotificationService
            .unregisterCurrentMobileDeviceForLogout(_auth);
        if (!mounted) return;
      }

      await _finishLocalLogout(
        warning: revoked
            ? null
            : 'Wylogowano lokalnie, ale serwer nie potwierdził '
                'wyłączenia powiadomień. Zaloguj się ponownie '
                'na poprzednie konto przy działającym Internecie '
                'i poproś administratora o unieważnienie starego tokena.',
      );
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> _handleSessionExpired() async {
    if (_loggingOut) return;
    _pushNotificationService.stopMobileTokenRegistration();
    await _finishLocalLogout(
      warning: 'Sesja wygasła. Nie udało się potwierdzić '
          'wyrejestrowania powiadomień z serwera. '
          'Na współdzielonym telefonie poproś administratora '
          'o unieważnienie tokena poprzedniego konta.',
    );
  }

  Future<void> _finishLocalLogout({String? warning}) async {
    _pushNotificationService.clearRegisteredTokenHistory();
    await _auth.logout();
    if (!mounted) return;

    setState(() {
      _session = null;
      _pendingAlarmNotificationTarget = null;
      _alarmScreenIsOpening = false;
      _error = warning;
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
      onSessionExpired: _handleSessionExpired,
    );
  }
}
