import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/models/device.dart';
import 'package:vedasentio_mobile/models/home.dart';
import 'package:vedasentio_mobile/models/home_details_data.dart';
import 'package:vedasentio_mobile/screens/home_details_screen.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';

const _home = Home(
  id: 'ci_home',
  name: 'Dom testowy',
  role: 'viewer',
  createdAt: '2026-11-22T00:00:00Z',
);

const _online = Device(
  homeId: 'ci_home',
  id: 'door_ci',
  deviceType: 'door_contact',
  name: 'Drzwi frontowe',
  isActive: true,
  lastSeenAt: '2026-11-22T10:00:00Z',
  isOnline: true,
  createdAt: '2026-11-21T10:00:00Z',
);

const _offline = Device(
  homeId: 'ci_home',
  id: 'door_ci',
  deviceType: 'door_contact',
  name: 'Drzwi frontowe',
  isActive: true,
  lastSeenAt: '2026-11-22T09:00:00Z',
  isOnline: false,
  createdAt: '2026-11-21T10:00:00Z',
);

const _inactive = Device(
  homeId: 'ci_home',
  id: 'old_ci',
  deviceType: 'door_contact',
  name: 'Stary czujnik',
  isActive: false,
  lastSeenAt: null,
  isOnline: false,
  createdAt: '2026-11-21T10:00:00Z',
);

const _critical = Alarm(
  id: 9,
  homeId: 'ci_home',
  deviceId: 'door_ci',
  alarmType: 'sos',
  severity: 'critical',
  status: 'active',
  startedAt: '2026-11-22T10:00:00Z',
  createdAt: '2026-11-22T10:00:00Z',
  updatedAt: '2026-11-22T10:00:00Z',
);

HomeDetailsData _data({
  List<Device> devices = const [],
  List<Alarm> alarms = const [],
}) => HomeDetailsData(
      devices: devices,
      recentEvents: const [],
      latestEventsByDevice: const {},
      activeAlarms: alarms,
      alarmHistory: alarms,
    );

class _FakeAuth extends AuthService {
  _FakeAuth(this.fetches);
  final List<Future<HomeDetailsData> Function()> fetches;

  @override
  Future<HomeDetailsData> loadHomeDetails(
    String homeId, {
    int eventLimit = 20,
    int alarmHistoryLimit = 20,
  }) => fetches.removeAt(0)();
}

Future<void> _mount(WidgetTester tester, _FakeAuth auth) async {
  addTearDown(auth.dispose);
  await tester.pumpWidget(MaterialApp(
    home: HomeDetailsScreen(
      home: _home,
      authService: auth,
      onSessionExpired: () async {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('zero devices is unmonitored, never safe', (tester) async {
    await _mount(tester, _FakeAuth([() async => _data()]));

    expect(find.text('Monitoring nieaktywny'), findsOneWidget);
    expect(find.text('Brak aktywnych czujników'), findsOneWidget);
    expect(find.text('Wszystko OK'), findsNothing);
    expect(find.text('Miejsce na zdjęcie domu'), findsNothing);
    expect(find.text('Monitoring na żywo'), findsNothing);
  });

  testWidgets('inactive devices do not count as monitoring', (tester) async {
    await _mount(tester, _FakeAuth([
      () async => _data(devices: [_inactive]),
    ]));

    expect(find.text('Monitoring nieaktywny'), findsOneWidget);
    expect(find.text('0 z 0 urządzeń online'), findsOneWidget);
  });

  testWidgets('online sensor with no alarms gets neutral last-read status',
      (tester) async {
    await _mount(tester, _FakeAuth([
      () async => _data(devices: [_online]),
    ]));

    expect(find.text('Brak aktywnych alarmów'), findsWidgets);
    expect(find.text('Monitoring na żywo'), findsOneWidget);
    expect(find.text('1 z 1 urządzeń online'), findsOneWidget);
    expect(find.text('Wszystko OK'), findsNothing);
  });

  testWidgets('offline sensor without alarm is a warning', (tester) async {
    await _mount(tester, _FakeAuth([
      () async => _data(devices: [_offline]),
    ]));

    expect(find.text('Wymagana uwaga'), findsOneWidget);
    expect(find.text('Monitoring nieaktywny'), findsNothing);
    expect(find.text('0 z 1 urządzeń online'), findsOneWidget);
  });

  testWidgets('failed refresh cannot keep a reassuring status',
      (tester) async {
    final auth = _FakeAuth([
      () async => _data(devices: [_online]),
      () async => throw const ApiException('Brak połączenia z serwerem.'),
    ]);
    await _mount(tester, auth);
    expect(find.text('Brak aktywnych alarmów'), findsWidgets);

    await tester.tap(find.byTooltip('Odśwież teraz'));
    await tester.pumpAndSettle();

    expect(find.text('Stan niepotwierdzony'), findsOneWidget);
    expect(find.text('Dane nieaktualne'), findsOneWidget);
    expect(find.text('Monitoring na żywo'), findsNothing);
    expect(find.text('Miejsce na zdjęcie domu'), findsNothing);
  });

  testWidgets('critical alarm remains visible during connection loss',
      (tester) async {
    final auth = _FakeAuth([
      () async => _data(devices: [_online], alarms: [_critical]),
      () async => throw const ApiException('Sieć niedostępna.'),
    ]);
    await _mount(tester, auth);
    expect(find.text('ALARM'), findsOneWidget);

    await tester.tap(find.byTooltip('Odśwież teraz'));
    await tester.pumpAndSettle();
    expect(find.text('ALARM — dane nieaktualne'), findsOneWidget);
    expect(find.text('Aktywne alarmy: 1'), findsOneWidget);
    expect(find.text('Stan niepotwierdzony'), findsNothing);
  });
}
