import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Inscription vendeur (J46) : formulaire boutique, photos et documents.
///
/// Démo sandbox : sans bibliothèque de fichiers, les documents sont générés
/// comme PDF d'exemple (quelques octets) et envoyés via `uploadVendorDocument`.
class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  static const _docTypes = <(String, String)>[
    ('ifu', 'IFU'),
    ('business_registration', 'Registre de commerce / Patente'),
    ('id_card', 'Pièce d\'identité'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _legalName = TextEditingController();
  final _ifu = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final Set<String> _uploadedTypes = {};
  String? _uploadingType;
  bool _submitting = false;

  Uint8List? _logoBytes;
  Uint8List? _coverBytes;
  bool _pickingPhoto = false;

  @override
  void dispose() {
    _businessName.dispose();
    _legalName.dispose();
    _ifu.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _city.dispose();
    _address.dispose();
    super.dispose();
  }

  List<int> _placeholderPdf() {
    const header = <int>[
      0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25,
      0xE2, 0xE3, 0xCF, 0xD3, 0x0A,
    ];
    return [...header, ...List<int>.filled(100 - header.length, 0x20)];
  }

  Future<void> _uploadDocument(String type, String label) async {
    if (_uploadedTypes.contains(type) || _uploadingType != null) {
      return;
    }
    setState(() => _uploadingType = type);
    try {
      await widget.marketplace.uploadVendorDocument(type, _placeholderPdf(), fileName: '$type.pdf');
      if (mounted) {
        setState(() => _uploadedTypes.add(type));
        showToast(context, '$label envoyé (démo).');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingType = null);
      }
    }
  }

  Future<void> _pickPhoto({required bool isLogo}) async {
    setState(() => _pickingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file == null || !mounted) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        if (isLogo) {
          _logoBytes = bytes;
        } else {
          _coverBytes = bytes;
        }
      });
    } catch (_) {
      if (mounted) {
        showToast(context, 'Impossible de charger l\'image.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _pickingPhoto = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      try {
        await widget.marketplace.vendorOnboarding(
          businessName: _businessName.text.trim(),
          legalName: _legalName.text.trim().isEmpty ? null : _legalName.text.trim(),
          ifu: _ifu.text.trim().isEmpty ? null : _ifu.text.trim(),
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        );
      } on ApiException catch (e) {
        if (!e.isConflict) {
          rethrow;
        }
      }

      for (final (type, label) in _docTypes) {
        if (!_uploadedTypes.contains(type)) {
          await widget.marketplace.uploadVendorDocument(type, _placeholderPdf(), fileName: '$type.pdf');
          _uploadedTypes.add(type);
        }
        if (mounted && (type == 'ifu' || type == 'business_registration')) {
          showToast(context, '$label envoyé (démo).');
        }
      }

      if (_logoBytes != null || _coverBytes != null) {
        await widget.marketplace.updateVendorMedia(
          logo: _logoBytes,
          cover: _coverBytes,
        );
      }

      if (mounted) {
        showToast(context, 'Dossier soumis. Merci !');
        Navigator.of(context).pop(true);
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
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription vendeur')),
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
                  controller: _businessName,
                  label: 'Nom de la boutique',
                  icon: Icons.storefront_outlined,
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
                  controller: _legalName,
                  label: 'Raison sociale',
                  icon: Icons.business_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _ifu,
                  label: 'IFU',
                  icon: Icons.numbers_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _description,
                  label: 'Description',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
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
                  controller: _city,
                  label: 'Ville',
                  icon: Icons.location_city_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _address,
                  label: 'Adresse',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 24),
                Text('Photos de la boutique', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Ajoutez un logo et une photo de couverture pour votre fiche boutique.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                _buildPhotoTile(
                  title: 'Logo',
                  bytes: _logoBytes,
                  onPick: () => _pickPhoto(isLogo: true),
                  onRemove: () => setState(() => _logoBytes = null),
                ),
                const SizedBox(height: 12),
                _buildPhotoTile(
                  title: 'Couverture',
                  bytes: _coverBytes,
                  onPick: () => _pickPhoto(isLogo: false),
                  onRemove: () => setState(() => _coverBytes = null),
                ),
                const SizedBox(height: 24),
                Text('Documents justificatifs', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Démo : un document PDF d\'exemple est généré automatiquement.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (final (type, label) in _docTypes) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _uploadedTypes.contains(type) ? Icons.check_circle : Icons.description_outlined,
                            color: _uploadedTypes.contains(type) ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  _uploadedTypes.contains(type) ? 'Document transmis' : 'À fournir',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: _uploadedTypes.contains(type)
                                            ? Colors.green
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (_uploadingType == type)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          else if (!_uploadedTypes.contains(type))
                            TextButton(
                              onPressed: () => _uploadDocument(type, label),
                              child: const Text('Ajouter'),
                            )
                          else
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _uploadedTypes.remove(type)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: 'Soumettre le dossier',
                  icon: Icons.send_outlined,
                  onPressed: _submitting ? null : _submit,
                  loading: _submitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTile({
    required String title,
    required Uint8List? bytes,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final preview = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover)
        : Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(Icons.storefront, size: 32, color: theme.colorScheme.outline),
            ),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: preview,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _pickingPhoto
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_library_outlined),
                    label: Text(bytes != null ? 'Changer la photo' : 'Ajouter une photo'),
                    onPressed: _pickingPhoto ? null : onPick,
                  ),
                ),
                if (bytes != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Retirer la photo',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _pickingPhoto ? null : onRemove,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}