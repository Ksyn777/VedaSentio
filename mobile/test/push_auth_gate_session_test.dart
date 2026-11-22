import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm_notification_target.dart';
import 'package:vedasentio_mobile/models/session_data.dart';
import 'package:vedasentio_mobile/models/user_profile.dart';
import 'package:vedasentio_mobile/screens/auth_gate.dart';
import 'package:vedasentio_mobile/screens/dashboard_screen.dart';
import 'package:vedasentio_mobile/screens/login_screen.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';
import 'package:vedasentio_mobile/services/vedasentio_push_notification_service.dart';

const session = SessionData(
  user: UserProfile(
    id: 12,
    email: 'ci@example.invalid',
    firstName: 'CI',
    lastName: 'User',
    phone: '',
    isActive: true,
    createdAt: '2026-11-22T10:00:00Z',
    homes: [],
  ),
  homes: [],
);

class FakeAuth extends AuthService {
  int logoutCalls = 0;

  @override
  Future<SessionData?> restore() async => session;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class FakePush extends VedaSentioPushNotificationService {
  FakePush(this.code);
  final int code;

  @override
  Future<void> startAlarmNotificationOpenHandling(
    void Function(AlarmNotificationTarget) callback,
  ) async {}

  @override
  Future<bool> registerCurrentMobileDevice(AuthService authService) async {
    throw ApiException('Synthetic push registration failure.', statusCode: code);
  }
}

void main() {
  testWidgets('push registration 401 logs out an already restored session',
      (tester) async {
    final auth = FakeAuth();
    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authService: auth,
        pushNotificationService: FakePush(401),
      ),
    ));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('push registration 403 keeps the dashboard session',
      (tester) async {
    final auth = FakeAuth();
    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authService: auth,
        pushNotificationService: FakePush(403),
      ),
    ));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 0);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
