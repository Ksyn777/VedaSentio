import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/alarm_notification_target.dart';
import 'auth_service.dart';
import 'push_token_registration.dart';

class VedaSentioPushNotificationService {
  StreamSubscription<RemoteMessage>?
      _notificationOpenedSubscription;

  Future<void> startAlarmNotificationOpenHandling(
    void Function(
      AlarmNotificationTarget notificationTarget,
    ) handleAlarmNotificationOpened,
  ) async {
    bool mobilePlatformIsSupported =
        _isSupportedMobilePlatform();

    if (!mobilePlatformIsSupported) {
      return;
    }

    try {
      await _initializeFirebaseIfNeeded();

      _notificationOpenedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage firebaseMessage) {
          AlarmNotificationTarget?
              notificationTarget =
              AlarmNotificationTarget.fromFirebaseData(
            firebaseMessage.data,
          );

          if (notificationTarget == null) {
            debugPrint(
              '[PUSH] Powiadomienie nie zawiera home_id lub alarm_id.',
            );
            return;
          }

          handleAlarmNotificationOpened(
            notificationTarget,
          );
        },
      );

      RemoteMessage? initialFirebaseMessage =
          await FirebaseMessaging.instance
              .getInitialMessage();

      if (initialFirebaseMessage == null) {
        return;
      }

      AlarmNotificationTarget?
          initialNotificationTarget =
          AlarmNotificationTarget.fromFirebaseData(
        initialFirebaseMessage.data,
      );

      if (initialNotificationTarget == null) {
        debugPrint(
          '[PUSH] Początkowe powiadomienie nie zawiera home_id lub alarm_id.',
        );
        return;
      }

      handleAlarmNotificationOpened(
        initialNotificationTarget,
      );
    } catch (error) {
      debugPrint(
        '[PUSH] Nie udało się uruchomić obsługi kliknięcia powiadomienia: $error',
      );
    }
  }

  Future<bool> registerCurrentMobileDevice(
    AuthService authService,
  ) async {
    bool mobilePlatformIsSupported =
        _isSupportedMobilePlatform();

    if (!mobilePlatformIsSupported) {
      return false;
    }

    try {
      await _initializeFirebaseIfNeeded();

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

      final registered = await PushTokenRegistration.register(
        auth: authService,
        fcmToken: firebaseCloudMessagingToken,
        platform: _getMobilePlatformName(),
      );

      if (registered) {
        debugPrint('[PUSH] Urządzenie mobilne zostało zarejestrowane.');
      }
      return registered;
    } catch (error) {
      debugPrint(
        '[PUSH] Nie udało się zarejestrować urządzenia: $error',
      );

      return false;
    }
  }

  Future<void> _initializeFirebaseIfNeeded() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    await Firebase.initializeApp();
  }

  bool _isSupportedMobilePlatform() {
    if (kIsWeb) {
      return false;
    }

    if (defaultTargetPlatform ==
        TargetPlatform.android) {
      return true;
    }

    if (defaultTargetPlatform ==
        TargetPlatform.iOS) {
      return true;
    }

    return false;
  }

  String _getMobilePlatformName() {
    if (defaultTargetPlatform ==
        TargetPlatform.android) {
      return 'android';
    }

    if (defaultTargetPlatform ==
        TargetPlatform.iOS) {
      return 'ios';
    }

    return 'unsupported';
  }

  void dispose() {
    _notificationOpenedSubscription
        ?.cancel();
  }
}
