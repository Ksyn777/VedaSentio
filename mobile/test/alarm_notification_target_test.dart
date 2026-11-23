import 'package:vedasentio_mobile/models/home.dart';
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
  test('accepts numeric positive alarm ID and trimmed home ID', () {
    final target = AlarmNotificationTarget.fromFirebaseData({
      'home_id': ' home_test ',
      'alarm_id': 17,
    });
    expect(target?.homeId, 'home_test');
    expect(target?.alarmId, 17);
  });

  test('rejects invalid alarm IDs without throwing', () {
    for (final invalid in [
      null,
      0,
      -2,
      3.5,
      '',
      '0',
      '-1',
      '12abc',
      '1.0',
      ' 12',
      '+12',
      '99999999999999999999999999999999999',
    ]) {
      expect(
        AlarmNotificationTarget.fromFirebaseData({
          'home_id': 'home_ci',
          'alarm_id': invalid,
        }),
        isNull,
        reason: 'Invalid ID: $invalid',
      );
    }
  });

  test('rejects malformed home IDs and unsafe path separators', () {
    for (final invalid in [
      '',
      ' ',
      'home/other',
      r'home\other',
      'home\nother',
      'x' * 129,
      15,
    ]) {
      expect(
        AlarmNotificationTarget.fromFirebaseData({
          'home_id': invalid,
          'alarm_id': '5',
        }),
        isNull,
        reason: 'Invalid home: $invalid',
      );
    }
  });

  test('only a home in the active session can be opened', () {
    final target = AlarmNotificationTarget.fromFirebaseData({
      'home_id': 'home_b',
      'alarm_id': '5',
    })!;
    const homes = [
      Home(id: 'home_a', name: 'A', role: 'viewer', createdAt: ''),
      Home(id: 'home_b', name: 'B', role: 'caregiver', createdAt: ''),
    ];
    expect(target.findAccessibleHome(homes)?.id, 'home_b');
    expect(target.findAccessibleHome([homes.first]), isNull);
    expect(target.findAccessibleHome(const <Home>[]), isNull);
  });

}
