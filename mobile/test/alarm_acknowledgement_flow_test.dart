import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/models/home.dart';
import 'package:vedasentio_mobile/models/home_details_data.dart';
import 'package:vedasentio_mobile/screens/home_details_screen.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';

const _active = Alarm(
  id: 27,
  homeId: 'home_ci',
  deviceId: 'sos_ci',
  alarmType: 'sos',
  severity: 'critical',
  status: 'active',
  startedAt: '2026-11-22T10:00:00Z',
  createdAt: '2026-11-22T10:00:00Z',
  updatedAt: '2026-11-22T10:00:00Z',
);

const _acknowledged = Alarm(
  id: 27,
  homeId: 'home_ci',
  deviceId: 'sos_ci',
  alarmType: 'sos',
  severity: 'critical',
  status: 'acknowledged',
  startedAt: '2026-11-22T10:00:00Z',
  acknowledgedAt: '2026-11-22T10:01:00Z',
  acknowledgedBy: 12,
  createdAt: '2026-11-22T10:00:00Z',
  updatedAt: '2026-11-22T10:01:00Z',
);

const _resolved = Alarm(
  id: 27,
  homeId: 'home_ci',
  deviceId: 'sos_ci',
  alarmType: 'sos',
  severity: 'critical',
  status: 'resolved',
  startedAt: '2026-11-22T10:00:00Z',
  resolvedAt: '2026-11-22T10:02:00Z',
  resolutionSource: 'sensor_event',
  createdAt: '2026-11-22T10:00:00Z',
  updatedAt: '2026-11-22T10:02:00Z',
);

HomeDetailsData _data({
  List<Alarm> active = const [],
  List<Alarm> history = const [],
}) {
  return HomeDetailsData(
    devices: const [],
    recentEvents: const [],
    latestEventsByDevice: const {},
    activeAlarms: active,
    alarmHistory: history,
  );
}

Home _home(String role) => Home(
      id: 'home_ci',
      name: 'Dom testowy',
      role: role,
      createdAt: '2026-11-22T00:00:00Z',
    );

class _FakeAuthService extends AuthService {
  _FakeAuthService(
    this.responses, {
    this.acknowledge,
  });

  final List<Future<HomeDetailsData> Function()> responses;
  final Future<Alarm> Function()? acknowledge;

  int reads = 0;
  int writes = 0;
  String? lastHomeId;
  int? lastAlarmId;

  @override
  Future<HomeDetailsData> loadHomeDetails(
    String homeId, {
    int eventLimit = 20,
    int alarmHistoryLimit = 20,
  }) {
    reads++;
    lastHomeId = homeId;
    if (responses.isEmpty) {
      throw StateError('Unexpected additional home read');
    }
    return responses.removeAt(0)();
  }

  @override
  Future<Alarm> acknowledgeAlarm({
    required String homeId,
    required int alarmId,
  }) async {
    writes++;
    lastHomeId = homeId;
    lastAlarmId = alarmId;
    if (acknowledge == null) {
      throw StateError('Unexpected alarm write');
    }
    return acknowledge!();
  }
}

Future<void> _mount(
  WidgetTester tester,
  _FakeAuthService auth, {
  String role = 'owner',
  Future<void> Function()? onSessionExpired,
}) async {
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: HomeDetailsScreen(
        home: _home(role),
        authService: auth,
        onSessionExpired: onSessionExpired ?? () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _showAlarm(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Alarm SOS'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final role in ['owner', 'caregiver']) {
    testWidgets('$role can acknowledge once and sees refreshed status',
        (tester) async {
      final auth = _FakeAuthService(
        [
          () async => _data(active: [_active], history: [_active]),
          () async => _data(active: [_acknowledged], history: [_acknowledged]),
        ],
        acknowledge: () async => _acknowledged,
      );

      await _mount(tester, auth, role: role);
      await _showAlarm(tester);
      await tester.tap(find.text('Potwierdź alarm'));
      await tester.pumpAndSettle();

      expect(auth.writes, 1);
      expect(auth.reads, 2);
      expect(auth.lastHomeId, 'home_ci');
      expect(auth.lastAlarmId, 27);
      expect(find.text('Potwierdzony'), findsOneWidget);
      expect(find.text('Potwierdź alarm'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('viewer cannot acknowledge an active alarm',
      (tester) async {
    final auth = _FakeAuthService([
      () async => _data(active: [_active], history: [_active]),
    ]);

    await _mount(tester, auth, role: 'viewer');
    await _showAlarm(tester);

    expect(find.text('Aktywny'), findsOneWidget);
    expect(find.text('Potwierdź alarm'), findsNothing);
    expect(auth.writes, 0);
  });

  testWidgets('already acknowledged alarm has no write action',
      (tester) async {
    final auth = _FakeAuthService([
      () async => _data(
        active: [_acknowledged],
        history: [_acknowledged],
      ),
    ]);

    await _mount(tester, auth);
    await _showAlarm(tester);

    expect(find.text('Potwierdzony'), findsOneWidget);
    expect(find.text('Potwierdź alarm'), findsNothing);
    expect(auth.writes, 0);
  });

  testWidgets('resolved alarm has no acknowledge action',
      (tester) async {
    final auth = _FakeAuthService([
      () async => _data(history: [_resolved]),
    ]);

    await _mount(tester, auth);
    await _showAlarm(tester);

    expect(find.text('Alarm SOS'), findsOneWidget);
    expect(find.text('Potwierdź alarm'), findsNothing);
    expect(auth.writes, 0);
  });

  testWidgets('403 on acknowledgement is shown and does not log out',
      (tester) async {
    var logoutCount = 0;
    final auth = _FakeAuthService(
      [
        () async => _data(active: [_active], history: [_active]),
      ],
      acknowledge: () async => throw const ApiException(
        'Access denied.',
        statusCode: 403,
      ),
    );

    await _mount(
      tester,
      auth,
      onSessionExpired: () async { logoutCount++; },
    );
    await _showAlarm(tester);
    await tester.tap(find.text('Potwierdź alarm'));
    await tester.pump();

    expect(find.text('Nie masz uprawnień do potwierdzania alarmów.'),
        findsOneWidget);
    expect(auth.writes, 1);
    expect(auth.reads, 1);
    expect(logoutCount, 0);
  });

  testWidgets('401 during acknowledgement expires the session',
      (tester) async {
    var logoutCount = 0;
    final auth = _FakeAuthService(
      [
        () async => _data(active: [_active], history: [_active]),
      ],
      acknowledge: () async => throw const ApiException(
        'Session expired.',
        statusCode: 401,
      ),
    );

    await _mount(
      tester,
      auth,
      onSessionExpired: () async { logoutCount++; },
    );
    await _showAlarm(tester);
    await tester.tap(find.text('Potwierdź alarm'));
    await tester.pump();

    expect(auth.writes, 1);
    expect(logoutCount, 1);
  });

  testWidgets('a second tap cannot send two pending acknowledgements',
      (tester) async {
    final completer = Completer<Alarm>();
    final auth = _FakeAuthService(
      [
        () async => _data(active: [_active], history: [_active]),
        () async => _data(
          active: [_acknowledged],
          history: [_acknowledged],
        ),
      ],
      acknowledge: () => completer.future,
    );

    await _mount(tester, auth);
    await _showAlarm(tester);
    await tester.tap(find.text('Potwierdź alarm'));
    await tester.pump();

    expect(find.text('Potwierdzanie...'), findsOneWidget);
    await tester.tap(find.text('Potwierdzanie...'));
    await tester.pump();
    expect(auth.writes, 1);

    completer.complete(_acknowledged);
    await tester.pumpAndSettle();
    expect(auth.writes, 1);
    expect(auth.reads, 2);
    expect(find.text('Potwierdzony'), findsOneWidget);
  });

  testWidgets('POST waits for an earlier refresh before reading new alarm',
      (tester) async {
    final oldRead = Completer<HomeDetailsData>();
    final auth = _FakeAuthService(
      [
        () async => _data(active: [_active], history: [_active]),
        () => oldRead.future,
        () async => _data(
          active: [_acknowledged],
          history: [_acknowledged],
        ),
      ],
      acknowledge: () async => _acknowledged,
    );

    await _mount(tester, auth);
    await _showAlarm(tester);
    await tester.tap(find.byTooltip('Odśwież teraz'));
    await tester.pump();

    expect(auth.reads, 2);
    await tester.tap(find.text('Potwierdź alarm'));
    await tester.pump();
    expect(auth.writes, 1);
    expect(auth.reads, 2);

    oldRead.complete(_data(active: [_active], history: [_active]));
    await tester.pumpAndSettle();

    expect(auth.reads, 3);
    expect(find.text('Potwierdzony'), findsOneWidget);
    expect(find.text('Potwierdź alarm'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
