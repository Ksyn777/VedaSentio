import '../models/home_safety_status.dart';
import '../models/sensor_event.dart';

class HomeSafetyEvaluator {
  HomeSafetyEvaluator._();

  static const Duration _sosAlarmWindow =
      Duration(minutes: 15);

  static HomeSafetyStatus evaluate(
    List<SensorEvent> events, {
    DateTime? now,
  }) {
    final referenceNow =
        (now ?? DateTime.now()).toUtc();

    final sorted = [...events]
      ..sort(
        (a, b) => _eventTime(b).compareTo(
          _eventTime(a),
        ),
      );

    final sosAlarm = _recentActiveSos(
      sorted,
      referenceNow,
    );

    if (sosAlarm != null) {
      return HomeSafetyStatus(
        level: SafetyLevel.alarm,
        title: 'ALARM',
        message:
            'Wykryto niedawne użycie przycisku SOS.',
        triggeringEvent: sosAlarm,
      );
    }

    final smokeAlarm = _persistentState(
      sorted,
      activeTypes: const {
        'smoke_detected',
      },
      clearTypes: const {
        'smoke_cleared',
      },
    );

    if (smokeAlarm != null) {
      return HomeSafetyStatus(
        level: SafetyLevel.alarm,
        title: 'ALARM',
        message: 'Czujnik zgłosił obecność dymu.',
        triggeringEvent: smokeAlarm,
      );
    }

    final coAlarm = _persistentState(
      sorted,
      activeTypes: const {
        'co_detected',
      },
      clearTypes: const {
        'co_cleared',
      },
    );

    if (coAlarm != null) {
      return HomeSafetyStatus(
        level: SafetyLevel.alarm,
        title: 'ALARM',
        message:
            'Czujnik zgłosił obecność tlenku węgla.',
        triggeringEvent: coAlarm,
      );
    }

    final gasAlarm = _persistentState(
      sorted,
      activeTypes: const {
        'gas_detected',
      },
      clearTypes: const {
        'gas_cleared',
      },
    );

    if (gasAlarm != null) {
      return HomeSafetyStatus(
        level: SafetyLevel.alarm,
        title: 'ALARM',
        message: 'Czujnik zgłosił obecność gazu.',
        triggeringEvent: gasAlarm,
      );
    }

    final floodWarning = _persistentState(
      sorted,
      activeTypes: const {
        'flood_detected',
      },
      clearTypes: const {
        'flood_cleared',
      },
    );

    if (floodWarning != null) {
      return HomeSafetyStatus(
        level: SafetyLevel.warning,
        title: 'Ostrzeżenie',
        message:
            'Czujnik zgłosił możliwe zalanie.',
        triggeringEvent: floodWarning,
      );
    }

    return const HomeSafetyStatus(
      level: SafetyLevel.safe,
      title: 'Wszystko OK',
      message:
          'Brak aktywnych alarmów w dostępnych danych.',
    );
  }

  static SensorEvent? _recentActiveSos(
    List<SensorEvent> sorted,
    DateTime now,
  ) {
    for (final event in sorted) {
      if (event.eventType == 'sos_resolved') {
        return null;
      }

      if (
          event.eventType == 'sos_pressed' &&
          _isActiveValue(event.value)) {
        final time = _eventTime(event);

        if (now.difference(time) <= _sosAlarmWindow) {
          return event;
        }

        return null;
      }
    }

    return null;
  }

  static SensorEvent? _persistentState(
    List<SensorEvent> sorted, {
    required Set<String> activeTypes,
    required Set<String> clearTypes,
  }) {
    for (final event in sorted) {
      if (clearTypes.contains(event.eventType)) {
        return null;
      }

      if (activeTypes.contains(event.eventType)) {
        return _isActiveValue(event.value)
            ? event
            : null;
      }
    }

    return null;
  }

  static bool _isActiveValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized =
          value.trim().toLowerCase();

      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'active' ||
          normalized == 'alarm';
    }

    if (value is Map<String, dynamic>) {
      final nested = value['active'];

      if (nested != null) {
        return _isActiveValue(nested);
      }
    }

    return false;
  }

  static DateTime _eventTime(
    SensorEvent event,
  ) {
    final candidates = [
      event.receivedAt,
      event.deviceTimestamp,
    ];

    for (final candidate in candidates) {
      if (candidate.trim().isEmpty) {
        continue;
      }

      final parsed = DateTime.tryParse(
        candidate.trim().replaceFirst(
              ' ',
              'T',
            ),
      );

      if (parsed != null) {
        return parsed.toUtc();
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(
      0,
      isUtc: true,
    );
  }
}
