import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/city_area_picker.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Sélecteur d'images injectable (tests).
typedef ClientImagePicker = Future<Uint8List?> Function(ImageSource source);

typedef _ClientDoc = (String type, String title, String subtitle, IconData icon);

/// Onboarding du compte client (J19) : écran de bienvenue puis dossier
/// d'identification (coordonnées + carte CIP/biométrique + domicile).
///
/// Le compte reste bloqué tant que le dossier n'a pas été complété.
class ClientOnboardingScreen extends StatefulWidget {
  const ClientOnboardingScreen({
    super.key,
    required this.marketplace,
    required this.user,
    this.imagePicker,
    this.onCompleted,
  });

  final MarketplaceApi marketplace;
  final User? user;
  final ClientImagePicker? imagePicker;

  /// Appelé lorsque le dossier est complété. Si `null`, l'écran se ferme par
  /// `Navigator.pop(true)`.
  final VoidCallback? onCompleted;

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> {
  static const List<_ClientDoc> _docTypes = [
    ('id_card', 'Carte CIP ou biométrique', 'Recto/verso, photo nette', Icons.badge_outlined),
    ('proof_of_address', 'Justificatif de domicile', 'Facture, quittance ou attestation', Icons.home_work_outlined),
    ('selfie', 'Photo du titulaire (optionnel)', 'Un selfie récent', Icons.account_circle_outlined),
  ];

  static const List<String> _requiredTypes = ['id_card', 'proof_of_address'];

  final PageController _pageController = PageController();

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();

  bool _profileCreated = false;
  bool _submitting = false;
  String? _uploadingType;
  bool _navigated = false;
  final Map<String, Uint8List?> _previews = {};

  @override
  void initState() {
    super.initState();
    _name.text = widget.user?.name ?? '';
    _phone.text = widget.user?.phone ?? '';
    _restore();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _area.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final status = await widget.marketplace.clientStatus();
      if (!mounted) {
        return;
      }
      final profile = status['profile'];
      final documents = status['documents'];
      final uploaded = <String>{};
      if (documents is List) {
        for (final raw in documents) {
          if (raw is Map<String, dynamic> && raw['type'] is String) {
            uploaded.add(raw['type'] as String);
          }
        }
      }
      if (profile is Map<String, dynamic>) {
        _name.text = (profile['full_name'] as String?)?.isNotEmpty == true
            ? profile['full_name'] as String
            : _name.text;
        _phone.text = (profile['phone'] as String?)?.isNotEmpty == true
            ? profile['phone'] as String
            : _phone.text;
        _city.text = profile['city'] as String? ?? '';
        _area.text = profile['area'] as String? ?? '';
        _address.text = profile['address'] as String? ?? '';
        _profileCreated = true;
      }
      setState(() => _uploadedTypes.addAll(uploaded));
      // Dossier déjà commencé (montage de l'écran) : on reprend directement
      // sur la page des documents au lieu de repasser par la bienvenue.
      if (_profileCreated && !_navigated) {
        _navigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(1);
          }
        });
      }
    } on ApiException {
      // Pas encore de dossier : premier passage.
    }
  }

  final Set<String> _uploadedTypes = {};

  // ---------------------------------------------------------------- navigation

  void _goTo(int step) {
    _navigated = true;
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // ---------------------------------------------------------------- images

  Future<ImageSource?> _askImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 18, 24, 6),
              child: Text('Ajouter un document',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.orange),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.orange),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              title: const Text('Annuler', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _readImage(ImageSource source) async {
    final custom = widget.imagePicker;
    if (custom != null) {
      return await custom(source);
    }
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
      return await file?.readAsBytes();
    } catch (_) {
      if (mounted) {
        showToast(context, "Impossible de charger l'image.", isError: true);
      }
      return null;
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    if (error is ApiException && error.fieldErrors.isNotEmpty) {
      showToast(context, error.fieldErrors.values.first.first, isError: true);
    } else if (error is ApiException) {
      showToast(context, error.message, isError: true);
    } else {
      showToast(context, 'Une erreur est survenue. Réessayez.', isError: true);
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> _createProfile() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      showToast(context, 'Renseignez votre nom et votre téléphone.', isError: true);
      return;
    }
    if (_address.text.trim().isEmpty || _city.text.trim().isEmpty) {
      showToast(context, 'Renseignez votre ville et votre adresse.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.marketplace.clientOnboarding(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        city: _city.text.trim(),
        area: _area.text.trim(),
      );
      if (mounted) {
        setState(() => _profileCreated = true);
        showToast(context, 'Informations enregistrées. Ajoutez vos documents.');
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _pickDocument(String type) async {
    if (_uploadingType != null) {
      return;
    }
    if (!_profileCreated) {
      showToast(context, "Enregistrez d'abord vos informations.", isError: true);
      return;
    }
    final source = await _askImageSource();
    if (source == null || !mounted) {
      return;
    }
    final bytes = await _readImage(source);
    if (bytes == null || !mounted) {
      return;
    }

    setState(() => _uploadingType = type);
    try {
      await widget.marketplace.uploadClientDocument(type, bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _uploadedTypes.add(type);
        _previews[type] = bytes;
      });
      showToast(context, 'Document envoyé.');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _uploadingType = null);
      }
    }
  }

  Future<void> _finish() async {
    final missing =
        _requiredTypes.where((type) => !_uploadedTypes.contains(type)).length;
    if (missing > 0) {
      showToast(
        context,
        missing == 1
            ? 'Envoyez le document restant.'
            : 'Envoyez les $missing documents restants.',
        isError: true,
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BeninfoodAppBar(api: widget.marketplace),
            Expanded(
              child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _WelcomePage(onStart: () => _goTo(1)),
            _DocumentsPage(
              marketplace: widget.marketplace,
              name: _name,
              phone: _phone,
              city: _city,
              area: _area,
              address: _address,
              profileCreated: _profileCreated,
              submitting: _submitting,
              uploadingType: _uploadingType,
              uploadedTypes: _uploadedTypes,
              previews: _previews,
              docTypes: _docTypes,
              requiredTypes: _requiredTypes,
              onBack: () => _goTo(0),
              onCreateProfile: _createProfile,
              onPickDocument: _pickDocument,
              onFinish: _finish,
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

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onStart});

  final VoidCallback onStart;

  static const _benefits = [
    'Commandez auprès des meilleurs vendeurs',
    'Faites-vous livrer à domicile',
    'Envoyez vos colis en toute confiance',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      const Center(child: BrandLogo(size: 120)),
                      const SizedBox(height: 24),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                          children: const [
                            TextSpan(text: 'Bienvenue chez '),
                            TextSpan(text: 'Bénin', style: TextStyle(color: AppColors.green)),
                            TextSpan(text: 'food', style: TextStyle(color: AppColors.orange)),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Activez votre compte client pour commander et envoyer '
                        'vos colis partout au Bénin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (final benefit in _benefits) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 22, color: AppColors.green),
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
                      const Spacer(flex: 3),
                      AppButton(
                        label: 'Commencer',
                        icon: Icons.arrow_forward,
                        onPressed: onStart,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentsPage extends StatelessWidget {
  const _DocumentsPage({
    required this.marketplace,
    required this.name,
    required this.phone,
    required this.city,
    required this.area,
    required this.address,
    required this.profileCreated,
    required this.submitting,
    required this.uploadingType,
    required this.uploadedTypes,
    required this.previews,
    required this.docTypes,
    required this.requiredTypes,
    required this.onBack,
    required this.onCreateProfile,
    required this.onPickDocument,
    required this.onFinish,
  });

  final MarketplaceApi marketplace;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController city;
  final TextEditingController area;
  final TextEditingController address;
  final bool profileCreated;
  final bool submitting;
  final String? uploadingType;
  final Set<String> uploadedTypes;
  final Map<String, Uint8List?> previews;
  final List<_ClientDoc> docTypes;
  final List<String> requiredTypes;
  final VoidCallback onBack;
  final VoidCallback onCreateProfile;
  final ValueChanged<String> onPickDocument;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allRequiredDone =
        requiredTypes.every((type) => uploadedTypes.contains(type));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const Expanded(
                child: Text(
                  'Activation du compte',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text('Vos informations', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              AppTextField(
                controller: name,
                label: 'Nom complet',
                icon: Icons.person_outline,
                enabled: !profileCreated,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: phone,
                label: 'Téléphone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                enabled: !profileCreated,
              ),
              const SizedBox(height: 12),
              CityAreaPickerField(
                marketplace: marketplace,
                cityController: city,
                areaController: area,
                enabled: !profileCreated,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: address,
                label: 'Adresse (domicile)',
                icon: Icons.home_outlined,
                enabled: !profileCreated,
              ),
              const SizedBox(height: 16),
              if (!profileCreated)
                AppButton(
                  label: 'Enregistrer mes informations',
                  icon: Icons.save_outlined,
                  loading: submitting,
                  onPressed: onCreateProfile,
                )
              else
                Row(
                  children: const [
                    Icon(Icons.verified_outlined, size: 18, color: AppColors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Informations enregistrées.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),
              Text('Pièces justificatives', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Carte CIP ou biométrique et justificatif de domicile obligatoires.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final doc in docTypes) ...[
                _DocumentTile(
                  type: doc.$1,
                  title: doc.$2,
                  subtitle: doc.$3,
                  icon: doc.$4,
                  required: requiredTypes.contains(doc.$1),
                  uploaded: uploadedTypes.contains(doc.$1),
                  preview: previews[doc.$1],
                  uploading: uploadingType == doc.$1,
                  enabled: profileCreated && uploadingType == null,
                  onPick: () => onPickDocument(doc.$1),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: AppButton(
              label: allRequiredDone ? 'Activer mon compte' : 'Terminer',
              icon: Icons.check_circle_outline,
              enabled: profileCreated,
              onPressed: onFinish,
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.required,
    required this.uploaded,
    required this.preview,
    required this.uploading,
    required this.enabled,
    required this.onPick,
  });

  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool required;
  final bool uploaded;
  final Uint8List? preview;
  final bool uploading;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: uploaded ? AppColors.green : AppColors.border,
          width: uploaded ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (uploaded ? AppColors.green : AppColors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: preview != null
                  ? Image.memory(preview!, fit: BoxFit.cover)
                  : Icon(
                      uploaded ? Icons.check_circle : icon,
                      color: uploaded ? AppColors.green : AppColors.orange,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (required) ...[
                        const SizedBox(width: 6),
                        Text('*', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (uploading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            else
              TextButton(
                onPressed: enabled ? onPick : null,
                child: Text(uploaded ? 'Modifier' : 'Ajouter'),
              ),
          ],
        ),
      ),
    );
  }
}
