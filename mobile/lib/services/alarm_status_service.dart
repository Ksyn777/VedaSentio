import '../models/alarm.dart';
import '../models/home_safety_status.dart';

class AlarmStatusService {
  AlarmStatusService._();

  static HomeSafetyStatus fromBackendAlarms(
    List<Alarm> activeAlarms,
  ) {
    if (activeAlarms.isEmpty) {
      return const HomeSafetyStatus(
        level: SafetyLevel.safe,
        title: 'Wszystko OK',
        message:
            'Backend nie zgłasza obecnie aktywnych alarmów.',
      );
    }

    final critical = activeAlarms
        .where((alarm) => alarm.severity == 'critical')
        .toList(growable: false);

    if (critical.isNotEmpty) {
      final allAcknowledged =
          critical.every((alarm) => alarm.isAcknowledged);

      return HomeSafetyStatus(
        level: SafetyLevel.alarm,
        title: 'ALARM',
        message: allAcknowledged
            ? 'Krytyczny alarm został potwierdzony przez opiekuna, ale nadal pozostaje aktywny.'
            : 'Backend zgłasza aktywny alarm wymagający reakcji.',
      );
    }

    return HomeSafetyStatus(
      level: SafetyLevel.warning,
      title: 'Ostrzeżenie',
      message:
          'Backend zgłasza ${activeAlarms.length} aktywny alarm o poziomie ostrzegawczym.',
    );
  }
}
