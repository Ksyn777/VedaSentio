import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/screens/alarm_details_screen.dart';

const startedAt = '2026-11-22T10:00:00Z';

Alarm testAlarm(String status) => Alarm(
      id: 31,
      homeId: 'home_ci',
      deviceId: 'sos_ci',
      alarmType: 'sos',
      severity: 'critical',
      status: status,
      startedAt: startedAt,
      acknowledgedAt:
          status == 'acknowledged' ? '2026-11-22T10:01:00Z' : null,
      acknowledgedBy: status == 'acknowledged' ? 7 : null,
      resolvedAt: status == 'resolved' ? '2026-11-22T10:03:00Z' : null,
      resolutionSource: status == 'resolved' ? 'sensor_event' : null,
      createdAt: startedAt,
      updatedAt: startedAt,
    );

void main() {
  testWidgets('active alarm details show severity, device, status and time',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AlarmDetailsScreen(
        alarm: testAlarm('active'),
        sourceLabel: 'Przycisk SOS',
      ),
    ));

    expect(find.text('Alarm SOS'), findsOneWidget);
    expect(find.text('Przycisk SOS'), findsOneWidget);
    expect(find.text('sos_ci'), findsOneWidget);
    expect(find.text('Krytyczny'), findsOneWidget);
    expect(find.text('Aktywny'), findsOneWidget);
    expect(find.text('Rozpoczęto'), findsOneWidget);
    expect(find.text('Potwierdzono'), findsNothing);
  });

  testWidgets('acknowledged alarm shows acknowledgement timestamp',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AlarmDetailsScreen(
        alarm: testAlarm('acknowledged'),
        sourceLabel: 'Przycisk SOS',
      ),
    ));

    expect(find.text('Potwierdzony'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Potwierdzono'),
      170,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Potwierdzono'), findsOneWidget);
    expect(find.text('Zakończono'), findsNothing);
  });

  testWidgets('resolved alarm keeps history but offers no write action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AlarmDetailsScreen(
        alarm: testAlarm('resolved'),
        sourceLabel: 'Przycisk SOS',
      ),
    ));

    expect(find.text('Zakończony'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sposób zakończenia'),
      170,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Zdarzenie z czujnika'), findsOneWidget);
    expect(find.text('Potwierdź alarm'), findsNothing);
  });
}
