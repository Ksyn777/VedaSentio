import 'package:flutter/material.dart';
import '../models/session_data.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.auth, required this.onLogin, this.startupError, super.key});
  final AuthService auth;
  final ValueChanged<SessionData> onLogin;
  final String? startupError;
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy=false, _obscure=true;
  String? _error;

  @override void initState(){ super.initState(); _error=widget.startupError; }
  @override void dispose(){ _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _busy=true; _error=null; });
    try {
      final s = await widget.auth.login(_email.text, _password.text);
      _password.clear();
      if (mounted) widget.onLogin(s);
    } on ApiException catch(e) {
      if (mounted) setState(() => _error = e.statusCode == 401 ? 'Nieprawidłowy e-mail lub hasło.' : e.message);
    } catch (_) {
      if (mounted) setState(() => _error='Nie udało się połączyć z backendem.');
    } finally {
      if (mounted) setState(() => _busy=false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Card(
        child: Padding(padding: const EdgeInsets.all(24), child: Form(key: _form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.health_and_safety_outlined, size: 58, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('VedaSentio', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText:'E-mail', border: OutlineInputBorder()), validator:(v){ final x=v?.trim()??''; if(x.isEmpty) return 'Podaj e-mail.'; if(!x.contains('@')) return 'Niepoprawny e-mail.'; return null; }),
            const SizedBox(height: 16),
            TextFormField(controller: _password, obscureText:_obscure, onFieldSubmitted:(_)=>_submit(), decoration: InputDecoration(labelText:'Hasło', border: const OutlineInputBorder(), suffixIcon:IconButton(onPressed:()=>setState(()=>_obscure=!_obscure), icon:Icon(_obscure?Icons.visibility:Icons.visibility_off))), validator:(v)=>(v??'').isEmpty?'Podaj hasło.':null),
            if(_error!=null)...[const SizedBox(height:16), Text(_error!, style:TextStyle(color:Theme.of(context).colorScheme.error))],
            const SizedBox(height:20),
            FilledButton(onPressed:_busy?null:_submit, child:Text(_busy?'Logowanie...':'Zaloguj')),
          ],
        ))),
      )),
    ))),
  );
}
