import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Connexion (J19 §2.3) : téléphone OU email + mot de passe.
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

  Future<void> _submit() async {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/Logo.jpeg',
                  width: 84,
                  height: 84,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.storefront, size: 72, color: AppColors.green),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Bon retour !',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Connectez-vous pour continuer vos achats.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _login,
                    label: 'Téléphone ou email',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _password,
                    label: 'Mot de passe',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Se connecter',
                    icon: Icons.login,
                    onPressed: _submit,
                    loading: _loading,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/reset-password'),
                    child: const Text('Mot de passe oublié ?'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Pas encore de compte ?',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => context.go('/register'),
                        child: const Text('Inscrivez-vous'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}