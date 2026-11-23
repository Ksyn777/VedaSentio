import '../models/alarm.dart';
import '../models/device.dart';
import '../models/home.dart';
import '../models/home_details_data.dart';
import '../models/sensor_event.dart';
import '../models/session_data.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'token_storage.dart';

class AuthService {
  AuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _api = apiClient ?? ApiClient(),
        _tokens = tokenStorage ?? TokenStorage();

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<SessionData> login(
    String email,
    String password,
  ) async {
    final login = await _api.post(
      '/api/auth/login',
      {
        'email': email.trim(),
        'password': password,
      },
    );

    final token = login['access_token'];

    if (token is! String ||
        token.isEmpty) {
      throw const ApiException(
        'Brak tokena dostępu.',
      );
    }

    await _tokens.save(token);

    try {
      return await _load(token);
    } catch (_) {
      await _tokens.clear();
      rethrow;
    }
  }

  Future<SessionData?> restore() async {
    final token =
        await _tokens.read();

    if (token == null ||
        token.isEmpty) {
      return null;
    }

    try {
      return await _load(token);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokens.clear();
        return null;
      }

      rethrow;
    }
  }

  Future<HomeDetailsData> loadHomeDetails(
    String homeId, {
    int eventLimit = 20,
    int alarmHistoryLimit = 20,
  }) async {
    final token = await _requireToken();

    try {
      final devicesRaw =
          await _api.getList(
        '/api/homes/$homeId/devices',
        token,
      );

      final eventsRaw =
          await _api.getList(
        '/api/homes/$homeId/events?limit=$eventLimit',
        token,
      );

      final activeAlarmsRaw =
          await _api.getList(
        '/api/homes/$homeId/alarms?active=true',
        token,
      );

      final alarmHistoryRaw =
          await _api.getList(
        '/api/homes/$homeId/alarms?limit=$alarmHistoryLimit',
        token,
      );

      final devices = devicesRaw
          .whereType<
              Map<String, dynamic>>()
          .map(Device.fromJson)
          .toList(growable: false);

      final events = eventsRaw
          .whereType<
              Map<String, dynamic>>()
          .map(SensorEvent.fromJson)
          .toList(growable: false);

      final activeAlarms =
          activeAlarmsRaw
              .whereType<
                  Map<String, dynamic>>()
              .map(Alarm.fromJson)
              .toList(growable: false);

      final alarmHistory =
          alarmHistoryRaw
              .whereType<
                  Map<String, dynamic>>()
              .map(Alarm.fromJson)
              .toList(growable: false);

      final List<
          MapEntry<
              String,
              SensorEvent?>> latestEntries =
          await Future.wait<
              MapEntry<
                  String,
                  SensorEvent?>>(
        devices.map<
            Future<
                MapEntry<
                    String,
                    SensorEvent?>>>(
          (device) async {
            try {
              final latestJson =
                  await _api.getObject(
                '/api/homes/$homeId/devices/${device.id}/latest',
                token,
              );

              return MapEntry<
                  String,
                  SensorEvent?>(
                device.id,
                SensorEvent.fromJson(
                  latestJson,
                ),
              );
            } on ApiException catch (error) {
              if (error.statusCode ==
                  404) {
                return MapEntry<
                    String,
                    SensorEvent?>(
                  device.id,
                  null,
                );
              }

              rethrow;
            }
          },
        ),
      );

      return HomeDetailsData(
        devices: devices,
        recentEvents: events,
        latestEventsByDevice:
            Map<
                String,
                SensorEvent?>.fromEntries(
          latestEntries,
        ),
        activeAlarms: activeAlarms,
        alarmHistory: alarmHistory,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokens.clear();
      }

      rethrow;
    }
  }

  Future<List<SensorEvent>> loadHomeEvents(
    String homeId, {
    int limit = 50,
  }) async {
    final token = await _requireToken();

    try {
      final eventsRaw = await _api.getList(
        '/api/homes/$homeId/events?limit=$limit',
        token,
      );

      return eventsRaw
          .whereType<Map<String, dynamic>>()
          .map(SensorEvent.fromJson)
          .toList(growable: false);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokens.clear();
      }

      rethrow;
    }
  }

  Future<List<Alarm>> loadHomeAlarms(
    String homeId, {
    int limit = 50,
  }) async {
    final token = await _requireToken();

    try {
      final alarmsRaw = await _api.getList(
        '/api/homes/$homeId/alarms?limit=$limit',
        token,
      );

      return alarmsRaw
          .whereType<Map<String, dynamic>>()
          .map(Alarm.fromJson)
          .toList(growable: false);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokens.clear();
      }

      rethrow;
    }
  }

  Future<Alarm> acknowledgeAlarm({
    required String homeId,
    required int alarmId,
  }) async {
    final token = await _requireToken();

    try {
      final response =
          await _api.postAuthorized(
        '/api/homes/$homeId/alarms/$alarmId/acknowledge',
        token,
      );

      return Alarm.fromJson(response);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokens.clear();
      }

      rethrow;
    }
  }


  Future<void> registerMobilePushNotificationToken(
    String firebaseCloudMessagingToken,
    String mobilePlatformName,
  ) async {
    final accessToken = await _requireToken();

    try {
      await _api.postAuthorized(
        '/api/mobile-devices/push-token',
        accessToken,
        body: {
          'fcm_token': firebaseCloudMessagingToken,
          'platform': mobilePlatformName,
        },
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokens.clear();
      }
      rethrow;
    }
  }

  Future<void> unregisterMobilePushNotificationToken(
    String firebaseCloudMessagingToken,
  ) async {
    final accessToken = await _requireToken();

    try {
      final response = await _api.deleteAuthorized(
        '/api/mobile-devices/push-token',
        accessToken,
        body: {'fcm_token': firebaseCloudMessagingToken},
      );
      if (response['status'] != 'unregistered') {
        throw const ApiException(
          'Serwer nie potwierdził wyrejestrowania urządzenia.',
        );
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _tokens.clear();
      }
      rethrow;
    }
  }

  Future<void> logout() =>
      _tokens.clear();

  Future<String> _requireToken() async {
    final token =
        await _tokens.read();

    if (token == null ||
        token.isEmpty) {
      throw const ApiException(
        'Sesja wygasła. Zaloguj się ponownie.',
        statusCode: 401,
      );
    }

    return token;
  }

  Future<SessionData> _load(
    String token,
  ) async {
    final me = UserProfile.fromJson(
      await _api.getObject(
        '/api/me',
        token,
      ),
    );

    final homesRaw =
        await _api.getList(
      '/api/homes',
      token,
    );

    final homes = homesRaw
        .whereType<
            Map<String, dynamic>>()
        .map(Home.fromJson)
        .toList(growable: false);

    return SessionData(
      user: me,
      homes: homes,
    );
  }

  void dispose() => _api.close();
}
