import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/device.dart';

void main() {
  test(
    'odczytuje status online i czas ostatniego kontaktu',
    () {
      Device device = Device.fromJson({
        'home_id': 'home_001',
        'id': 'sos_001',
        'device_type': 'sos_button',
        'name': 'Przycisk SOS',
        'is_active': true,
        'last_seen_at': '2026-10-16 16:00:00+02',
        'is_online': true,
        'created_at': '2026-10-01 10:00:00+02',
      });

      expect(device.isActive, true);
      expect(device.isOnline, true);
      expect(
        device.lastSeenAt,
        '2026-10-16 16:00:00+02',
      );
    },
  );

  test(
    'urzadzenie bez kontaktu jest offline',
    () {
      Device device = Device.fromJson({
        'home_id': 'home_001',
        'id': 'sos_001',
        'device_type': 'sos_button',
        'name': 'Przycisk SOS',
        'is_active': true,
        'last_seen_at': null,
        'is_online': false,
        'created_at': '2026-10-01 10:00:00+02',
      });

      expect(device.isOnline, false);
      expect(device.lastSeenAt, isNull);
    },
  );
}
