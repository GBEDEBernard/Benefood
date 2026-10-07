import 'package:flutter/material.dart';

import '../widgets/custom_text_field.dart';

/// Étape 1/4 — Informations légales : raison sociale, IFU, téléphone,
/// email et adresse complète de l'entreprise.
class LegalInfoStep extends StatelessWidget {
  const LegalInfoStep({
    super.key,
    required this.formKey,
    required this.raisonSociale,
    required this.ifu,
    required this.phone,
    required this.email,
    required this.adresse,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController raisonSociale;
  final TextEditingController ifu;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController adresse;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: 'Raison sociale',
            required: true,
            controller: raisonSociale,
            hint: 'Le Délice Fast-Food',
            textInputAction: TextInputAction.next,
            validator: (v) => _required(v, 'Indiquez la raison sociale'),
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Numéro IFU',
            required: true,
            controller: ifu,
            hint: '4202012345678',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: _ifuValidator,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Téléphone',
            required: true,
            controller: phone,
            hint: '+229 97 12 34 56',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _phoneValidator,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Email',
            required: true,
            controller: email,
            hint: 'contact@ledelice.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _emailValidator,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Adresse complète',
            required: true,
            controller: adresse,
            hint: 'Cadjèhoun, Cotonou, Bénin',
            maxLines: 3,
            validator: (v) => _required(v, 'Indiquez l\u2019adresse de la boutique'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  String? _ifuValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Indiquez le numéro IFU';
    }
    return RegExp(r'^[0-9]+$').hasMatch(value.trim())
        ? null
        : 'IFU invalide (chiffres uniquement)';
  }

  /// Reprend la regex backend : indicatif 229 facultatif, 8 chiffres locaux.
  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Indiquez le numéro de téléphone';
    }
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00229')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('229')) {
      digits = digits.substring(3);
    }
    return RegExp(r'^0?1?[0-9]{8}$').hasMatch(digits)
        ? null
        : 'Numéro invalide (8 chiffres)';
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Indiquez l\u2019adresse email';
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
        ? null
        : 'Adresse email invalide';
  }
}
