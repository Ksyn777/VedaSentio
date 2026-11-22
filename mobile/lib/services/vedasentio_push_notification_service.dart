import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/alarm_notification_target.dart';
import 'auth_service.dart';
import 'push_token_registration_coordinator.dart';

class VedaSentioPushNotificationService {
  StreamSubscription<RemoteMessage>?
      _notificationOpenedSubscription;
  PushTokenRegistrationCoordinator? _tokenRegistration;
  int _registrationGeneration = 0;
  final Set<String> _registeredTokens = <String>{};

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
    } catch (_) {
      debugPrint(
        '[PUSH] Nie udało się uruchomić obsługi kliknięcia powiadomienia.',
      );
    }
  }

  Future<bool> registerCurrentMobileDevice(
    AuthService authService,
  ) async {
    // A previous session must never own this account's token refresh stream.
    stopMobileTokenRegistration();
    final generation = _registrationGeneration;

    if (!_isSupportedMobilePlatform()) {
      return false;
    }

    try {
      await _initializeFirebaseIfNeeded();
      if (generation != _registrationGeneration) {
        return false;
      }

      final firebaseMessaging = FirebaseMessaging.instance;
      final settings = await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (generation != _registrationGeneration ||
          settings.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }

      final currentToken = await firebaseMessaging.getToken();
      if (generation != _registrationGeneration ||
          currentToken == null ||
          currentToken.trim().isEmpty) {
        return false;
      }

      final platform = _getMobilePlatformName();
      final registration = PushTokenRegistrationCoordinator(
        (token) async {
          await authService.registerMobilePushNotificationToken(
            token,
            platform,
          );
          // A completed registration may race with logout. Keep every
          // token registered during this session until the backend confirms
          // its revocation, including old tokens after rotation.
          _registeredTokens.add(token);
        },
        onStreamError: () {
          debugPrint('[PUSH] Nie udało się odczytać nowego tokena FCM.');
        },
      );
      _tokenRegistration = registration;
      registration.start(firebaseMessaging.onTokenRefresh);

      final succeeded = await registration.register(currentToken);
      if (succeeded) {
        debugPrint('[PUSH] Urządzenie mobilne zostało zarejestrowane.');
      } else {
        debugPrint('[PUSH] Rejestracja urządzenia nie powiodła się.');
      }
      return succeeded;
    } catch (_) {
      debugPrint('[PUSH] Nie udało się zarejestrować urządzenia.');
      return false;
    }
  }

  void stopMobileTokenRegistration() {
    _registrationGeneration++;
    _tokenRegistration?.stop();
    _tokenRegistration = null;
  }

  /// Returns true only if the backend confirmed revocation of every
  /// successfully registered token from this session.
  ///
  /// Stops refreshes and waits for in-flight HTTP registrations before
  /// revoking, so a late registration cannot overwrite a successful logout.
  Future<bool> unregisterCurrentMobileDeviceForLogout(
    AuthService authService,
  ) async {
    final previousRegistration = _tokenRegistration;
    stopMobileTokenRegistration();
    if (previousRegistration != null) {
      await previousRegistration.idle;
    }

    var allRevoked = true;
    for (final token in _registeredTokens.toList()) {
      try {
        await authService.unregisterMobilePushNotificationToken(token);
        _registeredTokens.remove(token);
      } catch (_) {
        allRevoked = false;
      }
    }
    return allRevoked;
  }

  /// Called only after local logout. Failed tokens must not be retried
  /// under the JWT of another account.
  void clearRegisteredTokenHistory() {
    _registeredTokens.clear();
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
    stopMobileTokenRegistration();
    clearRegisteredTokenHistory();
    final subscription = _notificationOpenedSubscription;
    _notificationOpenedSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
