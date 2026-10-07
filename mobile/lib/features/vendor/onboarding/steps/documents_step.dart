import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/upload_card.dart';

/// Les trois documents requis, dans l'ordre du parcours.
/// Partagé avec le contrôleur (types d'envoi et reprise du dossier).
typedef OnboardingDocument = (String type, String title, String subtitle, IconData icon);

const List<OnboardingDocument> kOnboardingDocumentTypes = [
  (
    'id_card',
    'Pièce d\u2019identité',
    'Recto verso, JPG ou PNG',
    Icons.badge_outlined,
  ),
  (
    'business_registration',
    'Registre de commerce',
    'PDF ou image',
    Icons.assignment_outlined,
  ),
  (
    'store_photo',
    'Photo de la boutique',
    'Image de la façade',
    Icons.storefront_outlined,
  ),
];

/// Étape 2/4 — Documents requis : trois cartes de téléchargement
/// (aperçu + coche verte quand le fichier est envoyé).
class DocumentsStep extends StatelessWidget {
  const DocumentsStep({
    super.key,
    required this.previews,
    required this.uploadedTypes,
    required this.uploadingType,
    required this.onPick,
  });

  /// Aperçus locaux des images déjà envoyées (par type de document).
  final Map<String, Uint8List?> previews;

  /// Types de documents envoyés avec succès.
  final Set<String> uploadedTypes;

  /// Type en cours d'envoi (spinner), le cas échéant.
  final String? uploadingType;

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (type, title, subtitle, icon) in kOnboardingDocumentTypes) ...[
          UploadCard(
            title: title,
            subtitle: uploadedTypes.contains(type) ? 'Document transmis' : subtitle,
            icon: icon,
            preview: previews[type],
            uploaded: uploadedTypes.contains(type),
            uploading: uploadingType == type,
            onTap: () => onPick(type),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Tous les documents sont obligatoires pour la vérification '
          'de votre compte.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
        ),
      ],
    );
  }
}
