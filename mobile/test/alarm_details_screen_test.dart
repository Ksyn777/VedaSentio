import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/screens/alarm_details_screen.dart';

void main() {
  testWidgets(
    'szczegoly alarmu pokazuja najwazniejsze dane',
    (tester) async {
      Alarm alarm = const Alarm(
        id: 10,
        homeId: 'home_001',
        deviceId: 'co_001',
        alarmType: 'co',
        severity: 'critical',
        status: 'resolved',
        startedAt: '2026-10-20T14:48:00Z',
        resolvedAt: '2026-10-20T14:50:00Z',
        resolutionSource: 'sensor_event',
        createdAt: '2026-10-20T14:48:00Z',
        updatedAt: '2026-10-20T14:50:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlarmDetailsScreen(
            alarm: alarm,
            sourceLabel: 'Czujnik CO',
          ),
        ),
      );

      expect(find.text('Szczegóły alarmu'), findsOneWidget);
      expect(find.text('Tlenek węgla'), findsOneWidget);
      expect(find.text('Czujnik CO'), findsOneWidget);
      expect(find.text('co_001'), findsOneWidget);
      expect(find.text('Zdarzenie z czujnika'), findsOneWidget);
    },
  );
}
