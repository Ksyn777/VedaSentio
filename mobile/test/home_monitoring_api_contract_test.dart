import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vedasentio_mobile/models/home_safety_status.dart';
import 'package:vedasentio_mobile/services/alarm_status_service.dart';
import 'package:vedasentio_mobile/services/api_client.dart';
import 'package:vedasentio_mobile/services/auth_service.dart';
import 'package:vedasentio_mobile/services/token_storage.dart';

class _MemoryTokens extends TokenStorage {
  @override
  Future<String?> read() async => 'ci-fake-jwt';
}

Map<String, dynamic> _event(String type, int id) => {
      'id': id,
      'home_id': 'ci_home',
      'device_id': 'door_ci',
      'event_type': type,
      'value': type == 'door_opened',
      'device_timestamp': '2026-11-22T10:00:00Z',
      'received_at': '2026-11-22T10:00:01Z',
    };

final Map<String, dynamic> _critical = {
  'id': 41,
  'home_id': 'ci_home',
  'device_id': 'sos_ci',
  'alarm_type': 'sos',
  'severity': 'critical',
  'status': 'active',
  'started_at': '2026-11-22T10:01:00Z',
  'created_at': '2026-11-22T10:01:00Z',
  'updated_at': '2026-11-22T10:01:00Z',
};

void main() {
  test('wire-level API model refresh updates the door and active alarm', () async {
    var eventReads = 0;
    final paths = <String>[];
    final httpClient = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer ci-fake-jwt');
      expect(request.method, 'GET');
      paths.add(request.url.path);

      final path = request.url.path;
      final bool secondRead = eventReads >= 2;
      dynamic payload;

      if (path == '/api/homes/ci_home/devices') {
        payload = [
          {
            'home_id': 'ci_home',
            'id': 'door_ci',
            'device_type': 'door_contact',
            'name': 'Drzwi wejściowe',
            'is_active': true,
            'last_seen_at': '2026-11-22T10:01:00Z',
            'is_online': true,
            'created_at': '2026-11-20T10:00:00Z',
          }
        ];
      } else if (path == '/api/homes/ci_home/events') {
        expect(request.url.queryParameters['limit'], '20');
        eventReads++;
        payload = [_event(eventReads == 1 ? 'door_opened' : 'door_closed', eventReads)];
      } else if (path == '/api/homes/ci_home/alarms') {
        final isActive = request.url.queryParameters['active'] == 'true';
        if (!isActive) {
          expect(request.url.queryParameters['limit'], '20');
        }
        payload = secondRead ? [_critical] : [];
      } else if (path == '/api/homes/ci_home/devices/door_ci/latest') {
        payload = _event(secondRead ? 'door_closed' : 'door_opened', eventReads);
      } else {
        return http.Response('{"error":"unexpected route"}', 404);
      }

      return http.Response(jsonEncode(payload), 200, headers: {
        'content-type': 'application/json',
      });
    });

    final auth = AuthService(
      apiClient: ApiClient(client: httpClient),
      tokenStorage: _MemoryTokens(),
    );
    addTearDown(auth.dispose);

    final first = await auth.loadHomeDetails('ci_home');
    expect(first.devices.single.isOnline, true);
    expect(first.latestEventsByDevice['door_ci']?.eventType, 'door_opened');
    expect(first.recentEvents.single.eventType, 'door_opened');
    expect(first.activeAlarms, isEmpty);
    expect(
      AlarmStatusService.fromBackendAlarms(first.activeAlarms).level,
      SafetyLevel.safe,
    );

    final second = await auth.loadHomeDetails('ci_home');
    expect(second.latestEventsByDevice['door_ci']?.eventType, 'door_closed');
    expect(second.recentEvents.single.eventType, 'door_closed');
    expect(second.activeAlarms.single.alarmType, 'sos');
    expect(second.activeAlarms.single.isCritical, true);
    expect(
      AlarmStatusService.fromBackendAlarms(second.activeAlarms).level,
      SafetyLevel.alarm,
    );
    expect(paths.where((path) => path.endsWith('/latest')).length, 2);
    expect(eventReads, 2);
  });
}
