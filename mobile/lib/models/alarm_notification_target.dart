import 'home.dart';

class AlarmNotificationTarget {
  const AlarmNotificationTarget({
    required this.homeId,
    required this.alarmId,
  });

  final String homeId;
  final int alarmId;

  static AlarmNotificationTarget? fromFirebaseData(
    Map<String, dynamic> firebaseData,
  ) {
    String homeId = '';

    dynamic homeIdValue =
        firebaseData['home_id'];

    if (homeIdValue is String) {
      homeId = homeIdValue.trim();
    }

    dynamic alarmIdValue =
        firebaseData['alarm_id'];

    int? alarmId;

    if (alarmIdValue is int) {
      alarmId = alarmIdValue;
    }

    if (alarmIdValue is String) {
      final digits = alarmIdValue.trim();
      if (RegExp(r'^[0-9]+$').hasMatch(digits)) {
        alarmId = int.tryParse(digits);
      }
    }

    if (homeId.isEmpty) {
      return null;
    }

    if (alarmId == null || alarmId <= 0) {
      return null;
    }

    return AlarmNotificationTarget(
      homeId: homeId,
      alarmId: alarmId,
    );
  }

  // Client-side membership check; server-side JWT checks are still required.
  Home? accessibleHome(Iterable<Home> homes) {
    for (final home in homes) {
      if (home.id == homeId) {
        return home;
      }
    }
    return null;
  }
}
