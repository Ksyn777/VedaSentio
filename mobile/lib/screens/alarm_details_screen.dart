import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../utils/date_time_formatter.dart';

class AlarmDetailsScreen extends StatelessWidget {
  const AlarmDetailsScreen({
    required this.alarm,
    required this.sourceLabel,
    super.key,
  });

  final Alarm alarm;
  final String sourceLabel;

  Color _accentColor() {
    if (alarm.isCritical) {
      return const Color(0xFFD92D20);
    }

    return const Color(0xFFF28C28);
  }

  IconData _alarmIcon() {
    if (alarm.alarmType == 'sos') {
      return Icons.sos;
    }

    if (alarm.alarmType == 'smoke') {
      return Icons.local_fire_department_outlined;
    }

    if (alarm.alarmType == 'flood') {
      return Icons.water_drop_outlined;
    }

    if (alarm.alarmType == 'device_offline') {
      return Icons.wifi_off_rounded;
    }

    return Icons.warning_amber_rounded;
  }

  String _resolutionLabel() {
    if (alarm.resolutionSource == null || alarm.resolutionSource!.isEmpty) {
      return 'Brak informacji';
    }

    if (alarm.resolutionSource == 'sensor_event') {
      return 'Zdarzenie z czujnika';
    }

    if (alarm.resolutionSource == 'heartbeat') {
      return 'Urządzenie ponownie online';
    }

    if (alarm.resolutionSource == 'manual') {
      return 'Ręcznie';
    }

    return alarm.resolutionSource!;
  }

  @override
  Widget build(BuildContext context) {
    Color accent = _accentColor();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F0),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Szczegóły alarmu',
          style: TextStyle(
            color: Color(0xFF3A2A24),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _alarmIcon(),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.typeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${alarm.severityLabel} • ${alarm.statusLabel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DetailsCard(
            title: 'Informacje',
            children: [
              _DetailsRow(
                icon: Icons.sensors_outlined,
                label: 'Źródło',
                value: sourceLabel,
              ),
              if (alarm.deviceId.isNotEmpty)
                _DetailsRow(
                  icon: Icons.memory_outlined,
                  label: 'Identyfikator urządzenia',
                  value: alarm.deviceId,
                ),
              _DetailsRow(
                icon: Icons.flag_outlined,
                label: 'Poziom',
                value: alarm.severityLabel,
              ),
              _DetailsRow(
                icon: Icons.info_outline_rounded,
                label: 'Status',
                value: alarm.statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailsCard(
            title: 'Przebieg zdarzenia',
            children: [
              _DetailsRow(
                icon: Icons.play_circle_outline_rounded,
                label: 'Rozpoczęto',
                value: DateTimeFormatter.compact(alarm.startedAt),
              ),
              if (alarm.acknowledgedAt != null &&
                  alarm.acknowledgedAt!.isNotEmpty)
                _DetailsRow(
                  icon: Icons.done_all_rounded,
                  label: 'Potwierdzono',
                  value: DateTimeFormatter.compact(alarm.acknowledgedAt!),
                ),
              if (alarm.resolvedAt != null && alarm.resolvedAt!.isNotEmpty)
                _DetailsRow(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Zakończono',
                  value: DateTimeFormatter.compact(alarm.resolvedAt!),
                ),
              if (alarm.isResolved)
                _DetailsRow(
                  icon: Icons.rule_outlined,
                  label: 'Sposób zakończenia',
                  value: _resolutionLabel(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFF0E7DF),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFB85C3B),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Historia alarmu jest zachowywana po jego zakończeniu, aby opiekun mógł później sprawdzić przebieg zdarzenia.',
                    style: TextStyle(
                      color: Color(0xFF776A63),
                      height: 1.4,
                    ),
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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF0E7DF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3A2A24),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFFB85C3B),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9A8D85),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF5C4F48),
                    fontWeight: FontWeight.w700,
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
