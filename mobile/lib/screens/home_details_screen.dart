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
    super.key,
  });

  final Home home;
  final AuthService authService;
  final Future<void> Function()
      onSessionExpired;

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
  }) async {
    if (_refreshInProgress) {
      return;
    }

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
        _acknowledgingAlarmId !=
            null) {
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
      appBar: AppBar(
        title:
            Text(widget.home.name),
        actions: [
          IconButton(
            tooltip:
                'Odśwież teraz',
            onPressed:
                _refreshInProgress
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
          child:
              _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
  ) {
    if (_loading &&
        _data == null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 320,
            child: Center(
              child:
                  CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null &&
        _data == null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(20),
        children: [
          const SizedBox(
            height: 80,
          ),
          Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color:
                Theme.of(context)
                    .colorScheme
                    .error,
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            _errorMessage!,
            textAlign:
                TextAlign.center,
          ),
          const SizedBox(
            height: 16,
          ),
          Center(
            child:
                FilledButton.icon(
              onPressed:
                  _manualRefresh,
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

    final activeCount =
        data.devices
            .where(
              (device) =>
                  device.isActive,
            )
            .length;

    final safetyStatus =
        AlarmStatusService
            .fromBackendAlarms(
      data.activeAlarms,
    );

    final resolvedAlarms =
        data.alarmHistory
            .where(
              (alarm) =>
                  alarm.isResolved,
            )
            .toList(
              growable: false,
            );

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.all(20),
      children: [
        _SafetyStatusCard(
          status: safetyStatus,
          activeAlarmCount:
              data.activeAlarms.length,
        ),
        const SizedBox(
          height: 8,
        ),
        Row(
          children: [
            const Icon(
              Icons.sync,
              size: 17,
            ),
            const SizedBox(
              width: 6,
            ),
            Expanded(
              child: Text(
                'Monitoring na żywo • status z backendu • '
                'odświeżanie co '
                '${_autoRefreshInterval.inSeconds} s • '
                'ostatnio: ${_lastUpdatedLabel()}',
                style:
                    Theme.of(context)
                        .textTheme
                        .bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 16,
        ),
        Card(
          child: Padding(
            padding:
                const EdgeInsets
                    .all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(
                    Icons
                        .home_outlined,
                    size: 30,
                  ),
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        widget
                            .home.name,
                        style:
                            Theme.of(
                                    context)
                                .textTheme
                                .titleLarge,
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        '${widget.home.id} • rola: ${widget.home.role}',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        '$activeCount z '
                        '${data.devices.length} '
                        'urządzeń aktywnych',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage !=
            null) ...[
          const SizedBox(
            height: 12,
          ),
          _InlineError(
            message:
                _errorMessage!,
          ),
        ],
        const SizedBox(
          height: 24,
        ),
        Text(
          'Aktywne alarmy',
          style:
              Theme.of(context)
                  .textTheme
                  .titleLarge,
        ),
        const SizedBox(
          height: 12,
        ),
        if (data
            .activeAlarms
            .isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(
                Icons
                    .verified_user_outlined,
              ),
              title: Text(
                'Brak aktywnych alarmów',
              ),
              subtitle: Text(
                'Stan pochodzi z backendowej tabeli alarmów.',
              ),
            ),
          )
        else
          ...data.activeAlarms
              .map(
            (alarm) =>
                _AlarmCard(
              alarm: alarm,
              canAcknowledge:
                  _canManageAlarms &&
                      alarm.status ==
                          'active',
              acknowledging:
                  _acknowledgingAlarmId ==
                      alarm.id,
              onAcknowledge:
                  () =>
                      _acknowledge(
                alarm,
              ),
            ),
          ),
        const SizedBox(
          height: 24,
        ),
        Text(
          'Historia alarmów',
          style:
              Theme.of(context)
                  .textTheme
                  .titleLarge,
        ),
        const SizedBox(
          height: 12,
        ),
        if (resolvedAlarms.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.history,
              ),
              title: Text(
                'Brak zakończonych alarmów',
              ),
            ),
          )
        else
          ...resolvedAlarms.map(
            (alarm) =>
                _AlarmHistoryCard(
              alarm: alarm,
            ),
          ),
        const SizedBox(
          height: 24,
        ),
        Text(
          'Urządzenia',
          style:
              Theme.of(context)
                  .textTheme
                  .titleLarge,
        ),
        const SizedBox(
          height: 12,
        ),
        if (data.devices.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(
                Icons
                    .sensors_off_outlined,
              ),
              title: Text(
                'Brak urządzeń',
              ),
            ),
          )
        else
          ...data.devices.map(
            (device) {
              final latest =
                  data.latestEventsByDevice[
                      device.id];

              final statusText =
                  !device.isActive
                      ? 'Urządzenie nieaktywne'
                      : latest == null
                          ? 'Aktywne • brak zapisanych zdarzeń'
                          : 'Aktywne • ${latest.displayType}';

              return Card(
                child: ListTile(
                  leading:
                      CircleAvatar(
                    child: Icon(
                      _deviceIcon(
                        device,
                      ),
                    ),
                  ),
                  title: Text(
                    device.name
                            .isEmpty
                        ? device
                            .displayType
                        : device.name,
                  ),
                  subtitle: Text(
                    '$statusText\n'
                    '${device.id}'
                    '${latest == null ? '' : '\n${DateTimeFormatter.compact(latest.receivedAt)}'}',
                  ),
                  isThreeLine:
                      true,
                  trailing: Icon(
                    device.isActive
                        ? Icons
                            .check_circle_outline
                        : Icons
                            .pause_circle_outline,
                  ),
                ),
              );
            },
          ),
        const SizedBox(
          height: 24,
        ),
        Text(
          'Historia zdarzeń technicznych',
          style:
              Theme.of(context)
                  .textTheme
                  .titleLarge,
        ),
        const SizedBox(
          height: 12,
        ),
        if (data
            .recentEvents
            .isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(
                Icons
                    .history_toggle_off_outlined,
              ),
              title: Text(
                'Brak zapisanych zdarzeń',
              ),
            ),
          )
        else
          ...data.recentEvents
              .map(
            (event) => Card(
              child: ListTile(
                leading:
                    CircleAvatar(
                  child: Icon(
                    _eventIcon(
                      event,
                    ),
                  ),
                ),
                title: Text(
                  event.displayType,
                ),
                subtitle: Text(
                  '${event.deviceId}\n'
                  '${DateTimeFormatter.compact(event.receivedAt)}'
                  '${event.displayValue.isEmpty ? '' : ' • ${event.displayValue}'}',
                ),
                isThreeLine:
                    true,
              ),
            ),
          ),
        const SizedBox(
          height: 24,
        ),
      ],
    );
  }
}

class _SafetyStatusCard
    extends StatelessWidget {
  const _SafetyStatusCard({
    required this.status,
    required this.activeAlarmCount,
  });

  final HomeSafetyStatus status;
  final int activeAlarmCount;

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    final background =
        switch (status.level) {
      SafetyLevel.safe =>
        Colors.green.shade50,
      SafetyLevel.warning =>
        Colors.orange.shade50,
      SafetyLevel.alarm =>
        scheme.errorContainer,
    };

    final foreground =
        switch (status.level) {
      SafetyLevel.safe =>
        Colors.green.shade900,
      SafetyLevel.warning =>
        Colors.orange.shade900,
      SafetyLevel.alarm =>
        scheme.onErrorContainer,
    };

    final icon =
        switch (status.level) {
      SafetyLevel.safe =>
        Icons
            .verified_user_outlined,
      SafetyLevel.warning =>
        Icons
            .warning_amber_outlined,
      SafetyLevel.alarm =>
        Icons.crisis_alert,
    };

    return Container(
      decoration:
          BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      padding:
          const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: foreground,
            size: 34,
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  status.title,
                  style:
                      Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            color:
                                foreground,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  status.message,
                  style: TextStyle(
                    color:
                        foreground,
                  ),
                ),
                if (activeAlarmCount >
                    0) ...[
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Aktywne alarmy: $activeAlarmCount',
                    style:
                        TextStyle(
                      color:
                          foreground,
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmCard
    extends StatelessWidget {
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
    final isCritical =
        alarm.isCritical;

    final scheme =
        Theme.of(context)
            .colorScheme;

    final background =
        isCritical
            ? scheme
                .errorContainer
            : Colors
                .orange.shade50;

    final foreground =
        isCritical
            ? scheme
                .onErrorContainer
            : Colors
                .orange.shade900;

    return Card(
      color: background,
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            Row(
              children: [
                Icon(
                  isCritical
                      ? Icons
                          .crisis_alert
                      : Icons
                          .warning_amber_outlined,
                  color:
                      foreground,
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    alarm.typeLabel,
                    style:
                        Theme.of(
                                context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color:
                                  foreground,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                  ),
                ),
                Text(
                  alarm.statusLabel,
                  style: TextStyle(
                    color:
                        foreground,
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              '${alarm.severityLabel} • ${alarm.deviceId}',
              style: TextStyle(
                color: foreground,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              'Rozpoczęto: ${DateTimeFormatter.compact(alarm.startedAt)}',
              style: TextStyle(
                color: foreground,
              ),
            ),
            if (alarm
                .isAcknowledged) ...[
              const SizedBox(
                height: 4,
              ),
              Text(
                alarm.acknowledgedBy ==
                        null
                    ? 'Potwierdzony przez opiekuna'
                    : 'Potwierdzony przez opiekuna (ID ${alarm.acknowledgedBy})',
                style: TextStyle(
                  color:
                      foreground,
                  fontWeight:
                      FontWeight
                          .w600,
                ),
              ),
            ],
            if (canAcknowledge) ...[
              const SizedBox(
                height: 14,
              ),
              FilledButton.icon(
                onPressed:
                    acknowledging
                        ? null
                        : onAcknowledge,
                icon: acknowledging
                    ? const SizedBox
                        .square(
                        dimension: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                        ),
                      )
                    : const Icon(
                        Icons
                            .done_all,
                      ),
                label: Text(
                  acknowledging
                      ? 'Potwierdzanie...'
                      : 'Potwierdź alarm',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlarmHistoryCard
    extends StatelessWidget {
  const _AlarmHistoryCard({
    required this.alarm,
  });

  final Alarm alarm;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons.history,
          ),
        ),
        title: Text(
          alarm.typeLabel,
        ),
        subtitle: Text(
          '${alarm.severityLabel} • ${alarm.statusLabel}\n'
          '${DateTimeFormatter.compact(alarm.startedAt)}'
          '${alarm.resolvedAt == null ? '' : ' → ${DateTimeFormatter.compact(alarm.resolvedAt!)}'}'
          '${alarm.acknowledgedBy == null ? '' : '\nPotwierdził użytkownik ID ${alarm.acknowledgedBy}'}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _InlineError
    extends StatelessWidget {
  const _InlineError({
    required this.message,
  });

  final String message;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .errorContainer,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color:
                Theme.of(context)
                    .colorScheme
                    .onErrorContainer,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color:
                    Theme.of(context)
                        .colorScheme
                        .onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
