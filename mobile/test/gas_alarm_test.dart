import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/models/home_safety_status.dart';
import 'package:vedasentio_mobile/services/alarm_status_service.dart';

void main() {
  test(
    'alarm gazu jest krytyczny i ma czytelna etykiete',
    () {
      Alarm gasAlarm = Alarm.fromJson({
        'id': 20,
        'home_id': 'home_001',
        'device_id': 'gas_001',
        'alarm_type': 'gas',
        'severity': 'critical',
        'status': 'active',
        'started_at': '2026-10-16 18:30:00+02',
        'created_at': '2026-10-16 18:30:00+02',
        'updated_at': '2026-10-16 18:30:00+02',
      });

      expect(
        gasAlarm.typeLabel,
        'Alarm gazu',
      );

      expect(
        gasAlarm.severityLabel,
        'Krytyczny',
      );

      expect(
        gasAlarm.isCritical,
        true,
      );
    },
  );

  test(
    'aktywny alarm gazu ustawia czerwony stan alarmowy',
    () {
      Alarm gasAlarm = Alarm.fromJson({
        'id': 20,
        'home_id': 'home_001',
        'device_id': 'gas_001',
        'alarm_type': 'gas',
        'severity': 'critical',
        'status': 'active',
        'started_at': '2026-10-16 18:30:00+02',
        'created_at': '2026-10-16 18:30:00+02',
        'updated_at': '2026-10-16 18:30:00+02',
      });

      HomeSafetyStatus safetyStatus =
          AlarmStatusService.fromBackendAlarms(
        [gasAlarm],
      );

      expect(
        safetyStatus.level,
        SafetyLevel.alarm,
      );

      expect(
        safetyStatus.title,
        'ALARM',
      );
    },
  );
}
