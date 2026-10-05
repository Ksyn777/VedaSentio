import 'package:flutter/material.dart';

import '../models/session_data.dart';
import '../services/auth_service.dart';
import 'home_details_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.session,
    required this.auth,
    required this.onLogout,
    super.key,
  });

  final SessionData session;
  final AuthService auth;
  final Future<void> Function() onLogout;

  Future<void> _openHome(
    BuildContext context,
    int index,
  ) async {
    final home = session.homes[index];

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HomeDetailsScreen(
          home: home,
          authService: auth,
          onSessionExpired: onLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VedaSentio'),
        actions: [
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Wyloguj',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Witaj, ${session.user.displayName}',
            style:
                Theme.of(context).textTheme.headlineSmall,
          ),
          Text(session.user.email),
          const SizedBox(height: 24),
          Text(
            'Twoje gospodarstwa',
            style:
                Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (session.homes.isEmpty)
            const Card(
              child: ListTile(
                title: Text(
                  'Brak przypisanych gospodarstw',
                ),
              ),
            )
          else
            ...List.generate(
              session.homes.length,
              (index) {
                final home = session.homes[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.home_outlined,
                      ),
                    ),
                    title: Text(home.name),
                    subtitle: Text(
                      '${home.id} • rola: ${home.role}',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () => _openHome(
                      context,
                      index,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
          const Card(
            child: ListTile(
              leading:
                  Icon(Icons.security_outlined),
              title:
                  Text('Sesja zabezpieczona'),
              subtitle: Text(
                'JWT jest przechowywany w bezpiecznym magazynie systemowym.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
