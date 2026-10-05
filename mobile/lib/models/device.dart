class Device {
  const Device({
    required this.homeId,
    required this.id,
    required this.deviceType,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  final String homeId;
  final String id;
  final String deviceType;
  final String name;
  final bool isActive;
  final String createdAt;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      homeId: json['home_id'] as String? ?? '',
      id: json['id'] as String? ?? '',
      deviceType: json['device_type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get displayType {
    return switch (deviceType) {
      'sos_button' => 'Przycisk SOS',
      'door_contact' => 'Czujnik drzwi',
      'smoke_detector' => 'Czujnik dymu',
      'co_detector' => 'Czujnik CO',
      'gas_detector' => 'Czujnik gazu',
      'flood_sensor' => 'Czujnik zalania',
      _ => deviceType.isEmpty ? 'Urządzenie' : deviceType,
    };
  }
}
