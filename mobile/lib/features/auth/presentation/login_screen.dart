import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/auth_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Connexion (J19 §2.3) : téléphone OU email + mot de passe.
///
/// Design : bandeau orange dégradé, grand bol de légumes qui déborde sur le
/// panneau blanc, formulaire épuré, rappel COMMANDEZ / PAYEZ / RECEVEZ.
/// Page fixe, partagée avec l'inscription via le kit `auth_kit.dart`.
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
      await widget.session.login(_login.text.trim(), _password.text);
      if (mounted) {
        final role = widget.session.activeRole;
        context.go(role == null ? '/context' : switch (role) {
          AppContext.vendor => '/vendor',
          AppContext.driver => '/driver',
          _ => '/client',
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.isUnauthorized) {
          showToast(context, 'Identifiants invalides.', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      hero: true,
      title: 'Bon retour !',
      subtitle: 'Connectez-vous pour continuer vos achats.',
      onBack: _back,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                controller: _login,
                label: 'Téléphone ou email',
                hint: 'Votre numéro ou votre email',
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _password,
                label: 'Mot de passe',
                hint: 'Votre mot de passe',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/reset-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: AuthColors.brand,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AuthPrimaryButton(
                label: 'Se connecter',
                icon: Icons.login_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 34),
              const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDF0)),
              const SizedBox(height: 22),
              const AuthPromises(),
              const SizedBox(height: 26),
              const AuthSecureNote(),
            ],
          ),
        ),
      ),
    );
  }
}