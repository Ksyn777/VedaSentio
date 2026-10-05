class Alarm {
  const Alarm({
    required this.id,
    required this.homeId,
    required this.deviceId,
    required this.alarmType,
    required this.severity,
    required this.status,
    required this.startedAt,
    required this.createdAt,
    required this.updatedAt,
    this.sourceEventId,
    this.lastEventId,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionSource,
  });

  final int id;
  final String homeId;
  final String deviceId;
  final String alarmType;
  final String severity;
  final String status;

  final int? sourceEventId;
  final int? lastEventId;

  final String startedAt;
  final String? acknowledgedAt;
  final int? acknowledgedBy;
  final String? resolvedAt;
  final int? resolvedBy;
  final String? resolutionSource;

  final String createdAt;
  final String updatedAt;

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: (json['id'] as num?)?.toInt() ?? 0,
      homeId: json['home_id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      alarmType: json['alarm_type'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      status: json['status'] as String? ?? '',
      sourceEventId:
          (json['source_event_id'] as num?)?.toInt(),
      lastEventId:
          (json['last_event_id'] as num?)?.toInt(),
      startedAt: json['started_at'] as String? ?? '',
      acknowledgedAt:
          json['acknowledged_at'] as String?,
      acknowledgedBy:
          (json['acknowledged_by'] as num?)?.toInt(),
      resolvedAt: json['resolved_at'] as String?,
      resolvedBy:
          (json['resolved_by'] as num?)?.toInt(),
      resolutionSource:
          json['resolution_source'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  bool get isActive =>
      status == 'active' || status == 'acknowledged';

  bool get isAcknowledged => status == 'acknowledged';

  bool get isResolved => status == 'resolved';

  bool get isCritical => severity == 'critical';

  String get typeLabel {
    return switch (alarmType) {
      'sos' => 'Alarm SOS',
      'smoke' => 'Dym',
      'co' => 'Tlenek węgla',
      'gas' => 'Gaz',
      'flood' => 'Zalanie',
      _ => alarmType.isEmpty ? 'Alarm' : alarmType,
    };
  }

  String get severityLabel {
    return switch (severity) {
      'critical' => 'Krytyczny',
      'warning' => 'Ostrzeżenie',
      _ => severity.isEmpty ? 'Nieznany' : severity,
    };
  }

  String get statusLabel {
    return switch (status) {
      'active' => 'Aktywny',
      'acknowledged' => 'Potwierdzony',
      'resolved' => 'Zakończony',
      _ => status.isEmpty ? 'Nieznany' : status,
    };
  }
}
