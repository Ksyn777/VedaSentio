import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';

void main() {
  test(
    'model alarmu nadal poprawnie rozpoznaje alarm aktywny',
    () {
      Alarm safetyAlarm = const Alarm(
        id: 1,
        homeId: 'home_001',
        deviceId: 'sos_001',
        alarmType: 'sos',
        severity: 'critical',
        status: 'active',
        startedAt: '2026-10-05 15:11:36+00',
        createdAt: '2026-10-05 15:11:36+00',
        updatedAt: '2026-10-05 15:11:36+00',
      );

      bool alarmIsActive =
          safetyAlarm.isActive;

      expect(
        alarmIsActive,
        true,
      );
    },
  );
}
