import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/device.dart';
import 'package:vedasentio_mobile/models/sensor_event.dart';

void main() {
  test('parses Device from API JSON', () {
    final device = Device.fromJson({
      'home_id': 'home_001',
      'id': 'sos_001',
      'device_type': 'sos_button',
      'name': 'Przycisk SOS',
      'is_active': true,
      'created_at': '2026-10-04 12:18:14+00',
    });

    expect(device.id, 'sos_001');
    expect(device.isActive, isTrue);
    expect(device.displayType, 'Przycisk SOS');
  });

  test('parses SensorEvent from API JSON', () {
    final event = SensorEvent.fromJson({
      'id': 41,
      'home_id': 'home_001',
      'device_id': 'sos_001',
      'event_type': 'sos_pressed',
      'value': true,
      'device_timestamp': '2026-10-04 12:30:00+00',
      'received_at': '2026-10-04 12:30:01+00',
    });

    expect(event.id, 41);
    expect(event.displayType, 'Naciśnięto SOS');
    expect(event.displayValue, 'aktywne');
  });
}
