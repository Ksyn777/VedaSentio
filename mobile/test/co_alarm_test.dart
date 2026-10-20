import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/models/home_safety_status.dart';
import 'package:vedasentio_mobile/services/alarm_status_service.dart';

void main() {
  test(
    'alarm CO jest krytyczny i ma czytelna etykiete',
    () {
      Alarm coAlarm = Alarm.fromJson({
        'id': 30,
        'home_id': 'home_001',
        'device_id': 'co_001',
        'alarm_type': 'co',
        'severity': 'critical',
        'status': 'active',
        'started_at': '2026-10-20 16:00:00+02',
        'created_at': '2026-10-20 16:00:00+02',
        'updated_at': '2026-10-20 16:00:00+02',
      });

      expect(coAlarm.typeLabel, 'Tlenek węgla');
      expect(coAlarm.severityLabel, 'Krytyczny');
      expect(coAlarm.isCritical, true);
    },
  );

  test(
    'aktywny alarm CO ustawia czerwony stan alarmowy',
    () {
      Alarm coAlarm = Alarm.fromJson({
        'id': 30,
        'home_id': 'home_001',
        'device_id': 'co_001',
        'alarm_type': 'co',
        'severity': 'critical',
        'status': 'active',
        'started_at': '2026-10-20 16:00:00+02',
        'created_at': '2026-10-20 16:00:00+02',
        'updated_at': '2026-10-20 16:00:00+02',
      });

      HomeSafetyStatus safetyStatus =
          AlarmStatusService.fromBackendAlarms([coAlarm]);

      expect(safetyStatus.level, SafetyLevel.alarm);
      expect(safetyStatus.title, 'ALARM');
    },
  );
}
