import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/models/home.dart';
import 'package:vedasentio_mobile/models/home_details_data.dart';
import 'package:vedasentio_mobile/screens/home_details_screen.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';

class QueuedAuthService extends AuthService {
  QueuedAuthService(this.responses, {this.acknowledgeFailure});

  final List<Future<HomeDetailsData> Function()> responses;
  final ApiException? acknowledgeFailure;
  int loadCount = 0;
  int acknowledgeCount = 0;

  @override
  Future<HomeDetailsData> loadHomeDetails(
    String homeId, {
    int eventLimit = 20,
    int alarmHistoryLimit = 20,
  }) {
    loadCount++;
    return responses.removeAt(0)();
  }

  @override
  Future<Alarm> acknowledgeAlarm({
    required String homeId,
    required int alarmId,
  }) async {
    acknowledgeCount++;
    if (acknowledgeFailure != null) {
      throw acknowledgeFailure!;
    }
    throw StateError('Unexpected successful acknowledgement in fake');
  }
}

const home = Home(
  id: 'home_ci',
  name: 'Dom testowy',
  role: 'owner',
  createdAt: '2026-11-22T00:00:00Z',
);

const emptyData = HomeDetailsData(
  devices: [],
  recentEvents: [],
  latestEventsByDevice: {},
  activeAlarms: [],
  alarmHistory: [],
);

const activeAlarm = Alarm(
  id: 7,
  homeId: 'home_ci',
  deviceId: 'sos_ci',
  alarmType: 'sos',
  severity: 'critical',
  status: 'active',
  startedAt: '2026-11-22T10:00:00Z',
  createdAt: '2026-11-22T10:00:00Z',
  updatedAt: '2026-11-22T10:00:00Z',
);

const activeData = HomeDetailsData(
  devices: [],
  recentEvents: [],
  latestEventsByDevice: {},
  activeAlarms: [activeAlarm],
  alarmHistory: [activeAlarm],
);

Future<void> pumpHome(
  WidgetTester tester,
  QueuedAuthService auth, {
  Future<void> Function()? onSessionExpired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeDetailsScreen(
        home: home,
        authService: auth,
        onSessionExpired: onSessionExpired ?? () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('failed initial request shows a retry button and recovers',
      (tester) async {
    final auth = QueuedAuthService([
      () async => throw const ApiException('Brak połączenia z serwerem.'),
      () async => emptyData,
    ]);

    await pumpHome(tester, auth);
    expect(find.text('Brak połączenia z serwerem.'), findsOneWidget);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);

    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pumpAndSettle();

    expect(find.text('Monitoring na żywo'), findsOneWidget);
    expect(find.text('Spróbuj ponownie'), findsNothing);
    expect(auth.loadCount, 2);
  });

  testWidgets('failed refresh keeps prior data but marks it stale',
      (tester) async {
    final auth = QueuedAuthService([
      () async => emptyData,
      () async => throw const ApiException('Połączenie przerwane.'),
      () async => emptyData,
    ]);

    await pumpHome(tester, auth);
    expect(find.text('Monitoring na żywo'), findsOneWidget);
    expect(find.text('Dom testowy'), findsWidgets);

    await tester.tap(find.byTooltip('Odśwież teraz'));
    await tester.pumpAndSettle();

    expect(find.text('Dane nieaktualne'), findsOneWidget);
    expect(find.text('Monitoring na żywo'), findsNothing);
    expect(find.text('Dom testowy'), findsWidgets);

    await tester.tap(find.byTooltip('Odśwież teraz'));
    await tester.pumpAndSettle();
    expect(find.text('Monitoring na żywo'), findsOneWidget);
    expect(find.text('Dane nieaktualne'), findsNothing);
  });

  testWidgets('403 stays a visible access denial without logging out',
      (tester) async {
    var logoutCount = 0;
    final auth = QueuedAuthService([
      () async => throw const ApiException(
            'Access denied.',
            statusCode: 403,
          ),
    ]);

    await pumpHome(
      tester,
      auth,
      onSessionExpired: () async { logoutCount++; },
    );

    expect(find.text('Nie masz dostępu do tego gospodarstwa.'), findsOneWidget);
    expect(logoutCount, 0);
  });

  testWidgets('401 triggers session-expired callback',
      (tester) async {
    var logoutCount = 0;
    final auth = QueuedAuthService([
      () async => throw const ApiException(
            'Session expired.',
            statusCode: 401,
          ),
    ]);

    await pumpHome(
      tester,
      auth,
      onSessionExpired: () async { logoutCount++; },
    );

    expect(logoutCount, 1);
  });

  testWidgets('network error on acknowledgement shows a message, not crash',
      (tester) async {
    final auth = QueuedAuthService(
      [() async => activeData],
      acknowledgeFailure: const ApiException('Przekroczono czas połączenia.'),
    );

    await pumpHome(tester, auth);
    final button = find.text('Potwierdź alarm');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();

    expect(auth.acknowledgeCount, 1);
    expect(find.text('Przekroczono czas połączenia.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
