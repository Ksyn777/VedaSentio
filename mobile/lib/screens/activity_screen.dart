import 'package:flutter/material.dart';

import '../models/sensor_event.dart';
import '../models/session_data.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/date_time_formatter.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    required this.session,
    required this.auth,
    required this.onSessionExpired,
    super.key,
  });

  final SessionData session;
  final AuthService auth;
  final Future<void> Function() onSessionExpired;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _selectedHomeIndex = 0;
  bool _loading = true;
  String? _errorMessage;
  List<SensorEvent> _events = const [];
  int _loadGeneration = 0;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    final generation = ++_loadGeneration;
    if (widget.session.homes.isEmpty) {
      setState(() {
        _loading = false;
        _events = const [];
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
      final events = await widget.auth.loadHomeEvents(
        home.id,
        limit: 50,
      );

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _events = events
            .where((event) => event.eventType != 'heartbeat')
            .toList(growable: false);
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
        _errorMessage = 'Nie udało się pobrać aktywności.';
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
      _selectedDate = null;
      _events = const [];
      _loading = true;
      _errorMessage = null;
    });

    _loadActivity();
  }

  bool _isSameDate(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  List<SensorEvent> _visibleEvents() {
    if (_selectedDate == null) {
      return _events;
    }

    List<SensorEvent> filteredEvents = [];

    for (final event in _events) {
      DateTime? parsed = DateTime.tryParse(event.receivedAt);

      if (parsed == null) {
        continue;
      }

      DateTime localEventDate = parsed.toLocal();

      if (_isSameDate(localEventDate, _selectedDate!)) {
        filteredEvents.add(event);
      }
    }

    return filteredEvents;
  }

  String _dateLabel(DateTime date) {
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  void _selectToday() {
    DateTime now = DateTime.now();

    setState(() {
      _selectedDate = DateTime(
        now.year,
        now.month,
        now.day,
      );
    });
  }

  void _selectYesterday() {
    DateTime yesterday = DateTime.now().subtract(
      const Duration(days: 1),
    );

    setState(() {
      _selectedDate = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
      );
    });
  }

  Future<void> _chooseDate() async {
    DateTime now = DateTime.now();

    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2025),
      lastDate: now,
      helpText: 'Wybierz datę aktywności',
      cancelText: 'Anuluj',
      confirmText: 'Wybierz',
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
    });
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  IconData _eventIcon(SensorEvent event) {
    if (event.eventType == 'door_opened' ||
        event.eventType == 'door_closed') {
      return Icons.door_front_door_outlined;
    }

    if (event.eventType == 'sos_pressed') {
      return Icons.sos;
    }

    if (event.eventType == 'flood_detected') {
      return Icons.water_drop_outlined;
    }

    if (event.eventType == 'smoke_detected' ||
        event.eventType == 'gas_detected' ||
        event.eventType == 'co_detected') {
      return Icons.warning_amber_rounded;
    }

    if (event.eventType.endsWith('_cleared') ||
        event.eventType == 'sos_resolved') {
      return Icons.check_circle_outline;
    }

    return Icons.notifications_none_rounded;
  }

  Color _eventColor(SensorEvent event) {
    if (event.eventType == 'flood_detected') {
      return const Color(0xFFF28C28);
    }

    if (event.eventType == 'sos_pressed' ||
        event.eventType == 'smoke_detected' ||
        event.eventType == 'gas_detected' ||
        event.eventType == 'co_detected') {
      return const Color(0xFFD92D20);
    }

    if (event.eventType == 'door_opened' ||
        event.eventType == 'door_closed') {
      return const Color(0xFF356C9E);
    }

    return const Color(0xFF2F8F4E);
  }

  String _eventSourceLabel(SensorEvent event) {
    if (event.eventType == 'door_opened' ||
        event.eventType == 'door_closed') {
      return 'Drzwi wejściowe';
    }

    if (event.eventType == 'sos_pressed' ||
        event.eventType == 'sos_resolved') {
      return 'Przycisk SOS';
    }

    if (event.eventType == 'smoke_detected' ||
        event.eventType == 'smoke_cleared') {
      return 'Czujnik dymu';
    }

    if (event.eventType == 'co_detected' ||
        event.eventType == 'co_cleared') {
      return 'Czujnik CO';
    }

    if (event.eventType == 'gas_detected' ||
        event.eventType == 'gas_cleared') {
      return 'Czujnik gazu';
    }

    if (event.eventType == 'flood_detected' ||
        event.eventType == 'flood_cleared') {
      return 'Czujnik zalania';
    }

    if (event.deviceId.isEmpty) {
      return 'Urządzenie';
    }

    return 'Urządzenie ${event.deviceId}';
  }

  String _eventStateLabel(SensorEvent event) {
    if (event.eventType == 'door_opened') {
      return 'Otwarte';
    }

    if (event.eventType == 'door_closed') {
      return 'Zamknięte';
    }

    if (event.eventType == 'sos_pressed') {
      return 'Wezwanie';
    }

    if (event.eventType == 'sos_resolved') {
      return 'Zakończone';
    }

    if (event.eventType.endsWith('_detected')) {
      return 'Wykryto';
    }

    if (event.eventType.endsWith('_cleared')) {
      return 'Brak zagrożenia';
    }

    return '';
  }

  String _dayGroupLabel(String timestamp) {
    DateTime? parsed = DateTime.tryParse(timestamp);

    if (parsed == null) {
      return 'Wcześniej';
    }

    DateTime local = parsed.toLocal();
    DateTime now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (_isSameDate(local, now)) {
      return 'Dzisiaj';
    }

    if (_isSameDate(local, yesterday)) {
      return 'Wczoraj';
    }

    String day = local.day.toString().padLeft(2, '0');
    String month = local.month.toString().padLeft(2, '0');

    return '$day.$month.${local.year}';
  }

  List<Widget> _buildGroupedEvents(
    List<SensorEvent> events,
  ) {
    List<Widget> widgets = [];
    String previousGroup = '';

    for (final event in events) {
      String group = _dayGroupLabel(event.receivedAt);

      if (group != previousGroup) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              top: 2,
              bottom: 10,
            ),
            child: Text(
              group,
              style: const TextStyle(
                color: Color(0xFF5C4F48),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );

        previousGroup = group;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ActivityCard(
            event: event,
            icon: _eventIcon(event),
            accent: _eventColor(event),
            sourceLabel: _eventSourceLabel(event),
            stateLabel: _eventStateLabel(event),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildDateFilter() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );
    DateTime yesterday = today.subtract(
      const Duration(days: 1),
    );

    bool todaySelected = _selectedDate != null &&
        _isSameDate(_selectedDate!, today);
    bool yesterdaySelected = _selectedDate != null &&
        _isSameDate(_selectedDate!, yesterday);
    bool customDateSelected = _selectedDate != null &&
        !todaySelected &&
        !yesterdaySelected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtruj po dacie',
          style: TextStyle(
            color: Color(0xFF5C4F48),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              selected: todaySelected,
              onSelected: (_) => _selectToday(),
              label: const Text('Dzisiaj'),
              selectedColor: const Color(0xFFFFE1D2),
              checkmarkColor: const Color(0xFFB85C3B),
              backgroundColor: Colors.white,
              side: const BorderSide(
                color: Color(0xFFE9DDD1),
              ),
            ),
            FilterChip(
              selected: yesterdaySelected,
              onSelected: (_) => _selectYesterday(),
              label: const Text('Wczoraj'),
              selectedColor: const Color(0xFFFFE1D2),
              checkmarkColor: const Color(0xFFB85C3B),
              backgroundColor: Colors.white,
              side: const BorderSide(
                color: Color(0xFFE9DDD1),
              ),
            ),
            FilterChip(
              selected: customDateSelected,
              onSelected: (_) => _chooseDate(),
              avatar: const Icon(
                Icons.calendar_month_outlined,
                size: 18,
              ),
              label: Text(
                customDateSelected
                    ? _dateLabel(_selectedDate!)
                    : 'Wybierz datę',
              ),
              selectedColor: const Color(0xFFFFE1D2),
              checkmarkColor: const Color(0xFFB85C3B),
              backgroundColor: Colors.white,
              side: const BorderSide(
                color: Color(0xFFE9DDD1),
              ),
            ),
            if (_selectedDate != null)
              ActionChip(
                onPressed: _clearDateFilter,
                avatar: const Icon(
                  Icons.close,
                  size: 18,
                ),
                label: const Text('Wszystkie'),
                backgroundColor: const Color(0xFFF6EFE8),
                side: const BorderSide(
                  color: Color(0xFFE9DDD1),
                ),
              ),
          ],
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    List<SensorEvent> visibleEvents = _visibleEvents();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadActivity,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          children: [
            Text(
              'Aktywność',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF3A2A24),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Zdarzenia z czujników, które pomagają zrozumieć codzienną rutynę.',
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
              const SizedBox(height: 4),
              Text(
                _loading
                    ? 'Pobieranie ostatnich zdarzeń'
                    : _selectedDate == null
                        ? 'Ostatnie zdarzenia: ${_events.length}'
                        : 'Zdarzenia: ${visibleEvents.length} • ${_dateLabel(_selectedDate!)}',
                style: const TextStyle(
                  color: Color(0xFF81746C),
                ),
              ),
              const SizedBox(height: 14),
              if (!_loading) ...[
                _buildDateFilter(),
                const SizedBox(height: 18),
              ],
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              _MessageCard(
                icon: Icons.cloud_off_outlined,
                title: 'Nie udało się pobrać danych',
                subtitle: _errorMessage!,
              )
            else if (widget.session.homes.isEmpty)
              const _MessageCard(
                icon: Icons.home_outlined,
                title: 'Brak gospodarstw',
                subtitle: 'Nie masz jeszcze przypisanego gospodarstwa.',
              )
            else if (_events.isEmpty)
              const _MessageCard(
                icon: Icons.timeline_outlined,
                title: 'Brak aktywności',
                subtitle: 'Pierwsze zdarzenia z urządzeń pojawią się tutaj.',
              )
            else if (visibleEvents.isEmpty)
              _MessageCard(
                icon: Icons.event_busy_outlined,
                title: 'Brak zdarzeń',
                subtitle: _selectedDate == null
                    ? 'Brak zdarzeń do wyświetlenia.'
                    : 'Brak zdarzeń dla daty ${_dateLabel(_selectedDate!)}.',
              )
            else
              ..._buildGroupedEvents(visibleEvents),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.event,
    required this.icon,
    required this.accent,
    required this.sourceLabel,
    required this.stateLabel,
  });

  final SensorEvent event;
  final IconData icon;
  final Color accent;
  final String sourceLabel;
  final String stateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  event.displayType,
                  style: const TextStyle(
                    color: Color(0xFF3A2A24),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sourceLabel,
                  style: const TextStyle(
                    color: Color(0xFF81746C),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateTimeFormatter.compact(event.receivedAt),
                  style: const TextStyle(
                    color: Color(0xFF9A8D85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (stateLabel.isNotEmpty)
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
                stateLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
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
