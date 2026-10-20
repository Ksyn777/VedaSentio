import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/models/home_safety_status.dart';
import 'package:vedasentio_mobile/services/alarm_status_service.dart';

void main() {
  test(
    'alarm dymu jest krytyczny i ustawia stan ALARM',
    () {
      Alarm smokeAlarm = Alarm.fromJson({
        'id': 40,
        'home_id': 'home_001',
        'device_id': 'smoke_001',
        'alarm_type': 'smoke',
        'severity': 'critical',
        'status': 'active',
        'started_at': '2026-10-20 16:00:00+02',
        'created_at': '2026-10-20 16:00:00+02',
        'updated_at': '2026-10-20 16:00:00+02',
      });

      HomeSafetyStatus safetyStatus =
          AlarmStatusService.fromBackendAlarms(
        [smokeAlarm],
      );

      expect(smokeAlarm.typeLabel, 'Dym');
      expect(safetyStatus.level, SafetyLevel.alarm);
      expect(safetyStatus.title, 'ALARM');
    },
  );

  test(
    'alarm zalania jest ostrzezeniem',
    () {
      Alarm floodAlarm = Alarm.fromJson({
        'id': 41,
        'home_id': 'home_001',
        'device_id': 'flood_001',
        'alarm_type': 'flood',
        'severity': 'warning',
        'status': 'active',
        'started_at': '2026-10-20 16:10:00+02',
        'created_at': '2026-10-20 16:10:00+02',
        'updated_at': '2026-10-20 16:10:00+02',
      });

      HomeSafetyStatus safetyStatus =
          AlarmStatusService.fromBackendAlarms(
        [floodAlarm],
      );

      expect(floodAlarm.typeLabel, 'Zalanie');
      expect(safetyStatus.level, SafetyLevel.warning);
      expect(safetyStatus.title, 'Ostrzeżenie');
    },
  );
}
