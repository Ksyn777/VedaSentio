import 'device.dart';
import 'sensor_event.dart';

class HomeDetailsData {
  const HomeDetailsData({
    required this.devices,
    required this.recentEvents,
    required this.latestEventsByDevice,
  });

  final List<Device> devices;
  final List<SensorEvent> recentEvents;
  final Map<String, SensorEvent?> latestEventsByDevice;
}
