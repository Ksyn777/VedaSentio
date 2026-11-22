import 'package:flutter_test/flutter_test.dart';
import 'package:vedasentio_mobile/models/alarm_notification_target.dart';
import 'package:vedasentio_mobile/models/home.dart';

const allowed = Home(
  id: 'home_ci',
  name: 'Dom testowy',
  role: 'caregiver',
  createdAt: '2026-11-22T00:00:00Z',
);
const other = Home(
  id: 'home_else',
  name: 'Inny dom',
  role: 'viewer',
  createdAt: '2026-11-22T00:00:00Z',
);

void main() {
  test('FCM string identifier targets the correct alarm and accessible home',
      () {
    final target = AlarmNotificationTarget.fromFirebaseData({
      'home_id': ' home_ci ',
      'alarm_id': '31',
      'alarm_type': 'sos',
    });

    expect(target, isNotNull);
    expect(target!.homeId, 'home_ci');
    expect(target.alarmId, 31);
    expect(target.accessibleHome([other, allowed]), same(allowed));
    expect(target.accessibleHome([other]), isNull);
  });

  test('FCM integer ID and whitespace-surrounded decimal string are valid',
      () {
    expect(
      AlarmNotificationTarget.fromFirebaseData({
        'home_id': 'home_ci',
        'alarm_id': 2,
      })?.alarmId,
      2,
    );
    expect(
      AlarmNotificationTarget.fromFirebaseData({
        'home_id': 'home_ci',
        'alarm_id': ' 00023 ',
      })?.alarmId,
      23,
    );
  });

  test('missing, blank and wrong-type home_id are ignored', () {
    for (final value in [null, '', '  ', 123, true, <String>[]]) {
      expect(
        AlarmNotificationTarget.fromFirebaseData({
          'home_id': value,
          'alarm_id': '15',
        }),
        isNull,
      );
    }
  });

  test('alarm ID must be a positive, finite decimal integer', () {
    for (final value in [
      null,
      '',
      '  ',
      '0',
      0,
      -1,
      '-2',
      '+3',
      '1abc',
      '5.0',
      1.5,
      true,
      '9999999999999999999999999999999999999',
    ]) {
      expect(
        AlarmNotificationTarget.fromFirebaseData({
          'home_id': 'home_ci',
          'alarm_id': value,
        }),
        isNull,
        reason: 'Unexpected accepted alarm identifier: $value',
      );
    }
  });

  test('notification cannot be routed to a home outside the session', () {
    final target = AlarmNotificationTarget.fromFirebaseData({
      'home_id': 'private_other_home',
      'alarm_id': '81',
    });
    expect(target, isNotNull);
    expect(target!.accessibleHome([allowed, other]), isNull);
  });

  test('alarm from viewer home may open for read-only details', () {
    final target = AlarmNotificationTarget.fromFirebaseData({
      'home_id': other.id,
      'alarm_id': '81',
    });
    expect(target!.accessibleHome([other, allowed]), same(other));
  });
}
