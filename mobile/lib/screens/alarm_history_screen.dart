import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../models/session_data.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/date_time_formatter.dart';
import 'alarm_details_screen.dart';

class AlarmHistoryScreen extends StatefulWidget {
  const AlarmHistoryScreen({
    required this.session,
    required this.auth,
    required this.onSessionExpired,
    super.key,
  });

  final SessionData session;
  final AuthService auth;
  final Future<void> Function() onSessionExpired;

  @override
  State<AlarmHistoryScreen> createState() => _AlarmHistoryScreenState();
}

class _AlarmHistoryScreenState extends State<AlarmHistoryScreen> {
  int _selectedHomeIndex = 0;
  String _selectedFilter = 'all';
  bool _loading = true;
  String? _errorMessage;
  List<Alarm> _alarms = const [];
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final generation = ++_loadGeneration;
    if (widget.session.homes.isEmpty) {
      setState(() {
        _loading = false;
        _alarms = const [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final home = widget.session.homes[_selectedHomeIndex];

    try {
      final alarms = await widget.auth.loadHomeAlarms(
        home.id,
        limit: 50,
      );

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _alarms = alarms;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      if (error.isUnauthorized) {
        await widget.onSessionExpired();
        return;
      }

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _errorMessage = 'Nie udało się pobrać historii alarmów.';
        _loading = false;
      });
    }
  }

  void _selectHome(int index) {
    if (_selectedHomeIndex == index) {
      return;
    }

    setState(() {
      _selectedHomeIndex = index;
      _alarms = const [];
      _loading = true;
      _errorMessage = null;
    });

    _loadHistory();
  }

  List<Alarm> _filteredAlarms() {
    List<Alarm> result = [];

    for (final alarm in _alarms) {
      if (_selectedFilter == 'critical' && !alarm.isCritical) {
        continue;
      }

      if (_selectedFilter == 'warning' && alarm.isCritical) {
        continue;
      }

      result.add(alarm);
    }

    return result;
  }

  String _alarmSourceLabel(Alarm alarm) {
    if (alarm.alarmType == 'sos') {
      return 'Przycisk SOS';
    }

    if (alarm.alarmType == 'smoke') {
      return 'Czujnik dymu';
    }

    if (alarm.alarmType == 'co') {
      return 'Czujnik CO';
    }

    if (alarm.alarmType == 'gas') {
      return 'Czujnik gazu';
    }

    if (alarm.alarmType == 'flood') {
      return 'Czujnik zalania';
    }

    if (alarm.alarmType == 'device_offline') {
      return 'Problem z połączeniem urządzenia';
    }

    if (alarm.deviceId.isEmpty) {
      return 'Urządzenie';
    }

    return 'Urządzenie ${alarm.deviceId}';
  }

  IconData _alarmIcon(Alarm alarm) {
    if (alarm.alarmType == 'sos') {
      return Icons.sos;
    }

    if (alarm.alarmType == 'smoke') {
      return Icons.local_fire_department_outlined;
    }

    if (alarm.alarmType == 'co' || alarm.alarmType == 'gas') {
      return Icons.warning_amber_rounded;
    }

    if (alarm.alarmType == 'flood') {
      return Icons.water_drop_outlined;
    }

    if (alarm.alarmType == 'device_offline') {
      return Icons.wifi_off_rounded;
    }

    if (alarm.isResolved) {
      return Icons.history_rounded;
    }

    return Icons.crisis_alert;
  }

  void _openAlarmDetails(Alarm alarm) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlarmDetailsScreen(
          alarm: alarm,
          sourceLabel: _alarmSourceLabel(alarm),
        ),
      ),
    );
  }

  Widget _buildHomeSelector() {
    if (widget.session.homes.length <= 1) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        widget.session.homes.length,
        (index) {
          final home = widget.session.homes[index];

          return FilterChip(
            selected: _selectedHomeIndex == index,
            onSelected: (_) => _selectHome(index),
            label: Text(home.name),
            selectedColor: const Color(0xFFFFE1D2),
            checkmarkColor: const Color(0xFFB85C3B),
            backgroundColor: Colors.white,
            side: const BorderSide(
              color: Color(0xFFE9DDD1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlarmFilter(
    String label,
    String value,
  ) {
    bool selected = _selectedFilter == value;

    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
      label: Text(label),
      selectedColor: const Color(0xFFFFE1D2),
      backgroundColor: Colors.white,
      side: const BorderSide(
        color: Color(0xFFE9DDD1),
      ),
      labelStyle: TextStyle(
        color: selected
            ? const Color(0xFF9C482D)
            : const Color(0xFF776A63),
        fontWeight: FontWeight.w700,
      ),
      showCheckmark: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleAlarms = _filteredAlarms();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          children: [
            Text(
              'Historia alarmów',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF3A2A24),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Wszystkie zarejestrowane alarmy i ostrzeżenia w jednym miejscu.',
              style: TextStyle(
                color: Color(0xFF776A63),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            _buildHomeSelector(),
            if (widget.session.homes.length > 1)
              const SizedBox(height: 22),
            if (widget.session.homes.isNotEmpty) ...[
              Text(
                widget.session.homes[_selectedHomeIndex].name,
                style: const TextStyle(
                  color: Color(0xFF3A2A24),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildAlarmFilter('Wszystkie', 'all'),
                  _buildAlarmFilter('Krytyczne', 'critical'),
                  _buildAlarmFilter('Ostrzeżenia', 'warning'),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              _HistoryMessageCard(
                icon: Icons.cloud_off_outlined,
                title: 'Nie udało się pobrać historii',
                subtitle: _errorMessage!,
              )
            else if (widget.session.homes.isEmpty)
              const _HistoryMessageCard(
                icon: Icons.home_outlined,
                title: 'Brak gospodarstw',
                subtitle: 'Nie masz jeszcze przypisanego gospodarstwa.',
              )
            else if (_alarms.isEmpty)
              const _HistoryMessageCard(
                icon: Icons.verified_user_outlined,
                title: 'Brak alarmów',
                subtitle: 'Historia alarmów jest obecnie pusta.',
              )
            else if (visibleAlarms.isEmpty)
              const _HistoryMessageCard(
                icon: Icons.filter_alt_off_outlined,
                title: 'Brak wyników',
                subtitle: 'W tej kategorii nie ma obecnie żadnych alarmów.',
              )
            else
              ...visibleAlarms.map(
                (alarm) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlarmHistoryCard(
                    alarm: alarm,
                    sourceLabel: _alarmSourceLabel(alarm),
                    icon: _alarmIcon(alarm),
                    onTap: () => _openAlarmDetails(alarm),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlarmHistoryCard extends StatelessWidget {
  const _AlarmHistoryCard({
    required this.alarm,
    required this.sourceLabel,
    required this.icon,
    required this.onTap,
  });

  final Alarm alarm;
  final String sourceLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color accent;

    if (alarm.isCritical) {
      accent = const Color(0xFFD92D20);
    } else {
      accent = const Color(0xFFF28C28);
    }

    if (alarm.isResolved) {
      accent = alarm.isCritical
          ? const Color(0xFFE36A61)
          : const Color(0xFFB58B59);
    }

    String timeText = DateTimeFormatter.compact(alarm.startedAt);

    if (alarm.resolvedAt != null && alarm.resolvedAt!.isNotEmpty) {
      timeText = '$timeText → ${DateTimeFormatter.compact(alarm.resolvedAt!)}';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFF0E7DF),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarm.typeLabel,
                      style: const TextStyle(
                        color: Color(0xFF3A2A24),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${alarm.severityLabel} • $sourceLabel',
                      style: const TextStyle(
                        color: Color(0xFF81746C),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: Color(0xFF9A8D85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      alarm.statusLabel,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB3A79F),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryMessageCard extends StatelessWidget {
  const _HistoryMessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

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
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFB85C3B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF3A2A24),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF776A63),
                    height: 1.3,
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
