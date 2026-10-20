import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/sensor_event.dart';

void main() {
  test(
    'door_opened ma czytelna etykiete',
    () {
      SensorEvent doorOpened = SensorEvent.fromJson({
        'id': 50,
        'home_id': 'home_001',
        'device_id': 'door_001',
        'event_type': 'door_opened',
        'value': true,
        'device_timestamp': '2026-10-20T16:00:00Z',
        'received_at': '2026-10-20T16:00:01Z',
      });

      expect(doorOpened.displayType, 'Otwarto drzwi');
      expect(doorOpened.displayValue, 'aktywne');
    },
  );

  test(
    'door_closed ma czytelna etykiete',
    () {
      SensorEvent doorClosed = SensorEvent.fromJson({
        'id': 51,
        'home_id': 'home_001',
        'device_id': 'door_001',
        'event_type': 'door_closed',
        'value': false,
        'device_timestamp': '2026-10-20T16:01:00Z',
        'received_at': '2026-10-20T16:01:01Z',
      });

      expect(doorClosed.displayType, 'Zamknięto drzwi');
      expect(doorClosed.displayValue, 'nieaktywne');
    },
  );
}
