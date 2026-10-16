import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/services/alarm_status_service.dart';

void main() {
  test(
    'alarm offline ma etykiete ostrzezenia o urzadzeniu',
    () {
      Alarm alarm = Alarm.fromJson({
        'id': 10,
        'home_id': 'home_001',
        'device_id': 'sos_001',
        'alarm_type': 'device_offline',
        'severity': 'warning',
        'status': 'active',
        'started_at': '2026-10-16 17:00:00+02',
        'created_at': '2026-10-16 17:00:00+02',
        'updated_at': '2026-10-16 17:00:00+02',
      });

      expect(
        alarm.typeLabel,
        'Urządzenie offline',
      );

      expect(
        alarm.severityLabel,
        'Ostrzeżenie',
      );
    },
  );

  test(
    'alarm offline ustawia problem z monitoringiem',
    () {
      Alarm alarm = Alarm.fromJson({
        'id': 10,
        'home_id': 'home_001',
        'device_id': 'sos_001',
        'alarm_type': 'device_offline',
        'severity': 'warning',
        'status': 'active',
        'started_at': '2026-10-16 17:00:00+02',
        'created_at': '2026-10-16 17:00:00+02',
        'updated_at': '2026-10-16 17:00:00+02',
      });

      final status =
          AlarmStatusService.fromBackendAlarms(
        [alarm],
      );

      expect(
        status.title,
        'Problem z monitoringiem',
      );
    },
  );
}
