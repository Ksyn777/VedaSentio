import 'package:flutter/material.dart';

import '../models/session_data.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    required this.session,
    required this.onLogout,
    super.key,
  });

  final SessionData session;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text(
            'Konto',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF3A2A24),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Dane opiekuna i informacje o dostępie do VedaSentio.',
            style: TextStyle(
              color: Color(0xFF776A63),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFF0E7DF),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE9DE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFFB85C3B),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  session.user.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3A2A24),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _AccountInfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'E-mail',
                  value: session.user.email,
                ),
                if (session.user.phone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _AccountInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefon',
                    value: session.user.phone,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bezpieczeństwo i dostęp',
            style: TextStyle(
              color: Color(0xFF3A2A24),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const _AccountCard(
            icon: Icons.shield_outlined,
            title: 'Sesja zabezpieczona',
            subtitle:
                'Token logowania jest przechowywany w bezpiecznym magazynie systemowym urządzenia.',
          ),
          const SizedBox(height: 10),
          _AccountCard(
            icon: Icons.home_work_outlined,
            title: 'Przypisane gospodarstwa',
            subtitle: session.homes.length == 1
                ? 'Masz dostęp do 1 gospodarstwa.'
                : 'Masz dostęp do ${session.homes.length} gospodarstw.',
          ),
          const SizedBox(height: 10),
          const _AccountCard(
            icon: Icons.notifications_active_outlined,
            title: 'Powiadomienia alarmowe',
            subtitle:
                'Krytyczne alarmy i ostrzeżenia mogą być wysyłane na to urządzenie.',
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () async {
                await onLogout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Wyloguj się',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB85C3B),
                side: const BorderSide(
                  color: Color(0xFFE2B6A3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFB85C3B),
            size: 21,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
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
      padding: const EdgeInsets.all(17),
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
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE9DE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFFB85C3B),
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
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
