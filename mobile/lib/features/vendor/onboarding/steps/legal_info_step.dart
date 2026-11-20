import 'package:flutter/material.dart';

import '../../../../core/data/marketplace_api.dart';
import '../../../../shared/widgets/city_area_picker.dart';
import '../widgets/custom_text_field.dart';
import '../../../../core/i18n/app_localizations.dart';

/// Étape 1/4 — Informations légales : raison sociale, IFU, téléphone,
/// email, ville/quartier et adresse complète de l'entreprise.
class LegalInfoStep extends StatelessWidget {
  const LegalInfoStep({
    super.key,
    required this.marketplace,
    required this.formKey,
    required this.raisonSociale,
    required this.ifu,
    required this.phone,
    required this.email,
    required this.city,
    required this.area,
    required this.adresse,
    this.onGeoChanged,
  });

  final MarketplaceApi marketplace;
  final GlobalKey<FormState> formKey;
  final TextEditingController raisonSociale;
  final TextEditingController ifu;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController city;
  final TextEditingController area;
  final TextEditingController adresse;
  final ValueChanged<CityAreaSelection>? onGeoChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: context.tr('Raison sociale'),
            required: true,
            controller: raisonSociale,
            hint: 'Le Délice Fast-Food',
            textInputAction: TextInputAction.next,
            validator: (v) => _required(v, 'Indiquez la raison sociale'),
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: context.tr('Numéro IFU'),
            required: true,
            controller: ifu,
            hint: '4202012345678',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: _ifuValidator,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: context.tr('Téléphone'),
            required: true,
            controller: phone,
            hint: '+229 97 12 34 56',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _phoneValidator,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: context.tr('Email'),
            required: true,
            controller: email,
            hint: 'contact@ledelice.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _emailValidator,
          ),
          const SizedBox(height: 14),
          CityAreaPickerField(
            marketplace: marketplace,
            cityController: city,
            areaController: area,
            onChanged: onGeoChanged,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: context.tr('Adresse complète'),
            required: true,
            controller: adresse,
            hint: 'Numéro, rue, repère près de votre boutique',
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
