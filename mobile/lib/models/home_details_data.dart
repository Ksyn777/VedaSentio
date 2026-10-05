import 'alarm.dart';
import 'device.dart';
import 'sensor_event.dart';

class HomeDetailsData {
  const HomeDetailsData({
    required this.devices,
    required this.recentEvents,
    required this.latestEventsByDevice,
    required this.activeAlarms,
    required this.alarmHistory,
  });

  final List<Device> devices;
  final List<SensorEvent> recentEvents;
  final Map<String, SensorEvent?> latestEventsByDevice;

  /// Alarmy, których cykl życia prowadzi backend.
  final List<Alarm> activeAlarms;

  /// Ostatnie alarmy (w tym resolved) do historii użytkownika.
  final List<Alarm> alarmHistory;
}
