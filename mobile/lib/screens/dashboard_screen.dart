import 'package:flutter/material.dart';

import '../models/session_data.dart';
import '../services/auth_service.dart';
import 'account_screen.dart';
import 'activity_screen.dart';
import 'alarm_history_screen.dart';
import 'home_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.session,
    required this.auth,
    required this.onLogout,
    required this.onSessionExpired,
    super.key,
  });

  final SessionData session;
  final AuthService auth;
  final Future<void> Function() onLogout;
  final Future<void> Function() onSessionExpired;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  Future<void> _openHome(
    BuildContext context,
    int index,
  ) async {
    final home = widget.session.homes[index];

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HomeDetailsScreen(
          home: home,
          authService: widget.auth,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    if (role == 'owner') {
      return 'Właściciel';
    }

    if (role == 'caregiver') {
      return 'Opiekun';
    }

    return role.isEmpty ? 'Użytkownik' : role;
  }

  Widget _buildHomeTab(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'VedaSentio',
            style: TextStyle(
              color: Color(0xFF3A2A24),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Witaj, ${widget.session.user.displayName}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF3A2A24),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.session.user.email,
            style: const TextStyle(
              color: Color(0xFF81746C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sprawdź aktualny stan bezpieczeństwa swoich bliskich.',
            style: TextStyle(
              color: Color(0xFF776A63),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Twoje gospodarstwa',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF3A2A24),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF6EEE5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                  color: Color(0xFFB85C3B),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.session.homes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFF0E7DF),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.home_outlined,
                    color: Color(0xFF81746C),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Brak przypisanych gospodarstw',
                      style: TextStyle(
                        color: Color(0xFF5C4F48),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(
              widget.session.homes.length,
              (index) {
                final home = widget.session.homes[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () => _openHome(context, index),
                      child: Ink(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: const Color(0xFFF0E7DF),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFE9DE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.home_outlined,
                                color: Color(0xFFB85C3B),
                                size: 29,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    home.name,
                                    style: const TextStyle(
                                      color: Color(0xFF3A2A24),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Dom • ${_roleLabel(home.role)}',
                                    style: const TextStyle(
                                      color: Color(0xFF81746C),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.sensors_outlined,
                                        size: 17,
                                        color: Color(0xFF2F8F4E),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Otwórz monitoring',
                                        style: TextStyle(
                                          color: Color(0xFF2F8F4E),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF9C8F87),
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(context),
          ActivityScreen(
            session: widget.session,
            auth: widget.auth,
            onSessionExpired: widget.onSessionExpired,
          ),
          AlarmHistoryScreen(
            session: widget.session,
            auth: widget.auth,
            onSessionExpired: widget.onSessionExpired,
          ),
          AccountScreen(
            session: widget.session,
            onLogout: widget.onLogout,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE1D2),
        surfaceTintColor: Colors.transparent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Dom',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline_rounded),
            label: 'Aktywność',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historia',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Konto',
          ),
        ],
      ),
    );
  }
}
