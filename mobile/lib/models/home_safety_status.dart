import 'sensor_event.dart';

enum SafetyLevel {
  safe,
  warning,
  alarm,
}

class HomeSafetyStatus {
  const HomeSafetyStatus({
    required this.level,
    required this.title,
    required this.message,
    this.triggeringEvent,
  });

  final SafetyLevel level;
  final String title;
  final String message;
  final SensorEvent? triggeringEvent;
}
