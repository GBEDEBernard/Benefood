import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';

/// Ouvre le composeur téléphonique sur [phone].
///
/// Retourne `false` si le numéro est vide ou si aucun appel ne peut être
/// lancé (aucune app téléphone sur l'appareil, par ex. sur desktop).
Future<bool> launchPhoneCall(String? phone) async {
  final raw = phone?.trim() ?? '';
  if (raw.isEmpty) {
    return false;
  }
  final uri = Uri(scheme: 'tel', path: raw);
  return launchUrl(uri);
}

/// Bouton plein « Appeler » premium (orange Béninfood) réutilisé partout :
/// client → livreur, livreur → client / vendeur.
class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.label,
    required this.phone,
    this.onEmptyPhone,
    this.compact = false,
  });

  /// Libellé du bouton (ex. « Appeler le livreur »).
  final String label;

  /// Numéro à composer ; si vide, [onEmptyPhone] est invoqué (toast).
  final String? phone;

  /// Callback quand le numéro est indisponible (message d'info).
  final VoidCallback? onEmptyPhone;

  /// Version compacte (rangée d'icônes).
  final bool compact;

  Future<void> _call() async {
    final ok = await launchPhoneCall(phone);
    if (!ok && onEmptyPhone != null) {
      onEmptyPhone!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    void showNoNumber() {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Numéro de téléphone indisponible.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    if (compact) {
      return _CallIconButton(
        tooltip: label,
        onPressed: () {
          if ((phone?.trim().isEmpty ?? true)) {
            showNoNumber();
          } else {
            _call();
          }
        },
      );
    }

    return FilledButton.icon(
      onPressed: () {
        if ((phone?.trim().isEmpty ?? true)) {
          showNoNumber();
        } else {
          _call();
        }
      },
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.call, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Pastille d'appel compacte (44×44) pour les rangées d'actions.
class _CallIconButton extends StatelessWidget {
  const _CallIconButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.call, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
