import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/auth_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/social_auth_buttons.dart';

/// Connexion : Google, Facebook, LinkedIn ou e-mail / téléphone + mot de passe.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final SessionProvider session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(kLandingRoute);
    }
  }

  void _goAfterAuth() {
    if (!mounted) {
      return;
    }
    final role = widget.session.activeRole;
    context.go(
      role == null
          ? '/context'
          : switch (role) {
              AppContext.vendor => '/vendor',
              AppContext.driver => '/driver',
              _ => '/client',
            },
    );
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await widget.session.login(_login.text.trim(), _password.text);
      if (!mounted) {
        return;
      }
      if (result.requiresTwoFactor) {
        await _handleTwoFactor(result);
        return;
      }
      _goAfterAuth();
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isUnauthorized) {
          showToast(context, context.tr('Identifiants invalides.'), isError: true);
        } else if (e.fieldErrors.isNotEmpty) {
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

  Future<void> _handleTwoFactor(LoginResult challenge) async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _TwoFactorDialog(debugCode: challenge.debugCode),
    );
    if (code == null || code.trim().isEmpty || !mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.session.verifyTwoFactor(
        challengeToken: challenge.challengeToken ?? '',
        code: code.trim(),
      );
      _goAfterAuth();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message.isNotEmpty ? e.message : 'Code invalide ou expiré.', isError: true);
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
      hero: false,
      title: context.tr('Bienvenue !'),
      subtitle: context.tr('Connectez-vous à votre compte'),
      onBack: _back,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SocialAuthSection(
                session: widget.session,
                mode: SocialAuthMode.login,
                compact: true,
                onSuccess: _goAfterAuth,
              ),
              const SizedBox(height: 14),
              AuthField(
                controller: _login,
                label: context.tr('Adresse e-mail ou téléphone'),
                hint: context.tr('Votre e-mail ou numéro'),
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Requis') : null,
              ),
              const SizedBox(height: 12),
              AuthField(
                controller: _password,
                label: context.tr('Mot de passe'),
                hint: context.tr('Votre mot de passe'),
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.isEmpty) ? context.tr('Requis') : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/reset-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: AuthColors.brand,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.tr('Mot de passe oublié ?'),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AuthPrimaryButton(
                label: context.tr('Se connecter'),
                icon: Icons.login_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    context.tr('Vous n’avez pas encore de compte ? '),
                    style: const TextStyle(fontSize: 13.5, color: AuthColors.muted),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/register'),
                    child: Text(
                      context.tr('Créer un compte'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AuthColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const AuthSecureNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoFactorDialog extends StatefulWidget {
  const _TwoFactorDialog({this.debugCode});
  final String? debugCode;

  @override
  State<_TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<_TwoFactorDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vérification en deux étapes'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Saisissez le code de vérification envoyé pour sécuriser votre connexion.'),
          if (widget.debugCode != null && widget.debugCode!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Code (dev) : ${widget.debugCode}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Code à 6 chiffres', counterText: ''),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Vérifier'),
        ),
      ],
    );
  }
}