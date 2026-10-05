import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

class VedaSentioPushNotificationService {
  Future<bool> registerCurrentMobileDevice(
    AuthService authService,
  ) async {
    bool mobilePlatformIsSupported =
        _isSupportedMobilePlatform();

    if (!mobilePlatformIsSupported) {
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging firebaseMessaging =
          FirebaseMessaging.instance;

      NotificationSettings notificationSettings =
          await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.denied) {
        return false;
      }

      String? firebaseCloudMessagingToken =
          await firebaseMessaging.getToken();

      if (firebaseCloudMessagingToken == null) {
        return false;
      }

      if (firebaseCloudMessagingToken.isEmpty) {
        return false;
      }

      String mobilePlatformName =
          _getMobilePlatformName();

      await authService.registerMobilePushNotificationToken(
        firebaseCloudMessagingToken,
        mobilePlatformName,
      );

      debugPrint(
        '[PUSH] Urządzenie mobilne zostało zarejestrowane.',
      );

      return true;
    } catch (error) {
      debugPrint(
        '[PUSH] Nie udało się zarejestrować urządzenia: $error',
      );

      return false;
    }
  }

  bool _isSupportedMobilePlatform() {
    if (kIsWeb) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }

    return false;
  }

  String _getMobilePlatformName() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }

    return 'unsupported';
  }
}
