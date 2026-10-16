import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm_notification_target.dart';

void main() {
  test(
    'odczytuje home_id i alarm_id z danych Firebase',
    () {
      Map<String, dynamic> firebaseData = {
        'home_id': 'home_001',
        'alarm_id': '15',
        'alarm_type': 'sos',
      };

      AlarmNotificationTarget? notificationTarget =
          AlarmNotificationTarget.fromFirebaseData(
        firebaseData,
      );

      expect(
        notificationTarget,
        isNotNull,
      );

      expect(
        notificationTarget!.homeId,
        'home_001',
      );

      expect(
        notificationTarget.alarmId,
        15,
      );
    },
  );

  test(
    'odrzuca powiadomienie bez identyfikatora alarmu',
    () {
      Map<String, dynamic> firebaseData = {
        'home_id': 'home_001',
      };

      AlarmNotificationTarget? notificationTarget =
          AlarmNotificationTarget.fromFirebaseData(
        firebaseData,
      );

      expect(
        notificationTarget,
        isNull,
      );
    },
  );
}
