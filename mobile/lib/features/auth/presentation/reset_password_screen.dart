import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Réinitialisation de mot de passe en 2 étapes (J19 §2.5) :
/// 1. envoi du code (`/auth/forgot-password`)
/// 2. saisie du code + nouveau mot de passe (`/auth/reset-password`)
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _stepCode = false;
  bool _loading = false;

  @override
  void dispose() {
    _login.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() => _loading = true);
    try {
      await widget.session.forgotPassword(_login.text.trim());
      if (mounted) {
        setState(() => _stepCode = true);
        _code.text = '';
        showToast(context, 'Un code de réinitialisation a été envoyé.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.session.resetPassword(
        login: _login.text.trim(),
        code: _code.text.trim(),
        password: _password.text,
        passwordConfirmation: _confirm.text,
      );
      if (mounted) {
        showToast(context, 'Mot de passe réinitialisé, connectez-vous.');
        context.go('/login');
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
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                if (!_stepCode) ...[
                  AppTextField(
                    controller: _login,
                    label: 'Téléphone ou email',
                    icon: Icons.person_outline,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 24),
                  AppButton(label: 'Envoyer le code', onPressed: _requestCode, loading: _loading),
                ] else ...[
                  AppTextField(
                    controller: _code,
                    label: 'Code de réinitialisation',
                    icon: Icons.verified_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.trim().length < 6) ? 'Code de 6 chiffres' : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _password,
                    label: 'Nouveau mot de passe',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 8) ? 'Au moins 8 caractères' : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _confirm,
                    label: 'Confirmer',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (v) => v == _password.text ? null : 'Les mots de passe diffèrent',
                  ),
                  const SizedBox(height: 24),
                  AppButton(label: 'Réinitialiser', onPressed: _reset, loading: _loading),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}