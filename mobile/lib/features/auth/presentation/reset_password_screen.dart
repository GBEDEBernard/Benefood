import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/widgets/auth_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Réinitialisation de mot de passe en 2 étapes (J19 §2.5) :
/// 1. envoi du code (`/auth/forgot-password`)
/// 2. saisie du code + nouveau mot de passe (`/auth/reset-password`)
///
/// Design : en-tête orange compact (titre en blanc) + panneau blanc, même
/// kit visuel que la connexion et l'inscription. Page fixe, jamais de scroll.
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
    if (_loading) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (_login.text.trim().isEmpty) {
      _formKey.currentState!.validate();
      return;
    }
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
    if (_loading) {
      return;
    }
    FocusScope.of(context).unfocus();
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
    return AuthScaffold(
      title: context.tr('Mot de passe oublié'),
      subtitle: context.tr('Recevez un code et récupérez votre compte.'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_stepCode) ...[
                AuthField(
                  controller: _login,
                  label: context.tr('Téléphone ou email'),
                  hint: context.tr('Votre numéro ou votre email'),
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.tr('Requis')
                      : null,
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: context.tr('Envoyer le code'),
                  icon: Icons.send_outlined,
                  loading: _loading,
                  onPressed: _requestCode,
                ),
                const SizedBox(height: 22),
                const AuthSecureNote(),
              ] else ...[
                AuthField(
                  controller: _code,
                  label: context.tr('Code de réinitialisation'),
                  hint: context.tr('6 chiffres'),
                  icon: Icons.verified_outlined,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().length < 6)
                      ? context.tr('Code de 6 chiffres')
                      : null,
                ),
                const SizedBox(height: 16),
                AuthField(
                  controller: _password,
                  label: context.tr('Nouveau mot de passe'),
                  hint: context.tr('Au moins 8 caractères'),
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => (v == null || v.length < 8)
                      ? context.tr('Au moins 8 caractères')
                      : null,
                ),
                const SizedBox(height: 16),
                AuthField(
                  controller: _confirm,
                  label: context.tr('Confirmer'),
                  hint: context.tr('Retapez le nouveau mot de passe'),
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _reset(),
                  validator: (v) => v == _password.text
                      ? null
                      : context.tr('Les mots de passe diffèrent'),
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: context.tr('Réinitialiser'),
                  icon: Icons.check_circle_outline,
                  loading: _loading,
                  onPressed: _reset,
                ),
                const SizedBox(height: 22),
                const AuthSecureNote(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}