import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm.dart';
import 'package:vedasentio_mobile/models/home_safety_status.dart';
import 'package:vedasentio_mobile/services/alarm_status_service.dart';

Alarm alarm({
  required int id,
  required String severity,
  required String status,
}) {
  return Alarm(
    id: id,
    homeId: 'home_001',
    deviceId: 'sos_001',
    alarmType: 'sos',
    severity: severity,
    status: status,
    startedAt: '2026-10-05 15:11:36+00',
    createdAt: '2026-10-05 15:11:36+00',
    updatedAt: '2026-10-05 15:11:36+00',
  );
}

void main() {
  test(
    'parses acknowledged backend alarm',
    () {
      final parsed =
          Alarm.fromJson(
        {
          'id': 2,
          'home_id': 'home_001',
          'device_id': 'sos_001',
          'alarm_type': 'sos',
          'severity': 'critical',
          'status':
              'acknowledged',
          'source_event_id': 47,
          'last_event_id': 47,
          'started_at':
              '2026-10-05 15:11:36+00',
          'acknowledged_at':
              '2026-10-05 15:12:33+00',
          'acknowledged_by': 3,
          'resolved_at': null,
          'resolved_by': null,
          'resolution_source':
              null,
          'created_at':
              '2026-10-05 15:11:36+00',
          'updated_at':
              '2026-10-05 15:12:33+00',
        },
      );

      expect(
        parsed.isActive,
        isTrue,
      );

      expect(
        parsed.isAcknowledged,
        isTrue,
      );

      expect(
        parsed.acknowledgedBy,
        3,
      );
    },
  );

  test(
    'no active backend alarm means safe presentation',
    () {
      final status =
          AlarmStatusService
              .fromBackendAlarms(
        const [],
      );

      expect(
        status.level,
        SafetyLevel.safe,
      );
    },
  );

  test(
    'critical backend alarm means alarm presentation',
    () {
      final status =
          AlarmStatusService
              .fromBackendAlarms(
        [
          alarm(
            id: 1,
            severity: 'critical',
            status: 'active',
          ),
        ],
      );

      expect(
        status.level,
        SafetyLevel.alarm,
      );
    },
  );

  test(
    'acknowledged critical alarm remains alarm',
    () {
      final status =
          AlarmStatusService
              .fromBackendAlarms(
        [
          alarm(
            id: 1,
            severity: 'critical',
            status:
                'acknowledged',
          ),
        ],
      );

      expect(
        status.level,
        SafetyLevel.alarm,
      );
    },
  );
}
