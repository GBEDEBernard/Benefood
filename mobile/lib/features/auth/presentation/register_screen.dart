import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
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
  bool _wantVendor = false;
  bool _wantDriver = false;

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

    final roles = <String>[
      'client',
      if (_wantVendor) 'vendor',
      if (_wantDriver) 'driver-independent',
    ];

    setState(() => _loading = true);
    try {
      await widget.session.register(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        password: _password.text,
        passwordConfirmation: _confirm.text,
        roles: roles,
      );
      if (mounted) {
        showToast(context, 'Compte créé. Bienvenue sur Béninfood !');
        context.go('/client');
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 24),
                Text('Je souhaite aussi :', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _RoleChip(
                  icon: Icons.storefront_outlined,
                  label: 'Ouvrir une boutique (Vendeur)',
                  selected: _wantVendor,
                  onChanged: (v) => setState(() => _wantVendor = v),
                ),
                const SizedBox(height: 8),
                _RoleChip(
                  icon: Icons.delivery_dining_outlined,
                  label: 'Livrer des commandes (Livreur)',
                  selected: _wantDriver,
                  onChanged: (v) => setState(() => _wantDriver = v),
                ),
                const SizedBox(height: 28),
                AppButton(label: 'Créer mon compte', onPressed: _submit, loading: _loading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? colorScheme.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}