import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/home_safety_status.dart';
import 'package:vedasentio_mobile/models/sensor_event.dart';
import 'package:vedasentio_mobile/services/home_safety_evaluator.dart';

SensorEvent event({
  required int id,
  required String type,
  required dynamic value,
  required DateTime time,
}) {
  return SensorEvent(
    id: id,
    homeId: 'home_001',
    deviceId: 'device_001',
    eventType: type,
    value: value,
    deviceTimestamp: time.toUtc().toIso8601String(),
    receivedAt: time.toUtc().toIso8601String(),
  );
}

void main() {
  final now = DateTime.utc(
    2026,
    10,
    5,
    16,
    0,
  );

  test(
    'old SOS event does not keep the house in alarm forever',
    () {
      final result =
          HomeSafetyEvaluator.evaluate(
        [
          event(
            id: 1,
            type: 'sos_pressed',
            value: true,
            time: now.subtract(
              const Duration(hours: 2),
            ),
          ),
        ],
        now: now,
      );

      expect(
        result.level,
        SafetyLevel.safe,
      );
    },
  );

  test(
    'recent SOS creates alarm',
    () {
      final result =
          HomeSafetyEvaluator.evaluate(
        [
          event(
            id: 1,
            type: 'sos_pressed',
            value: true,
            time: now.subtract(
              const Duration(minutes: 3),
            ),
          ),
        ],
        now: now,
      );

      expect(
        result.level,
        SafetyLevel.alarm,
      );
    },
  );

  test(
    'gas remains alarm until cleared',
    () {
      final detected = event(
        id: 1,
        type: 'gas_detected',
        value: true,
        time: now.subtract(
          const Duration(hours: 3),
        ),
      );

      final active =
          HomeSafetyEvaluator.evaluate(
        [detected],
        now: now,
      );

      expect(
        active.level,
        SafetyLevel.alarm,
      );

      final cleared =
          HomeSafetyEvaluator.evaluate(
        [
          detected,
          event(
            id: 2,
            type: 'gas_cleared',
            value: false,
            time: now.subtract(
              const Duration(minutes: 1),
            ),
          ),
        ],
        now: now,
      );

      expect(
        cleared.level,
        SafetyLevel.safe,
      );
    },
  );

  test(
    'flood creates warning',
    () {
      final result =
          HomeSafetyEvaluator.evaluate(
        [
          event(
            id: 1,
            type: 'flood_detected',
            value: true,
            time: now,
          ),
        ],
        now: now,
      );

      expect(
        result.level,
        SafetyLevel.warning,
      );
    },
  );

  test(
    'door event is informational only',
    () {
      final result =
          HomeSafetyEvaluator.evaluate(
        [
          event(
            id: 1,
            type: 'door_opened',
            value: true,
            time: now,
          ),
        ],
        now: now,
      );

      expect(
        result.level,
        SafetyLevel.safe,
      );
    },
  );
}
