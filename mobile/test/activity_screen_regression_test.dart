import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/home.dart';
import 'package:vedasentio_mobile/models/sensor_event.dart';
import 'package:vedasentio_mobile/models/session_data.dart';
import 'package:vedasentio_mobile/models/user_profile.dart';
import 'package:vedasentio_mobile/screens/activity_screen.dart';
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

SensorEvent _event(String type, int id, {DateTime? when}) => SensorEvent(
      id: id,
      homeId: 'a',
      deviceId: 'door_ci',
      eventType: type,
      value: true,
      deviceTimestamp: (when ?? DateTime.now()).toUtc().toIso8601String(),
      receivedAt: (when ?? DateTime.now()).toUtc().toIso8601String(),
    );

class _FakeAuth extends AuthService {
  _FakeAuth(this.handlers);

  final Map<String, List<Future<List<SensorEvent>> Function()>> handlers;
  final List<String> requested = [];

  @override
  Future<List<SensorEvent>> loadHomeEvents(String homeId, {int limit = 50}) {
    requested.add(homeId);
    expect(limit, 50);
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
      body: ActivityScreen(
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
  testWidgets('real event labels are Polish and heartbeat is excluded',
      (tester) async {
    final fake = _FakeAuth({
      'a': [() async => [
            _event('door_opened', 1),
            _event('sos_pressed', 2),
            _event('flood_detected', 3),
            _event('heartbeat', 4),
          ]],
    });

    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();

    for (final label in ['Otwarto drzwi', 'Naciśnięto SOS', 'Wykryto zalanie']) {
      await _reveal(tester, label);
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('heartbeat'), findsNothing);
    expect(find.text('Ostatnie zdarzenia: 3'), findsOneWidget);
    expect(fake.requested, ['a']);
  });

  testWidgets('calendar filter separates today, yesterday and all',
      (tester) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
    final today = DateTime(now.year, now.month, now.day, 12);
    final fake = _FakeAuth({
      'a': [() async => [
            _event('door_opened', 1, when: today),
            _event('flood_detected', 2, when: yesterday),
          ]],
    });

    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Wczoraj'));
    await tester.pumpAndSettle();
    expect(find.text('Otwarto drzwi'), findsNothing);
    await _reveal(tester, 'Wykryto zalanie');

    await tester.tap(find.widgetWithText(ActionChip, 'Wszystkie'));
    await tester.pumpAndSettle();
    await _reveal(tester, 'Otwarto drzwi');
    expect(fake.requested.length, 1);
  });

  testWidgets('empty activity and empty date filter have distinct messages',
      (tester) async {
    final fake = _FakeAuth({
      'a': [() async => [_event('door_closed', 2)]],
    });
    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Wczoraj'));
    await tester.pumpAndSettle();
    expect(find.text('Brak zdarzeń'), findsOneWidget);
  });

  testWidgets('no assigned homes does not make an HTTP request',
      (tester) async {
    final fake = _FakeAuth({});
    await _mount(tester, fake, homes: []);
    await tester.pumpAndSettle();
    expect(find.text('Brak gospodarstw'), findsOneWidget);
    expect(fake.requested, isEmpty);
  });

  testWidgets('switching homes discards delayed data from previous home',
      (tester) async {
    final slowA = Completer<List<SensorEvent>>();
    final fake = _FakeAuth({
      'a': [() => slowA.future],
      'b': [() async => [_event('flood_detected', 3)]],
    });

    await _mount(tester, fake);
    await tester.tap(find.widgetWithText(FilterChip, 'Dom Beta'));
    await tester.pumpAndSettle();

    await _reveal(tester, 'Wykryto zalanie');
    expect(find.text('Dom Beta'), findsWidgets);
    slowA.complete([_event('sos_pressed', 99)]);
    await tester.pumpAndSettle();
    expect(find.text('Naciśnięto SOS'), findsNothing);
    expect(find.text('Wykryto zalanie'), findsOneWidget);
    expect(fake.requested, ['a', 'b']);
  });

  testWidgets('obsolete 401 on previous home cannot log out newer view',
      (tester) async {
    final slowA = Completer<List<SensorEvent>>();
    var logouts = 0;
    final fake = _FakeAuth({
      'a': [() => slowA.future],
      'b': [() async => [_event('door_closed', 5)]],
    });

    await _mount(
      tester,
      fake,
      onSessionExpired: () async { logouts++; },
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Dom Beta'));
    await tester.pumpAndSettle();

    slowA.completeError(const ApiException('Old request', statusCode: 401));
    await tester.pumpAndSettle();
    expect(logouts, 0);
    await _reveal(tester, 'Zamknięto drzwi');
  });

  testWidgets('compact screen does not overflow with SOS and flood',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = _FakeAuth({
      'a': [() async => [_event('sos_pressed', 1), _event('flood_detected', 2)]],
    });
    await _mount(tester, fake, homes: [_homes.first]);
    await tester.pumpAndSettle();
    await _reveal(tester, 'Wykryto zalanie');
    expect(tester.takeException(), isNull);
  });
}
