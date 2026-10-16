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
      alarmId = int.tryParse(
        alarmIdValue,
      );
    }

    if (homeId.isEmpty) {
      return null;
    }

    if (alarmId == null) {
      return null;
    }

    return AlarmNotificationTarget(
      homeId: homeId,
      alarmId: alarmId,
    );
  }
}
