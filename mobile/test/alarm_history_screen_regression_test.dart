import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/models/home.dart';
import 'package:vedasentio_mobile/models/session_data.dart';
import 'package:vedasentio_mobile/models/user_profile.dart';
import 'package:vedasentio_mobile/screens/alarm_history_screen.dart';
import 'package:vedasentio_mobile/services/api_exception.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';

const _user = UserProfile(
  id: 1,
  email: 'ci@example.invalid',
  firstName: 'CI',
  lastName: 'Tester',
  phone: '',
  isActive: true,
  createdAt: '2026-11-22T00:00:00Z',
  homes: [],
);

const _homes = [
  Home(id: 'a', name: 'Dom Alfa', role: 'viewer', createdAt: ''),
  Home(id: 'b', name: 'Dom Beta', role: 'viewer', createdAt: ''),
];

Alarm _alarm(String type, String severity, int id, {String status = 'active'}) =>
    Alarm(
      id: id,
      homeId: 'a',
      deviceId: 'sensor_ci',
      alarmType: type,
      severity: severity,
      status: status,
      startedAt: '2026-11-22T10:00:00Z',
      createdAt: '2026-11-22T10:00:00Z',
      updatedAt: '2026-11-22T10:00:00Z',
    );

class _FakeAuth extends AuthService {
  _FakeAuth(this.handlers);

  final Map<String, List<Future<List<Alarm>> Function()>> handlers;
  final List<String> requested = [];

  @override
  Future<List<Alarm>> loadHomeAlarms(String homeId, {int limit = 50}) {
    expect(limit, 50);
    requested.add(homeId);
    final queue = handlers[homeId]!;
    if (queue.isEmpty) throw StateError('Unexpected request for $homeId');
    return queue.removeAt(0)();
  }
}

Future<void> _mount(
  WidgetTester tester,
  _FakeAuth fake, {
  List<Home> homes = _homes,
  Future<void> Function()? onSessionExpired,
}) async {
  addTearDown(fake.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AlarmHistoryScreen(
        session: SessionData(user: _user, homes: homes),
        auth: fake,
        onSessionExpired: onSessionExpired ?? () async {},
      ),
    ),
  ));
  await tester.pump();
}

Future<void> _reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    170,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('critical, flood and offline alarm labels are readable',
      (tester) async {
    final fake = _FakeAuth({
      'a': [() async => [
            _alarm('sos', 'critical', 1),
            _alarm('flood', 'warning', 2),
            _alarm('device_offline', 'warning', 3),
          ]],
    });

    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();

    for (final label in ['Alarm SOS', 'Zalanie', 'Urządzenie offline']) {
      await _reveal(tester, label);
    }
    expect(find.text('Problem z połączeniem urządzenia'), findsNothing);
    expect(fake.requested, ['a']);
  });

  testWidgets('severity filter distinguishes warning from critical alarms',
      (tester) async {
    final fake = _FakeAuth({
      'a': [() async => [
            _alarm('sos', 'critical', 1),
            _alarm('flood', 'warning', 2),
          ]],
    });
    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Krytyczne'));
    await tester.pumpAndSettle();
    await _reveal(tester, 'Alarm SOS');
    expect(find.text('Zalanie'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ostrzeżenia'));
    await tester.pumpAndSettle();
    await _reveal(tester, 'Zalanie');
    expect(find.text('Alarm SOS'), findsNothing);
    expect(fake.requested, ['a']);
  });

  testWidgets('empty data and empty category have distinct messages',
      (tester) async {
    final fake = _FakeAuth({
      'a': [() async => [_alarm('flood', 'warning', 2)]],
    });
    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Krytyczne'));
    await tester.pumpAndSettle();
    expect(find.text('Brak wyników'), findsOneWidget);
    expect(find.text('Brak alarmów'), findsNothing);
  });

  testWidgets('no assigned homes shows empty state without HTTP request',
      (tester) async {
    final fake = _FakeAuth({});
    await _mount(tester, fake, homes: []);
    await tester.pumpAndSettle();
    expect(find.text('Brak gospodarstw'), findsOneWidget);
    expect(fake.requested, isEmpty);
  });

  testWidgets('alarm details preserve the selected alarm and offline source',
      (tester) async {
    final fake = _FakeAuth({
      'a': [() async => [_alarm('device_offline', 'warning', 3)]],
    });
    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();
    await _reveal(tester, 'Urządzenie offline');
    await tester.tap(find.text('Urządzenie offline'));
    await tester.pumpAndSettle();
    expect(find.text('Problem z połączeniem urządzenia'), findsOneWidget);
    expect(find.text('Ostrzeżenie'), findsWidgets);
  });

  testWidgets('switching homes discards obsolete alarm data',
      (tester) async {
    final slowA = Completer<List<Alarm>>();
    final fake = _FakeAuth({
      'a': [() => slowA.future],
      'b': [() async => [_alarm('flood', 'warning', 2)]],
    });
    await _mount(tester, fake);
    await tester.tap(find.widgetWithText(FilterChip, 'Dom Beta'));
    await tester.pumpAndSettle();
    await _reveal(tester, 'Zalanie');
    slowA.complete([_alarm('sos', 'critical', 99)]);
    await tester.pumpAndSettle();
    expect(find.text('Alarm SOS'), findsNothing);
    expect(find.text('Zalanie'), findsOneWidget);
    expect(fake.requested, ['a', 'b']);
  });

  testWidgets('old 403 must not hide successful data for the new home',
      (tester) async {
    final slowA = Completer<List<Alarm>>();
    final fake = _FakeAuth({
      'a': [() => slowA.future],
      'b': [() async => [_alarm('flood', 'warning', 2)]],
    });
    await _mount(tester, fake);
    await tester.tap(find.widgetWithText(FilterChip, 'Dom Beta'));
    await tester.pumpAndSettle();
    slowA.completeError(const ApiException('Access denied', statusCode: 403));
    await tester.pumpAndSettle();
    expect(find.text('Nie udało się pobrać historii'), findsNothing);
    await _reveal(tester, 'Zalanie');
  });

  testWidgets('compact 320px layout fits alarm severity badges',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _FakeAuth({
      'a': [() async => [
            _alarm('device_offline', 'warning', 3),
            _alarm('sos', 'critical', 4),
          ]],
    });
    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();
    await _reveal(tester, 'Alarm SOS');
    expect(tester.takeException(), isNull);
  });
}
