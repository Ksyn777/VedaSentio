import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/home.dart';
import '../models/home_details_data.dart';
import '../models/sensor_event.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/date_time_formatter.dart';

class HomeDetailsScreen extends StatefulWidget {
  const HomeDetailsScreen({
    required this.home,
    required this.authService,
    required this.onSessionExpired,
    super.key,
  });

  final Home home;
  final AuthService authService;
  final Future<void> Function() onSessionExpired;

  @override
  State<HomeDetailsScreen> createState() =>
      _HomeDetailsScreenState();
}

class _HomeDetailsScreenState
    extends State<HomeDetailsScreen> {
  HomeDetailsData? _data;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final data =
          await widget.authService.loadHomeDetails(
        widget.home.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.onSessionExpired();

        if (!mounted) {
          return;
        }

        Navigator.of(context).popUntil(
          (route) => route.isFirst,
        );

        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.isForbidden
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
    }
  }

  IconData _deviceIcon(Device device) {
    return switch (device.deviceType) {
      'sos_button' => Icons.sos_outlined,
      'door_contact' =>
        Icons.door_front_door_outlined,
      'smoke_detector' =>
        Icons.smoke_free_outlined,
      'co_detector' => Icons.air_outlined,
      'gas_detector' =>
        Icons.gas_meter_outlined,
      'flood_sensor' =>
        Icons.water_drop_outlined,
      _ => Icons.sensors_outlined,
    };
  }

  IconData _eventIcon(SensorEvent event) {
    return switch (event.eventType) {
      'sos_pressed' => Icons.sos,
      'door_opened' =>
        Icons.door_front_door_outlined,
      'door_closed' =>
        Icons.door_back_door_outlined,
      'smoke_detected' =>
        Icons.warning_amber_outlined,
      'co_detected' =>
        Icons.warning_amber_outlined,
      'gas_detected' =>
        Icons.warning_amber_outlined,
      'flood_detected' =>
        Icons.water_drop_outlined,
      _ => Icons.notifications_none_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.home.name),
        actions: [
          IconButton(
            tooltip: 'Odśwież',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _data == null) {
      return ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
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
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color:
                Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label:
                  const Text('Spróbuj ponownie'),
            ),
          ),
        ],
      );
    }

    final data = _data!;
    final activeCount = data.devices
        .where((device) => device.isActive)
        .length;

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(
                    Icons.home_outlined,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.home.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.home.id} • rola: ${widget.home.role}',
                      ),
                      const SizedBox(height: 8),
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
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _InlineError(
            message: _errorMessage!,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Urządzenia',
          style:
              Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (data.devices.isEmpty)
          const Card(
            child: ListTile(
              leading:
                  Icon(Icons.sensors_off_outlined),
              title: Text('Brak urządzeń'),
              subtitle: Text(
                'Do tego gospodarstwa nie przypisano jeszcze żadnych czujników.',
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
                  leading: CircleAvatar(
                    child: Icon(
                      _deviceIcon(device),
                    ),
                  ),
                  title: Text(
                    device.name.isEmpty
                        ? device.displayType
                        : device.name,
                  ),
                  subtitle: Text(
                    '$statusText\n'
                    '${device.id}'
                    '${latest == null ? '' : '\n${DateTimeFormatter.compact(latest.receivedAt)}'}',
                  ),
                  isThreeLine: true,
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
        const SizedBox(height: 24),
        Text(
          'Ostatnie zdarzenia',
          style:
              Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (data.recentEvents.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.history_toggle_off_outlined,
              ),
              title:
                  Text('Brak zapisanych zdarzeń'),
            ),
          )
        else
          ...data.recentEvents.map(
            (event) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    _eventIcon(event),
                  ),
                ),
                title:
                    Text(event.displayType),
                subtitle: Text(
                  '${event.deviceId}\n'
                  '${DateTimeFormatter.compact(event.receivedAt)}'
                  '${event.displayValue.isEmpty ? '' : ' • ${event.displayValue}'}',
                ),
                isThreeLine: true,
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .errorContainer,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context)
                .colorScheme
                .onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context)
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
