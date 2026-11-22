import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../models/device.dart';
import '../models/home.dart';
import '../models/home_details_data.dart';
import '../models/home_safety_status.dart';
import '../models/sensor_event.dart';
import '../services/alarm_status_service.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/date_time_formatter.dart';

class HomeDetailsScreen
    extends StatefulWidget {
  const HomeDetailsScreen({
    required this.home,
    required this.authService,
    required this.onSessionExpired,
    this.openedAlarmId,
    super.key,
  });

  final Home home;
  final AuthService authService;
  final Future<void> Function()
      onSessionExpired;
  final int? openedAlarmId;

  @override
  State<HomeDetailsScreen> createState() =>
      _HomeDetailsScreenState();
}

class _HomeDetailsScreenState
    extends State<HomeDetailsScreen> {
  static const Duration
      _autoRefreshInterval =
      Duration(seconds: 3);

  HomeDetailsData? _data;
  Timer? _autoRefreshTimer;

  bool _loading = true;
  bool _refreshInProgress = false;
  Future<void>? _ongoingLoad;
  int? _acknowledgingAlarmId;
  String? _errorMessage;
  DateTime? _lastUpdatedAt;

  bool get _canManageAlarms =>
      widget.home.role == 'owner' ||
      widget.home.role == 'caregiver';

  @override
  void initState() {
    super.initState();

    _load(showLoading: true);

    _autoRefreshTimer =
        Timer.periodic(
      _autoRefreshInterval,
      (_) => _load(
        showLoading: false,
      ),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({
    required bool showLoading,
  }) {
    final running = _ongoingLoad;
    if (running != null) {
      return running;
    }

    final request = _fetchHomeDetails(showLoading: showLoading);
    final tracked = request.whenComplete(() {
      _ongoingLoad = null;
    });
    _ongoingLoad = tracked;
    return tracked;
  }

  Future<void> _fetchHomeDetails({
    required bool showLoading,
  }) async {
    _refreshInProgress = true;

    if (mounted && showLoading) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final data =
          await widget.authService
              .loadHomeDetails(
        widget.home.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _data = data;
        _loading = false;
        _errorMessage = null;
        _lastUpdatedAt =
            DateTime.now();
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget
            .onSessionExpired();

        if (!mounted) {
          return;
        }

        Navigator.of(context)
            .popUntil(
          (route) => route.isFirst,
        );

        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            error.isForbidden
                ? 'Nie masz dostępu do tego gospodarstwa.'
                : error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Nie udało się pobrać danych gospodarstwa.';
        _loading = false;
      });
    } finally {
      _refreshInProgress = false;
    }
  }

  Future<void> _manualRefresh() {
    return _load(
      showLoading: _data == null,
    );
  }

  Future<void> _acknowledge(
    Alarm alarm,
  ) async {
    if (!_canManageAlarms ||
        alarm.status != 'active' ||
        _acknowledgingAlarmId != null) {
      return;
    }

    setState(() {
      _acknowledgingAlarmId =
          alarm.id;
    });

    try {
      await widget.authService
          .acknowledgeAlarm(
        homeId: widget.home.id,
        alarmId: alarm.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Alarm został potwierdzony.',
          ),
        ),
      );

      // A refresh started before the POST may return the old 'active'
      // alarm. Wait for it, then force a fresh read after the mutation.
      final running = _ongoingLoad;
      if (running != null) {
        await running;
      }
      if (!mounted) {
        return;
      }

      await _load(
        showLoading: false,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget
            .onSessionExpired();

        if (!mounted) {
          return;
        }

        Navigator.of(context)
            .popUntil(
          (route) => route.isFirst,
        );

        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.isForbidden
                ? 'Nie masz uprawnień do potwierdzania alarmów.'
                : error.message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _acknowledgingAlarmId =
              null;
        });
      }
    }
  }

  String _lastUpdatedLabel() {
    final value = _lastUpdatedAt;

    if (value == null) {
      return 'oczekiwanie na dane';
    }

    String twoDigits(int number) =>
        number
            .toString()
            .padLeft(2, '0');

    return '${twoDigits(value.hour)}:'
        '${twoDigits(value.minute)}:'
        '${twoDigits(value.second)}';
  }

  IconData _deviceIcon(
    Device device,
  ) {
    return switch (
        device.deviceType) {
      'sos_button' =>
        Icons.sos_outlined,
      'door_contact' =>
        Icons.door_front_door_outlined,
      'smoke_detector' =>
        Icons.smoke_free_outlined,
      'co_detector' =>
        Icons.air_outlined,
      'gas_detector' =>
        Icons.gas_meter_outlined,
      'flood_sensor' =>
        Icons.water_drop_outlined,
      _ => Icons.sensors_outlined,
    };
  }

  IconData _eventIcon(
    SensorEvent event,
  ) {
    return switch (
        event.eventType) {
      'sos_pressed' => Icons.sos,
      'sos_resolved' =>
        Icons.check_circle_outline,
      'door_opened' =>
        Icons.door_front_door_outlined,
      'door_closed' =>
        Icons.door_back_door_outlined,
      'smoke_detected' =>
        Icons.warning_amber_outlined,
      'smoke_cleared' =>
        Icons.check_circle_outline,
      'co_detected' =>
        Icons.warning_amber_outlined,
      'co_cleared' =>
        Icons.check_circle_outline,
      'gas_detected' =>
        Icons.warning_amber_outlined,
      'gas_cleared' =>
        Icons.check_circle_outline,
      'flood_detected' =>
        Icons.water_drop_outlined,
      'flood_cleared' =>
        Icons.check_circle_outline,
      _ =>
        Icons.notifications_none_outlined,
    };
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8EF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'VedaSentio',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Odśwież teraz',
            onPressed: _refreshInProgress
                ? null
                : _manualRefresh,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _manualRefresh,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
  ) {
    if (_loading && _data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 320,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null && _data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(
            height: 80,
          ),
          Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 16,
          ),
          Center(
            child: FilledButton.icon(
              onPressed: _manualRefresh,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Spróbuj ponownie',
              ),
            ),
          ),
        ],
      );
    }

    final data = _data!;

    final activeDeviceCount = data.devices.where((device) => device.isActive).length;
    final onlineCount = data.devices
        .where((device) => device.isActive && device.isOnline)
        .length;

    final offlineDeviceCount = activeDeviceCount - onlineCount;

    final safetyStatus = AlarmStatusService.fromBackendAlarms(
      data.activeAlarms,
    );

    final resolvedAlarms = data.alarmHistory
        .where(
          (alarm) => alarm.isResolved,
        )
        .toList(
          growable: false,
        );

    Alarm? openedAlarm;

    if (widget.openedAlarmId != null) {
      for (Alarm alarm in data.activeAlarms) {
        if (alarm.id == widget.openedAlarmId) {
          openedAlarm = alarm;
          break;
        }
      }

      if (openedAlarm == null) {
        for (Alarm alarm in data.alarmHistory) {
          if (alarm.id == widget.openedAlarmId) {
            openedAlarm = alarm;
            break;
          }
        }
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        Text(
          widget.home.name,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A2A24),
              ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          'Bezpieczeństwo i monitoring domu w jednym miejscu.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF776A63),
              ),
        ),
        const SizedBox(
          height: 18,
        ),
        _SafetyStatusCard(
          status: safetyStatus,
          activeAlarmCount: data.activeAlarms.length,
          offlineDeviceCount: offlineDeviceCount,
          hasActiveDevices: activeDeviceCount > 0,
          isStale: _errorMessage != null,
        ),
        const SizedBox(
          height: 14,
        ),
        _LiveMonitoringCard(
          lastUpdatedLabel: _lastUpdatedLabel(),
          refreshSeconds: _autoRefreshInterval.inSeconds,
          isStale: _errorMessage != null,
          isInactive: activeDeviceCount == 0,
        ),
        const SizedBox(
          height: 14,
        ),
        _HomeSummaryCard(
          homeName: widget.home.name,
          role: widget.home.role,
          onlineCount: onlineCount,
          deviceCount: activeDeviceCount,
          offlineDeviceCount: offlineDeviceCount,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(
            height: 12,
          ),
          _InlineError(
            message: _errorMessage!,
          ),
        ],
        if (widget.openedAlarmId != null) ...[
          const SizedBox(
            height: 24,
          ),
          const _SectionTitle(
            title: 'Alarm z powiadomienia',
          ),
          const SizedBox(
            height: 10,
          ),
          if (openedAlarm == null)
            _SimpleInfoCard(
              icon: Icons.notifications_active_outlined,
              title: 'Alarm ID ${widget.openedAlarmId}',
              subtitle:
                  'Alarm nie znajduje się już w pobranej historii. Odśwież dane, aby sprawdzić aktualny stan.',
            )
          else if (!openedAlarm.isResolved)
            _AlarmCard(
              alarm: openedAlarm,
              canAcknowledge: _canManageAlarms &&
                  openedAlarm.status == 'active',
              acknowledging: _acknowledgingAlarmId == openedAlarm.id,
              onAcknowledge: () => _acknowledge(
                openedAlarm!,
              ),
            )
          else
            _AlarmHistoryCard(
              alarm: openedAlarm,
            ),
        ],
        const SizedBox(
          height: 26,
        ),
        const _SectionTitle(
          title: 'Aktywne alarmy',
        ),
        const SizedBox(
          height: 10,
        ),
        if (data.activeAlarms.isEmpty)
          _SimpleInfoCard(
            icon: Icons.verified_user_outlined,
            title: 'Brak aktywnych alarmów',
            subtitle: _errorMessage != null
                ? 'Brak alarmów w ostatnich danych. Nie można potwierdzić obecnego stanu.'
                : activeDeviceCount == 0
                    ? 'Bez aktywnych czujników nie można potwierdzić stanu domu.'
                    : 'W ostatnim odczycie API nie ma aktywnych alarmów.',
          )
        else
          ...data.activeAlarms.map(
            (alarm) => Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _AlarmCard(
                alarm: alarm,
                canAcknowledge: _canManageAlarms &&
                    alarm.status == 'active',
                acknowledging: _acknowledgingAlarmId == alarm.id,
                onAcknowledge: () => _acknowledge(
                  alarm,
                ),
              ),
            ),
          ),
        const SizedBox(
          height: 22,
        ),
        const _SectionTitle(
          title: 'Urządzenia',
        ),
        const SizedBox(
          height: 10,
        ),
        if (data.devices.isEmpty)
          const _SimpleInfoCard(
            icon: Icons.sensors_off_outlined,
            title: 'Brak urządzeń',
            subtitle: 'Do tego domu nie przypisano jeszcze urządzeń.',
          )
        else
          ...data.devices.map(
            (device) {
              final latest = data.latestEventsByDevice[device.id];

              String statusText;

              if (!device.isActive) {
                statusText = 'Urządzenie nieaktywne';
              } else if (!device.isOnline) {
                statusText = 'Offline';
              } else if (latest == null) {
                statusText = 'Online • brak zapisanych zdarzeń';
              } else {
                statusText = 'Online • ${latest.displayType}';
              }

              String lastSeenText = 'Brak kontaktu z urządzeniem';

              if (device.lastSeenAt != null &&
                  device.lastSeenAt!.isNotEmpty) {
                lastSeenText =
                    'Ostatni kontakt: ${DateTimeFormatter.compact(device.lastSeenAt!)}';
              }

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: _DeviceCard(
                  icon: _deviceIcon(device),
                  name: device.name.isEmpty
                      ? device.displayType
                      : device.name,
                  deviceId: device.id,
                  statusText: statusText,
                  lastSeenText: lastSeenText,
                  isActive: device.isActive,
                  isOnline: device.isOnline,
                ),
              );
            },
          ),
        const SizedBox(
          height: 22,
        ),
        const _SectionTitle(
          title: 'Historia alarmów',
        ),
        const SizedBox(
          height: 10,
        ),
        if (resolvedAlarms.isEmpty)
          const _SimpleInfoCard(
            icon: Icons.history,
            title: 'Brak zakończonych alarmów',
            subtitle: 'Historia pojawi się po zakończeniu pierwszego alarmu.',
          )
        else
          ...resolvedAlarms.map(
            (alarm) => Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _AlarmHistoryCard(
                alarm: alarm,
              ),
            ),
          ),
        const SizedBox(
          height: 22,
        ),
        const _SectionTitle(
          title: 'Ostatnia aktywność',
        ),
        const SizedBox(
          height: 10,
        ),
        if (data.recentEvents.isEmpty)
          const _SimpleInfoCard(
            icon: Icons.history_toggle_off_outlined,
            title: 'Brak zapisanych zdarzeń',
            subtitle: 'Zdarzenia z urządzeń pojawią się w tym miejscu.',
          )
        else
          ...data.recentEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _EventCard(
                icon: _eventIcon(event),
                title: event.displayType,
                deviceId: event.deviceId,
                receivedAt: DateTimeFormatter.compact(event.receivedAt),
                value: event.displayValue,
              ),
            ),
          ),
      ],
    );
  }
}

class _SafetyStatusCard extends StatelessWidget {
  const _SafetyStatusCard({
    required this.status,
    required this.activeAlarmCount,
    required this.offlineDeviceCount,
    required this.hasActiveDevices,
    required this.isStale,
  });

  final HomeSafetyStatus status;
  final int activeAlarmCount;
  final int offlineDeviceCount;
  final bool hasActiveDevices;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final hasAlarm = status.level == SafetyLevel.alarm;
    final hasWarning = status.level == SafetyLevel.warning ||
        offlineDeviceCount > 0;
    final unknown = isStale || !hasActiveDevices;

    // An unmonitored or disconnected home cannot be confirmed safe.
    final String title;
    final String message;
    if (hasAlarm) {
      title = isStale ? 'ALARM — dane nieaktualne' : 'ALARM';
      message = isStale
          ? status.message + ' Brak bieżącego połączenia z serwerem.'
          : status.message;
    } else if (isStale) {
      title = 'Stan niepotwierdzony';
      message = 'Ostatni odczyt jest nieaktualny. '
          'Nie można potwierdzić obecnego stanu domu.';
    } else if (!hasActiveDevices) {
      title = 'Monitoring nieaktywny';
      message = 'Brak aktywnych czujników. '
          'System nie może jeszcze potwierdzać bezpieczeństwa domu.';
    } else if (hasWarning) {
      title = 'Wymagana uwaga';
      message = offlineDeviceCount > 0 && status.level == SafetyLevel.safe
          ? 'Nie wszystkie aktywne urządzenia odpowiadają. '
              'Sprawdź połączenie lub zasilanie.'
          : status.message;
    } else {
      title = 'Brak aktywnych alarmów';
      message = 'Ostatni odczyt API nie wykazał aktywnych alarmów.';
    }

    final Color accent;
    final Color tint;
    final IconData icon;
    if (hasAlarm) {
      accent = const Color(0xFFAD302D);
      tint = const Color(0xFFFBEDEA);
      icon = Icons.crisis_alert;
    } else if (unknown) {
      accent = const Color(0xFF52636B);
      tint = const Color(0xFFEDF0EF);
      icon = Icons.help_outline_rounded;
    } else if (hasWarning) {
      accent = const Color(0xFF936C31);
      tint = const Color(0xFFFBF0DA);
      icon = Icons.warning_amber_outlined;
    } else {
      accent = const Color(0xFF165D55);
      tint = const Color(0xFFE6F2EE);
      icon = Icons.verified_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDFE3E0)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STAN MONITORINGU',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  unknown ? 'NIEPOTWIERDZONY' : 'OSTATNI ODCZYT',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF202D31),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF57666A), height: 1.4),
          ),
          if (activeAlarmCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Aktywne alarmy: $activeAlarmCount',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveMonitoringCard extends StatelessWidget {
  const _LiveMonitoringCard({
    required this.lastUpdatedLabel,
    required this.refreshSeconds,
    required this.isStale,
    required this.isInactive,
  });

  final String lastUpdatedLabel;
  final int refreshSeconds;
  final bool isStale;
  final bool isInactive;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF0E7DF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isStale
                ? Icons.cloud_off_outlined
                : isInactive
                    ? Icons.sensors_off_outlined
                    : Icons.sync,
            size: 20,
            color: isStale || isInactive
                ? const Color(0xFF52636B)
                : const Color(0xFF165D55),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStale
                      ? 'Dane nieaktualne'
                      : isInactive
                          ? 'Brak aktywnych czujników'
                          : 'Monitoring na żywo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A2A24),
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  isStale
                      ? 'Nie można potwierdzić obecnego stanu • ostatnio $lastUpdatedLabel'
                      : isInactive
                          ? 'Odczyt API: $lastUpdatedLabel • brak aktywnego monitoringu'
                          : 'Odświeżanie co $refreshSeconds s • ostatnio $lastUpdatedLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7B6D64),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({
    required this.homeName,
    required this.role,
    required this.onlineCount,
    required this.deviceCount,
    required this.offlineDeviceCount,
  });

  final String homeName;
  final String role;
  final int onlineCount;
  final int deviceCount;
  final int offlineDeviceCount;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_outlined,
              size: 30,
              color: Color(0xFF356C9E),
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3A2A24),
                      ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  'Rola: $role',
                  style: const TextStyle(
                    color: Color(0xFF7B6D64),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    Icon(
                      offlineDeviceCount == 0
                          ? Icons.wifi
                          : Icons.wifi_off,
                      size: 17,
                      color: offlineDeviceCount == 0
                          ? const Color(0xFF2F8F4E)
                          : const Color(0xFFF28C28),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Flexible(
                      child: Text(
                        '$onlineCount z $deviceCount urządzeń online',
                        style: TextStyle(
                          color: offlineDeviceCount == 0
                              ? const Color(0xFF2F8F4E)
                              : const Color(0xFF9A5C13),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF3A2A24),
          ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.alarm,
    required this.canAcknowledge,
    required this.acknowledging,
    required this.onAcknowledge,
  });

  final Alarm alarm;
  final bool canAcknowledge;
  final bool acknowledging;
  final VoidCallback onAcknowledge;

  @override
  Widget build(
    BuildContext context,
  ) {
    final isCritical = alarm.isCritical;
    final accent = isCritical
        ? const Color(0xFFD92D20)
        : const Color(0xFFF28C28);
    final softBackground = isCritical
        ? const Color(0xFFFFF0EE)
        : const Color(0xFFFFF5E8);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: softBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCritical
                      ? Icons.crisis_alert
                      : Icons.warning_amber_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarm.typeLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF3A2A24),
                          ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${alarm.severityLabel} • ${alarm.deviceId}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  alarm.statusLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          _AlarmDetailRow(
            icon: Icons.schedule_outlined,
            text:
                'Rozpoczęto: ${DateTimeFormatter.compact(alarm.startedAt)}',
          ),
          if (alarm.isAcknowledged) ...[
            const SizedBox(
              height: 7,
            ),
            _AlarmDetailRow(
              icon: Icons.done_all,
              text: alarm.acknowledgedBy == null
                  ? 'Potwierdzony przez opiekuna'
                  : 'Potwierdzony przez opiekuna (ID ${alarm.acknowledgedBy})',
            ),
          ],
          if (canAcknowledge) ...[
            const SizedBox(
              height: 16,
            ),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accent.withValues(
                    alpha: 0.45,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: acknowledging
                    ? null
                    : onAcknowledge,
                icon: acknowledging
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.done_all,
                      ),
                label: Text(
                  acknowledging
                      ? 'Potwierdzanie...'
                      : 'Potwierdź alarm',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlarmDetailRow extends StatelessWidget {
  const _AlarmDetailRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF7B6D64),
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF5C4F48),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlarmHistoryCard extends StatelessWidget {
  const _AlarmHistoryCard({
    required this.alarm,
  });

  final Alarm alarm;

  @override
  Widget build(
    BuildContext context,
  ) {
    final iconColor = alarm.isCritical
        ? const Color(0xFFD95A42)
        : const Color(0xFF4D82B8);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF0E7DF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              color: iconColor,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm.typeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A2A24),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '${alarm.severityLabel} • ${alarm.statusLabel}',
                  style: const TextStyle(
                    color: Color(0xFF7B6D64),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  '${DateTimeFormatter.compact(alarm.startedAt)}'
                  '${alarm.resolvedAt == null ? '' : ' → ${DateTimeFormatter.compact(alarm.resolvedAt!)}'}',
                  style: const TextStyle(
                    color: Color(0xFF7B6D64),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: Color(0xFFA99B92),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.icon,
    required this.name,
    required this.deviceId,
    required this.statusText,
    required this.lastSeenText,
    required this.isActive,
    required this.isOnline,
  });

  final IconData icon;
  final String name;
  final String deviceId;
  final String statusText;
  final String lastSeenText;
  final bool isActive;
  final bool isOnline;

  @override
  Widget build(
    BuildContext context,
  ) {
    final statusColor = !isActive
        ? const Color(0xFF8A817C)
        : isOnline
            ? const Color(0xFF2F8F4E)
            : const Color(0xFFF28C28);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF0E7DF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFF4EEE8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6D5D54),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A2A24),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  '$deviceId • $lastSeenText',
                  style: const TextStyle(
                    color: Color(0xFF8A7D75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isOnline
                ? Icons.wifi
                : Icons.wifi_off,
            color: statusColor,
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.icon,
    required this.title,
    required this.deviceId,
    required this.receivedAt,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String deviceId;
  final String receivedAt;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF0E7DF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF356C9E),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A2A24),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '$deviceId • $receivedAt'
                  '${value.isEmpty ? '' : ' • $value'}',
                  style: const TextStyle(
                    color: Color(0xFF7B6D64),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleInfoCard extends StatelessWidget {
  const _SimpleInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF0E7DF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF4EEE8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6D5D54),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A2A24),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7B6D64),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
  });

  final String message;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFD92D20),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8D211A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
