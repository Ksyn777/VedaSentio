import 'package:flutter/material.dart';
import '../models/session_data.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.session, required this.onLogout, super.key});
  final SessionData session;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VedaSentio'), actions:[IconButton(onPressed:onLogout, icon:const Icon(Icons.logout), tooltip:'Wyloguj')]),
    body: ListView(padding: const EdgeInsets.all(20), children:[
      Text('Witaj, ${session.user.displayName}', style:Theme.of(context).textTheme.headlineSmall),
      Text(session.user.email),
      const SizedBox(height:24),
      Text('Twoje gospodarstwa', style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:12),
      if(session.homes.isEmpty)
        const Card(child:ListTile(title:Text('Brak przypisanych gospodarstw')))
      else
        ...session.homes.map((h)=>Card(child:ListTile(
          leading:const CircleAvatar(child:Icon(Icons.home_outlined)),
          title:Text(h.name),
          subtitle:Text('${h.id} • rola: ${h.role}'),
          trailing:const Icon(Icons.chevron_right),
          onTap:()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Szczegóły ${h.name} dodamy w następnym etapie.'))),
        ))),
      const SizedBox(height:20),
      const Card(child:ListTile(leading:Icon(Icons.security_outlined), title:Text('Sesja zabezpieczona'), subtitle:Text('JWT jest przechowywany w bezpiecznym magazynie systemowym.'))),
    ]),
  );
}
