import 'auth_service.dart';

/// Testable bridge between the mobile FCM token and the protected API.
/// It never starts Firebase or logs FCM credentials.
class PushTokenRegistration {
  const PushTokenRegistration._();

  static Future<bool> register({
    required AuthService auth,
    required String? fcmToken,
    required String platform,
  }) async {
    if (platform != 'android' && platform != 'ios') {
      return false;
    }

    final token = fcmToken?.trim();
    if (token == null || token.isEmpty) {
      return false;
    }

    await auth.registerMobilePushNotificationToken(token, platform);
    return true;
  }
}
