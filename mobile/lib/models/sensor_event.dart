class SensorEvent {
  const SensorEvent({
    required this.id,
    required this.homeId,
    required this.deviceId,
    required this.eventType,
    required this.value,
    required this.deviceTimestamp,
    required this.receivedAt,
  });

  final int id;
  final String homeId;
  final String deviceId;
  final String eventType;
  final dynamic value;
  final String deviceTimestamp;
  final String receivedAt;

  factory SensorEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    return SensorEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      homeId:
          json['home_id'] as String? ?? '',
      deviceId:
          json['device_id'] as String? ?? '',
      eventType:
          json['event_type'] as String? ?? '',
      value: json['value'],
      deviceTimestamp:
          json['device_timestamp'] as String? ??
              '',
      receivedAt:
          json['received_at'] as String? ?? '',
    );
  }

  String get displayType {
    return switch (eventType) {
      'sos_pressed' => 'Naciśnięto SOS',
      'sos_resolved' => 'Alarm SOS zakończony',
      'door_opened' => 'Otwarto drzwi',
      'door_closed' => 'Zamknięto drzwi',
      'smoke_detected' => 'Wykryto dym',
      'smoke_cleared' => 'Dym niewykrywany',
      'co_detected' =>
        'Wykryto tlenek węgla',
      'co_cleared' =>
        'Tlenek węgla niewykrywany',
      'gas_detected' => 'Wykryto gaz',
      'gas_cleared' => 'Gaz niewykrywany',
      'flood_detected' =>
        'Wykryto zalanie',
      'flood_cleared' =>
        'Zalanie niewykrywane',
      _ => eventType.isEmpty
          ? 'Zdarzenie'
          : eventType,
    };
  }

  String get displayValue {
    final currentValue = value;

    if (currentValue == null) {
      return '';
    }

    if (currentValue is bool) {
      return currentValue
          ? 'aktywne'
          : 'nieaktywne';
    }

    if (currentValue is num ||
        currentValue is String) {
      return currentValue.toString();
    }

    return currentValue.toString();
  }
}
