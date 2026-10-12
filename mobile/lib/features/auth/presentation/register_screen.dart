import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/auth_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Inscription (J19 §2.4) : coordonnées sur 1 écran, envoi direct (OTP
/// simplifié côté mobile : le rôle client est créé via POST /auth/register).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.session.register(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        password: _password.text,
        passwordConfirmation: _confirm.text,
      );
      if (mounted) {
        showToast(context, 'Compte créé. Bienvenue sur Béninfood !');
        context.go('/choose-account');
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.fieldErrors.isNotEmpty) {
          showToast(context, e.fieldErrors.values.first.first, isError: true);
        } else {
          showToast(context, e.message, isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthHeader(
                  title: 'Créer un compte',
                  subtitle: 'Rejoignez Béninfood en quelques secondes.',
                ),
                AppTextField(
                  controller: _name,
                  label: 'Nom complet',
                  icon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _phone,
                  label: 'Téléphone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  hint: '+229 XX XX XX XX',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Requis';
                    }
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    return digits.length >= 8 ? null : 'Numéro invalide';
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _password,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 8) ? 'Au moins 8 caractères' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _confirm,
                  label: 'Confirmer le mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: (v) => v == _password.text ? null : 'Les mots de passe diffèrent',
                ),
                const SizedBox(height: 28),
                AppButton(label: 'Créer mon compte', onPressed: _submit, loading: _loading),
                const SizedBox(height: 10),
                Text(
                  'Vous choisirez ensuite le type de compte à créer.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}