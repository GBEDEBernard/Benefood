import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/status_badge.dart';

/// Sélecteur d'images injectable pour les tests (caméra / galerie).
typedef DriverImagePicker = Future<Uint8List?> Function(ImageSource source);

/// Onboarding livreur : Bienvenue puis Documents (J10 §5.2).
///
/// Affiché à la place des missions tant que le profil n'est pas `active`.
/// L'inscription (véhicule) ouvre l'envoi des justificatifs ; l'activation
/// finale reste une validation administrative.
class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({
    super.key,
    required this.marketplace,
    required this.profile,
    required this.documents,
    required this.onRefresh,
    this.imagePicker,
  });

  final MarketplaceApi marketplace;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> documents;
  final Future<void> Function() onRefresh;
  final DriverImagePicker? imagePicker;

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  static const _docTypes = <(String, String)>[
    ('id_card', 'Pièce d\'identité'),
    ('driver_license', 'Permis de conduire'),
    ('vehicle_registration', 'Carte grise'),
    ('insurance', 'Assurance'),
    ('photo', 'Photo du livreur'),
  ];

  final PageController _pageController = PageController();
  final _vehicle = TextEditingController();
  bool _submitting = false;
  String? _uploadingType;

  final Map<String, Uint8List> _previews = {};
  final Set<String> _uploadedTypes = {};

  bool get _hasProfile => widget.profile != null;

  @override
  void initState() {
    super.initState();
    _restoreUploads();
  }

  @override
  void dispose() {
    _vehicle.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _restoreUploads() {
    final uploaded = widget.documents
        .map((doc) => doc['type'])
        .whereType<String>()
        .toList();
    _uploadedTypes.addAll(uploaded);
  }

  void _goTo(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<Uint8List?> _pickBytes(ImageSource source) async {
    final custom = widget.imagePicker;
    if (custom != null) {
      return await custom(source);
    }
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    return file?.readAsBytes();
  }

  Future<void> _submitVehicle() async {
    if (_vehicle.text.trim().isEmpty) {
      showToast(context, 'Indiquez votre type de véhicule.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      try {
        await widget.marketplace.driverOnboarding(vehicle: _vehicle.text.trim());
      } on ApiException catch (e) {
        if (!e.isConflict) {
          rethrow;
        }
      }
      await widget.onRefresh();
      if (mounted) {
        showToast(context, 'Inscription enregistrée.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _pickDocument(String type, String label) async {
    if (!_hasProfile || _uploadingType != null) {
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    setState(() => _uploadingType = type);
    try {
      final bytes = await _pickBytes(source);
      if (bytes == null) {
        return;
      }
      await widget.marketplace.uploadDriverDocument(type, bytes);
      await widget.onRefresh();
      if (mounted) {
        setState(() {
          _previews[type] = bytes;
          _uploadedTypes.add(type);
        });
        showToast(context, '$label transmis.');
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

  String _docLabel(String type) => _docTypes
      .firstWhere((entry) => entry.$1 == type, orElse: () => (type, type))
      .$2;

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _WelcomePage(onStart: () => _goTo(1)),
        _DocumentsPage(
          profile: widget.profile,
          documents: widget.documents,
          onRefresh: widget.onRefresh,
          vehicle: _vehicle,
          docTypes: _docTypes,
          hasProfile: _hasProfile,
          submitting: _submitting,
          uploadingType: _uploadingType,
          uploadedTypes: _uploadedTypes,
          previews: _previews,
          onSubmitVehicle: _submitVehicle,
          onPickDocument: _pickDocument,
          docLabel: _docLabel,
        ),
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onStart});

  final VoidCallback onStart;

  static const _benefits = [
    'Recevez des missions près de chez vous',
    'Gagnez selon vos disponibilités',
    'Aucun frais d\'inscription',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandLogo(size: 132)),
                const SizedBox(height: 20),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                    children: const [
                      TextSpan(text: 'Bienvenue chez '),
                      TextSpan(
                        text: 'Bénin',
                        style: TextStyle(color: AppColors.green),
                      ),
                      TextSpan(
                        text: 'food',
                        style: TextStyle(color: AppColors.orange),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Livrez des repas et des colis avec Béninfood.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                for (final benefit in _benefits) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 22,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 10),
                AppButton(label: 'Commencer', onPressed: onStart),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentsPage extends StatelessWidget {
  const _DocumentsPage({
    required this.profile,
    required this.documents,
    required this.onRefresh,
    required this.vehicle,
    required this.docTypes,
    required this.hasProfile,
    required this.submitting,
    required this.uploadingType,
    required this.uploadedTypes,
    required this.previews,
    required this.onSubmitVehicle,
    required this.onPickDocument,
    required this.docLabel,
  });

  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> documents;
  final Future<void> Function() onRefresh;
  final TextEditingController vehicle;
  final List<(String, String)> docTypes;
  final bool hasProfile;
  final bool submitting;
  final String? uploadingType;
  final Set<String> uploadedTypes;
  final Map<String, Uint8List> previews;
  final VoidCallback? onSubmitVehicle;
  final void Function(String type, String label) onPickDocument;
  final String Function(String type) docLabel;

  IconData _statusIcon(dynamic status) => switch (status) {
        'valid' => Icons.check_circle,
        'invalid' => Icons.cancel,
        _ => Icons.schedule,
      };

  Color _statusColor(dynamic status) => switch (status) {
        'valid' => Colors.green,
        'invalid' => Colors.red,
        _ => Colors.grey,
      };

  String _documentStatusLabel(dynamic status) => switch (status) {
        'valid' => 'Validé',
        'invalid' => 'Rejeté',
        _ => 'En vérification',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(context),
          const SizedBox(height: 16),
          Text('Inscription livreur', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Renseignez votre véhicule puis fournissez vos justificatifs pour '
            'être validé comme livreur Béninfood.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: vehicle,
            label: 'Véhicule',
            hint: 'Ex : Moto, voiture…',
            icon: Icons.two_wheeler_outlined,
            enabled: !hasProfile,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: hasProfile ? 'Inscription enregistrée' : 'Enregistrer mon inscription',
            icon: Icons.person_add_alt,
            enabled: !hasProfile,
            onPressed: onSubmitVehicle,
            loading: submitting,
          ),
          const SizedBox(height: 24),
          Text('Documents justificatifs', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            hasProfile ? 'Photo ou numérisation, format JPG ou PNG.' : 'Enregistrez d\'abord votre inscription pour envoyer vos documents.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final (type, label) in docTypes) ...[
            _DocumentTile(
              title: label,
              done: uploadedTypes.contains(type),
              preview: previews[type],
              uploading: uploadingType == type,
              enabled: hasProfile && uploadingType == null,
              onPick: () => onPickDocument(type, label),
            ),
            const SizedBox(height: 8),
          ],
          if (documents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Documents transmis', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: documents.map((doc) {
                  final docStatus = doc['status'];
                  final reason = doc['reason'];
                  return ListTile(
                    leading: Icon(_statusIcon(docStatus), color: _statusColor(docStatus)),
                    title: Text(docLabel(doc['type'] is String ? doc['type'] as String : '')),
                    subtitle: Text([
                      _documentStatusLabel(docStatus),
                      if (reason is String && reason.isNotEmpty) ' · $reason',
                    ].join()),
                    trailing: Text(
                      formatDate(doc['created_at'] is String ? doc['created_at'] as String : null, fallback: ''),
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Rafraîchir',
            variant: AppButtonVariant.outline,
            icon: Icons.refresh,
            onPressed: () => onRefresh(),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final theme = Theme.of(context);
    final rawStatus = profile?['status'];
    final status = rawStatus is String ? rawStatus : null;
    final palette = BadgePalette.driver(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.delivery_dining, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Espace livreur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  if (palette != null)
                    StatusBadge(label: palette.$1, color: palette.$2)
                  else
                    const StatusBadge(label: 'Inscription à compléter', color: Colors.blueGrey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.title,
    required this.done,
    required this.preview,
    required this.uploading,
    required this.enabled,
    required this.onPick,
  });

  final String title;
  final bool done;
  final Uint8List? preview;
  final bool uploading;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    done ? 'Document transmis' : 'Format JPG ou PNG',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: done ? AppColors.green : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (uploading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else if (done && preview != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(preview!, width: 36, height: 36, fit: BoxFit.cover),
              )
            else if (done)
              const Icon(Icons.check_circle, color: AppColors.green, size: 26)
            else
              TextButton(onPressed: enabled ? onPick : null, child: const Text('Ajouter')),
          ],
        ),
      ),
    );
  }
}