import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/images/logo.svg',
        height: size,
        // El SVG original es blanco: se tiñe con el color primario del tema.
        colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
      );
}

String _authError(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Email o contraseña incorrectos',
      'email-already-in-use' => 'Ese email ya está registrado',
      'weak-password' => 'La contraseña debe tener al menos 6 caracteres',
      'invalid-email' => 'Email inválido',
      _ => e.message ?? 'Error de autenticación',
    };
  }
  return '$e';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _nombre = TextEditingController();
  final _apodo = TextEditingController();
  bool _registro = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final s = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registro) {
        if (_nombre.text.trim().isEmpty) throw 'Ingresá tu nombre';
        await s.register(
            email: _email.text, pass: _pass.text, nombre: _nombre.text, apodo: _apodo.text);
      } else {
        await s.login(_email.text, _pass.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const Logo(size: 96),
                  const SizedBox(height: 20),
                  Text('2214', style: t.textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text('Jazit Hanoar',
                      style: t.textTheme.bodyMedium
                          ?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 36),
                  if (_registro) ...[
                    TextField(
                        controller: _nombre,
                        decoration: const InputDecoration(labelText: 'Nombre')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _apodo,
                        decoration: const InputDecoration(labelText: 'Apodo')),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_registro ? 'Crear cuenta' : 'Ingresar'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _registro = !_registro),
                    child: Text(_registro ? 'Ya tengo cuenta' : 'Crear una cuenta'),
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

/// Cuenta creada pero todavía no aprobada por la Hanagá.
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Logo(size: 72),
                const SizedBox(height: 24),
                Text('Cuenta pendiente', style: t.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'La Hanagá tiene que aprobar tu cuenta y asignarte tu kuvthzá. '
                  'Cuando lo haga, vas a entrar automáticamente.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                    onPressed: () => context.read<AppState>().logout(),
                    child: const Text('Cerrar sesión')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
