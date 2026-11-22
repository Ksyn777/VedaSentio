import 'home.dart';

class AlarmNotificationTarget {
  const AlarmNotificationTarget({
    required this.homeId,
    required this.alarmId,
  });

  final String homeId;
  final int alarmId;

  static final RegExp _decimalDigits = RegExp(r'^[0-9]+$');

  static AlarmNotificationTarget? fromFirebaseData(
    Map<String, dynamic> firebaseData,
  ) {
    final rawHomeId = firebaseData['home_id'];
    final homeId = rawHomeId is String ? rawHomeId.trim() : '';

    final rawAlarmId = firebaseData['alarm_id'];
    int? alarmId;
    if (rawAlarmId is int) {
      alarmId = rawAlarmId;
    } else if (rawAlarmId is String &&
        _decimalDigits.hasMatch(rawAlarmId)) {
      alarmId = int.tryParse(rawAlarmId);
    }

    // Refuse malformed navigation targets before reaching the API.
    if (homeId.isEmpty ||
        homeId.length > 128 ||
        homeId.contains('/') ||
        homeId.contains(r'\') ||
        homeId.codeUnits.any((code) => code < 32 || code == 127) ||
        alarmId == null ||
        alarmId <= 0) {
      return null;
    }

    return AlarmNotificationTarget(
      homeId: homeId,
      alarmId: alarmId,
    );
  }

  /// A notification never grants access to a home by itself.
  Home? findAccessibleHome(Iterable<Home> homes) {
    for (final home in homes) {
      if (home.id == homeId) {
        return home;
      }
    }
    return null;
  }
}
