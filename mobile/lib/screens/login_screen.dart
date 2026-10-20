import 'package:flutter/material.dart';

import '../models/session_data.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.auth,
    required this.onLogin,
    this.startupError,
    super.key,
  });

  final AuthService auth;
  final ValueChanged<SessionData> onLogin;
  final String? startupError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.startupError;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    if (!_form.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      SessionData session = await widget.auth.login(
        _email.text,
        _password.text,
      );

      _password.clear();

      if (mounted) {
        widget.onLogin(session);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (error.statusCode == 401) {
          _error = 'Nieprawidłowy e-mail lub hasło.';
        } else {
          _error = error.message;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Nie udało się połączyć z backendem.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    margin: const EdgeInsets.only(
                      bottom: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB85C3B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const Text(
                    'VedaSentio',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3A2A24),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  const Text(
                    'Bezpieczeństwo bliskich w jednym miejscu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF776A63),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(
                    height: 34,
                  ),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFF0E7DF),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Zaloguj się',
                            style: TextStyle(
                              color: Color(0xFF3A2A24),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          const Text(
                            'Uzyskaj dostęp do swoich gospodarstw i alarmów.',
                            style: TextStyle(
                              color: Color(0xFF81746C),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(
                            height: 22,
                          ),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: const Icon(
                                Icons.mail_outline,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9F4EE),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEDE2D8),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFB85C3B),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (value) {
                              String email = value?.trim() ?? '';

                              if (email.isEmpty) {
                                return 'Podaj e-mail.';
                              }

                              if (!email.contains('@')) {
                                return 'Niepoprawny e-mail.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Hasło',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9F4EE),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEDE2D8),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFB85C3B),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Podaj hasło.';
                              }

                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(
                              height: 14,
                            ),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0EE),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFD92D20),
                                    size: 20,
                                  ),
                                  const SizedBox(
                                    width: 9,
                                  ),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFF9F241B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(
                            height: 20,
                          ),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFB85C3B),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFD5B0A2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Zaloguj',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: Color(0xFF81746C),
                      ),
                      SizedBox(
                        width: 7,
                      ),
                      Flexible(
                        child: Text(
                          'Bezpieczna sesja i szyfrowane dane logowania',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF81746C),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
