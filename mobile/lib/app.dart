import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';

class VedaSentioApp extends StatelessWidget {
  const VedaSentioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VedaSentio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF345E8A)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
