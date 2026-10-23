import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/auth_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Inscription (J19 §2.4) : coordonnées sur 1 écran, envoi direct (OTP
/// simplifié côté mobile : le rôle client est créé via POST /auth/register).
///
/// Design : en-tête orange compact (titre en blanc) + panneau blanc, mêmes
/// champs et même bouton que la connexion.
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

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Indiquez votre email';
    }
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email);
    return valid ? null : 'Adresse email invalide';
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
      await widget.session.register(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
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
    return AuthScaffold(
      title: 'Créer un compte',
      subtitle: 'Rejoignez Béninfood en quelques secondes.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                controller: _name,
                label: 'Nom complet',
                hint: 'Votre nom et prénom',
                icon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _phone,
                label: 'Téléphone',
                hint: '+229 XX XX XX XX',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Requis';
                  }
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  return digits.length >= 8 ? null : 'Numéro invalide';
                },
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _email,
                label: 'Email',
                hint: 'nom@exemple.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _emailValidator,
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _password,
                label: 'Mot de passe',
                hint: 'Au moins 8 caractères',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => (v == null || v.length < 8)
                    ? 'Au moins 8 caractères'
                    : null,
              ),
              _PasswordMeter(controller: _password),
              const SizedBox(height: 16),
              AuthField(
                controller: _confirm,
                label: 'Confirmer le mot de passe',
                hint: 'Retapez votre mot de passe',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                validator: (v) =>
                    v == _password.text ? null : 'Les mots de passe diffèrent',
              ),
              const SizedBox(height: 28),
              AuthPrimaryButton(
                label: 'Créer mon compte',
                icon: Icons.person_add_alt_1_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 14),
              const Text(
                'Vous choisirez ensuite le type de compte à créer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AuthColors.muted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 22),
              const AuthSecureNote(text: 'Vos informations restent privées'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jauge de robustesse du mot de passe (affichage seulement : la règle
/// de validation reste « au moins 8 caractères »).
class _PasswordMeter extends StatelessWidget {
  const _PasswordMeter({required this.controller});

  final TextEditingController controller;

  static int _score(String p) {
    var s = 0;
    if (p.length >= 8) {
      s++;
    }
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) {
      s++;
    }
    if (RegExp(r'\d').hasMatch(p)) {
      s++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) {
      s++;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text;
        Widget content = const SizedBox(width: double.infinity);
        if (text.isNotEmpty) {
          final score = _score(text);
          const colors = [
            AuthColors.danger,
            AuthColors.danger,
            Color(0xFFF2A100),
            Color(0xFF7CB342),
            Color(0xFF2E9E5B),
          ];
          const labels = ['Faible', 'Faible', 'Moyen', 'Bon', 'Très fort'];
          final color = colors[score];
          content = Padding(
            padding: const EdgeInsets.only(top: 10, left: 2),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < score ? color : const Color(0xFFE8E8EC),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (i < 3) const SizedBox(width: 6),
                ],
                const SizedBox(width: 12),
                SizedBox(
                  width: 62,
                  child: Text(
                    labels[score],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: content,
        );
      },
    );
  }
}
