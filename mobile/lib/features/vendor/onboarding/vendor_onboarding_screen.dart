import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/category.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import 'steps/documents_step.dart';
import 'steps/legal_info_step.dart';
import 'steps/shop_config_step.dart';
import 'steps/submitted_step.dart';
import 'steps/welcome_step.dart';
import 'widgets/onboarding_scaffold.dart';

/// Sélecteur d'images injectable : les tests remplacent le plugin natif.
typedef OnboardingImagePicker = Future<Uint8List?> Function(ImageSource source);

/// Parcours d'inscription vendeur en 5 écrans (spec UX) :
/// accueil → informations légales → documents → configuration → confirmation.
///
/// Toute l'état (formulaires, documents, médias) vit dans ce contrôleur pour
/// survivre aux allers-retours entre les étapes de la [PageView].
class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({
    super.key,
    required this.marketplace,
    this.imagePicker,
  });

  final MarketplaceApi marketplace;

  /// Remplace le sélecteur d'images natif (tests uniquement).
  final OnboardingImagePicker? imagePicker;

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  /// Étapes : 0 accueil, 1 infos légales, 2 documents, 3 configuration, 4 fin.
  int _step = 0;

  final PageController _pageController = PageController();

  // --- Étape 1 : informations légales ---
  final _legalFormKey = GlobalKey<FormState>();
  final _raisonSociale = TextEditingController();
  final _ifu = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _adresse = TextEditingController();

  // --- Étape 2 : documents ---
  final Set<String> _uploadedTypes = {};
  final Map<String, Uint8List?> _docPreviews = {};
  String? _uploadingType;

  // --- Étape 3 : configuration boutique ---
  final _shopFormKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _description = TextEditingController();
  List<Category> _categories = [];
  String? _categoryId;
  Uint8List? _logoBytes;
  Uint8List? _coverBytes;
  String? _logoUrl;
  String? _coverUrl;

  /// Un profil vendeur existe déjà côté serveur (reprise du dossier).
  bool _vendorCreated = false;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _restore();
    _loadCategories();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _raisonSociale.dispose();
    _ifu.dispose();
    _phone.dispose();
    _email.dispose();
    _adresse.dispose();
    _shopName.dispose();
    _description.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Reprise du dossier et catégories
  // ------------------------------------------------------------------

  /// Reprend un dossier déjà commencé : pré-remplit les champs légaux,
  /// la configuration et coche les documents déjà transmis.
  Future<void> _restore() async {
    try {
      final status = await widget.marketplace.vendorStatus();
      if (!mounted) {
        return;
      }
      final vendor = status['vendor'];
      if (vendor is! Map<String, dynamic>) {
        return;
      }

      _vendorCreated = true;
      _raisonSociale.text =
          (vendor['legal_name'] as String?) ?? (vendor['business_name'] as String?) ?? '';
      _ifu.text = vendor['ifu'] as String? ?? '';
      _phone.text = vendor['phone'] as String? ?? '';
      _email.text = vendor['email'] as String? ?? '';
      _adresse.text = vendor['address'] as String? ?? '';
      _shopName.text = vendor['business_name'] as String? ?? '';
      _description.text = vendor['description'] as String? ?? '';
      _categoryId = vendor['category_id'] as String?;
      _logoUrl = vendor['logo_url'] as String?;
      _coverUrl = vendor['cover_url'] as String?;

      final documents = status['documents'];
      if (documents is List) {
        for (final raw in documents) {
          if (raw is Map<String, dynamic>) {
            final type = raw['type'];
            if (type is String &&
                kOnboardingDocumentTypes.any((doc) => doc.$1 == type)) {
              _uploadedTypes.add(type);
            }
          }
        }
      }
      setState(() {});
    } on ApiException {
      // Aucun profil vendeur : premier passage du parcours.
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.marketplace.categories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = [for (final c in categories) if (c.isActive) c];
      });
    } on ApiException {
      // Le dropdown reste vide : la saisie reste possible au prochain essai.
    }
  }

  // ------------------------------------------------------------------
  // Navigation entre les étapes
  // ------------------------------------------------------------------

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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

  // ------------------------------------------------------------------
  // Images : choix de la source puis lecture des octets
  // ------------------------------------------------------------------

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
              child: Text(
                'Ajouter une image',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.orange),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.orange),
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
      return custom(source);
    }
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
      return file?.readAsBytes();
    } catch (_) {
      if (mounted) {
        showToast(context, 'Impossible de charger l\u2019image.', isError: true);
      }
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Étape 2 : envoi immédiat des documents
  // ------------------------------------------------------------------

  Future<void> _pickDocument(String type) async {
    if (_uploadingType != null) {
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
      await widget.marketplace.uploadVendorDocument(type, bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _uploadedTypes.add(type);
        _docPreviews[type] = bytes;
        _uploadingType = null;
      });
      showToast(context, 'Document envoyé.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _uploadingType = null);
      _showError(error);
    }
  }

  // ------------------------------------------------------------------
  // Étape 3 : logo et couverture
  // ------------------------------------------------------------------

  Future<void> _pickMedia({required bool isLogo}) async {
    final source = await _askImageSource();
    if (source == null || !mounted) {
      return;
    }
    final bytes = await _readImage(source);
    if (bytes == null || !mounted) {
      return;
    }
    setState(() {
      if (isLogo) {
        _logoBytes = bytes;
        _logoUrl = null;
      } else {
        _coverBytes = bytes;
        _coverUrl = null;
      }
    });
  }

  // ------------------------------------------------------------------
  // Passages entre les étapes (validations + appels API)
  // ------------------------------------------------------------------

  Future<void> _continueFromLegal() async {
    final form = _legalFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_vendorCreated) {
        await _updateLegalInfo();
      } else {
        try {
          await _sendLegalInfo();
          _vendorCreated = true;
        } on ApiException catch (e) {
          if (!e.isConflict) {
            rethrow;
          }
          // Le dossier existe déjà côté serveur : on le met à jour.
          await _updateLegalInfo();
          _vendorCreated = true;
        }
      }
      _goTo(2);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _sendLegalInfo() {
    return widget.marketplace.vendorOnboarding(
      businessName: _raisonSociale.text.trim(),
      legalName: _raisonSociale.text.trim(),
      ifu: _ifu.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _adresse.text.trim(),
    );
  }

  Future<void> _updateLegalInfo() {
    return widget.marketplace.updateVendorProfile(
      businessName: _raisonSociale.text.trim(),
      legalName: _raisonSociale.text.trim(),
      ifu: _ifu.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _adresse.text.trim(),
    );
  }

  void _continueFromDocuments() {
    final missing = kOnboardingDocumentTypes
        .where((doc) => !_uploadedTypes.contains(doc.$1))
        .length;
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
    _goTo(3);
  }

  Future<void> _continueFromShop() async {
    final form = _shopFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_logoBytes == null && _logoUrl == null) {
      showToast(context, 'Ajoutez le logo de la boutique.', isError: true);
      return;
    }
    if (_coverBytes == null && _coverUrl == null) {
      showToast(context, 'Ajoutez l\u2019image de couverture.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.marketplace.updateVendorProfile(
        businessName: _shopName.text.trim(),
        description: _description.text.trim(),
        categoryId: _categoryId,
      );
      if (_logoBytes != null || _coverBytes != null) {
        await widget.marketplace.updateVendorMedia(
          logo: _logoBytes,
          cover: _coverBytes,
        );
      }
      _goTo(4);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  // ------------------------------------------------------------------
  // Affichage
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PopScope(
          // Retour système : une étape en arrière, sauf aux extrémités.
          canPop: _step == 0 || _step == 4,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _step > 0 && _step < 4) {
              _goTo(_step - 1);
            }
          },
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _step = index),
            children: [
              WelcomeStep(
                onStart: () => _goTo(1),
                onSkip: () => Navigator.of(context).pop(_vendorCreated),
              ),
              OnboardingScaffold(
                stepIndex: 1,
                title: 'Informations légales',
                subtitle: 'Renseignez les informations légales de votre entreprise.',
                nextLabel: 'Suivant',
                loading: _submitting,
                onBack: () => _goTo(0),
                onNext: _continueFromLegal,
                child: LegalInfoStep(
                  formKey: _legalFormKey,
                  raisonSociale: _raisonSociale,
                  ifu: _ifu,
                  phone: _phone,
                  email: _email,
                  adresse: _adresse,
                ),
              ),
              OnboardingScaffold(
                stepIndex: 2,
                title: 'Documents requis',
                subtitle: 'Envoyez les justificatifs demandés pour la vérification.',
                nextLabel: 'Suivant',
                onBack: () => _goTo(1),
                onNext: _continueFromDocuments,
                child: DocumentsStep(
                  previews: _docPreviews,
                  uploadedTypes: _uploadedTypes,
                  uploadingType: _uploadingType,
                  onPick: _pickDocument,
                ),
              ),
              OnboardingScaffold(
                stepIndex: 3,
                title: 'Configuration de la boutique',
                subtitle: 'Personnalisez la vitrine de votre boutique.',
                nextLabel: 'Suivant',
                loading: _submitting,
                onBack: () => _goTo(2),
                onNext: _continueFromShop,
                child: ShopConfigStep(
                  formKey: _shopFormKey,
                  shopName: _shopName,
                  description: _description,
                  categories: _categories,
                  selectedCategoryId: _categoryId,
                  onCategoryChanged: (value) => setState(() => _categoryId = value),
                  logoBytes: _logoBytes,
                  logoUrl: _logoUrl,
                  onPickLogo: () => _pickMedia(isLogo: true),
                  coverBytes: _coverBytes,
                  coverUrl: _coverUrl,
                  onPickCover: () => _pickMedia(isLogo: false),
                ),
              ),
              SubmittedStep(
                onGoToDashboard: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
