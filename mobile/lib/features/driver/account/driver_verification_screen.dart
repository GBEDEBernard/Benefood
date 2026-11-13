import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/beninfood_header.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/food_decor.dart';
import '../../../shared/widgets/state_widgets.dart';

class DriverVerificationScreen extends StatefulWidget {
  const DriverVerificationScreen({
    super.key,
    required this.marketplace,
    this.initialFocus,
  });

  final MarketplaceApi marketplace;

  final String? initialFocus;

  @override
  State<DriverVerificationScreen> createState() =>
      _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  static const _docTypes = <(String, String, IconData)>[
    ('id_card', 'Pièce d’identité', Icons.badge_outlined),
    ('driver_license', 'Permis de conduire', Icons.drive_eta_outlined),
    ('vehicle_registration', 'Carte grise', Icons.description_outlined),
    ('insurance', 'Assurance', Icons.health_and_safety_outlined),
    ('photo', 'Photo du livreur', Icons.account_box_outlined),
  ];

  final _scrollController = ScrollController();
  final _vehicleKey = GlobalKey();
  final _documentsKey = GlobalKey();

  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;
  String? _uploadingType;

  Map<String, dynamic>? get _profile {
    final raw = _status?['profile'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  List<Map<String, dynamic>> get _documents {
    final raw = _status?['documents'];
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  String? get _vehicle {
    final value = _profile?['vehicle'];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  String? get _vehicleKind {
    final value = _vehicle?.toLowerCase();
    if (value == null) {
      return null;
    }
    if (['moto', 'motocyclette', 'scooter', 'tricycle'].any(value.contains)) {
      return 'Moto';
    }
    if (['voiture', 'auto', 'berline', 'camionnette'].any(value.contains)) {
      return 'Voiture';
    }
    return null;
  }

  IconData get _vehicleIcon => switch (_vehicleKind) {
    'Moto' => Icons.two_wheeler_rounded,
    'Voiture' => Icons.directions_car_rounded,
    _ => Icons.delivery_dining_rounded,
  };

  String? get _location {
    final city = _profile?['city'];
    final area = _profile?['area'];
    final parts = [
      if (city is String && city.trim().isNotEmpty) city.trim(),
      if (area is String && area.trim().isNotEmpty) area.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.marketplace.driverStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _loading = false;
      });
      _scrollToFocus();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _scrollToFocus() {
    final focus = widget.initialFocus;
    if (focus == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = focus == 'documents'
          ? _documentsKey.currentContext
          : _vehicleKey.currentContext;
      if (target == null) {
        return;
      }
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    });
  }

  (String, Color, IconData) _vehicleStatus() {
    final registrations = _documents
        .where((doc) => doc['type'] == 'vehicle_registration')
        .toList(growable: false);
    if (registrations.any((doc) => doc['status'] == 'valid')) {
      return ('Vérifié', AppColors.greenFresh, Icons.verified_rounded);
    }
    if (registrations.any((doc) => doc['status'] == 'invalid')) {
      return ('Refusé', AppColors.red, Icons.cancel_rounded);
    }
    if (registrations.isNotEmpty) {
      return ('En attente', AppColors.orangeVivid, Icons.schedule_rounded);
    }
    return (
      'Non vérifié',
      AppColors.neutralTextSecondary,
      Icons.help_outline_rounded,
    );
  }

  Future<void> _pickDocument(String type, String label) async {
    if (_uploadingType != null) {
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    setState(() => _uploadingType = type);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      await widget.marketplace.uploadDriverDocument(type, bytes);
      await _load();
      if (mounted) {
        showToast(context, '$label transmis pour vérification.');
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

  Future<void> _openDocument(Map<String, dynamic> document) async {
    final rawUrl = document['url'];
    final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showToast(
          context,
          'Impossible d’ouvrir ce document. Actualisez la page puis réessayez.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BeninfoodPageScaffold(
      api: widget.marketplace,
      audience: NotificationAudience.driver,
      title: 'Véhicule & documents',
      body: Stack(
        children: [
          const Positioned.fill(child: FoodDecorPageBackground()),
          RefreshIndicator(
            color: AppColors.orangeVivid,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _status == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orangeVivid),
      );
    }
    if (_error != null && _status == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        children: [ErrorState(message: _error!, onRetry: _load)],
      );
    }

    final vehicleStatus = _vehicleStatus();
    final documents = _documents;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.lg,
        AppDimens.pagePadding,
        AppDimens.xxl,
      ),
      children: [
        _StatusNotice(
          vehicle: _vehicle,
          status: vehicleStatus,
          location: _location,
        ),
        const SizedBox(height: AppDimens.lg),
        _SectionCard(
          key: _vehicleKey,
          title: 'Mon véhicule',
          subtitle: 'Informations issues de votre dossier livreur.',
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.greenMist,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _vehicleIcon,
                      size: 29,
                      color: AppColors.greenDeep,
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _vehicle ?? 'Aucun véhicule renseigné',
                          style: TextStyle(
                            color: _vehicle == null
                                ? AppColors.neutralTextSecondary
                                : AppColors.neutralText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _location ?? 'Localisation non renseignée',
                          style: const TextStyle(
                            color: AppColors.neutralTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (_vehicleKind != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${_vehicleKind!.toUpperCase()} · BÉNIN',
                            style: const TextStyle(
                              color: AppColors.greenDeep,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.sm),
                  _ShieldBadge(
                    label: vehicleStatus.$1,
                    color: vehicleStatus.$2,
                    icon: vehicleStatus.$3,
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimens.md),
                decoration: BoxDecoration(
                  color: AppColors.neutralSurfaceMuted,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Text(
                  'Vérifiez que la marque, le modèle et l’immatriculation indiqués '
                  'correspondent à votre ${_vehicleKind?.toLowerCase() ?? 'véhicule'} '
                  'et à sa carte grise béninoise. Toute modification est vérifiée '
                  'par l’administration Béninfood.',
                  style: TextStyle(
                    color: AppColors.neutralTextSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _SectionCard(
          key: _documentsKey,
          title: 'Documents et vérification',
          subtitle: documents.isEmpty
              ? 'Aucun document transmis pour le moment.'
              : '${documents.length} document${documents.length > 1 ? 's' : ''} dans votre dossier.',
          child: Column(
            children: [
              for (final entry in _docTypes)
                _DocumentRow(
                  label: entry.$2,
                  icon: entry.$3,
                  document: _latestDocumentFor(entry.$1),
                  uploading: _uploadingType == entry.$1,
                  onUpload: () => _pickDocument(entry.$1, entry.$2),
                  onView: _openDocument,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        const _InfoFootnote(),
      ],
    );
  }

  Map<String, dynamic>? _latestDocumentFor(String type) {
    Map<String, dynamic>? latest;
    for (final doc in _documents) {
      if (doc['type'] != type) {
        continue;
      }
      final currentDate =
          DateTime.tryParse(doc['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final latestDate =
          DateTime.tryParse(latest?['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (latest == null || currentDate.isAfter(latestDate)) {
        latest = doc;
      }
    }
    return latest;
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.vehicle,
    required this.status,
    required this.location,
  });

  final String? vehicle;
  final (String, Color, IconData) status;
  final String? location;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(color: AppColors.neutralBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D202A33),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.orangeMist,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.orangeVivid,
              size: 24,
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vérification de votre dossier',
                  style: TextStyle(
                    color: AppColors.neutralText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${status.$1} · ${vehicle ?? 'véhicule non renseigné'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutralTextSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(color: AppColors.neutralBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D202A33),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.neutralText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.neutralTextSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          child,
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.label,
    required this.icon,
    required this.document,
    required this.uploading,
    required this.onUpload,
    required this.onView,
  });

  final String label;
  final IconData icon;
  final Map<String, dynamic>? document;
  final bool uploading;
  final VoidCallback onUpload;
  final ValueChanged<Map<String, dynamic>> onView;

  @override
  Widget build(BuildContext context) {
    final status = document == null
        ? null
        : _DriverDocumentStatus.of(document!['status']);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.neutralSurfaceMuted,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.greenDeep),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.neutralText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        document == null
                            ? 'Document non transmis'
                            : status!.label,
                        style: TextStyle(
                          color:
                              status?.color ?? AppColors.neutralTextSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (document?['reason'] case final String reason
                          when reason.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          reason,
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (uploading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orangeVivid,
                      ),
                    ),
                  ),
              ],
            ),
            if (!uploading)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  children: [
                    if (document?['url'] is String &&
                        (document!['url'] as String).isNotEmpty)
                      TextButton.icon(
                        onPressed: () => onView(document!),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Consulter'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.greenDeep,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    TextButton(
                      onPressed: onUpload,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.orangeVivid,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        document == null ? 'Ajouter' : 'Remplacer',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

class _DriverDocumentStatus {
  const _DriverDocumentStatus(this.label, this.color);

  final String label;
  final Color color;

  static _DriverDocumentStatus of(dynamic status) => switch (status) {
    'valid' => const _DriverDocumentStatus('Validé', AppColors.greenFresh),
    'invalid' => const _DriverDocumentStatus('Rejeté', AppColors.red),
    'submitted' => const _DriverDocumentStatus(
      'En vérification',
      AppColors.orangeVivid,
    ),
    _ => const _DriverDocumentStatus(
      'En attente',
      AppColors.neutralTextSecondary,
    ),
  };
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoFootnote extends StatelessWidget {
  const _InfoFootnote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: AppColors.neutralTextSecondary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Vos documents sont chiffrés et utilisés uniquement pour la '
            'vérification de votre compte livreur Béninfood.',
            style: TextStyle(
              color: AppColors.neutralTextSecondary.withValues(alpha: 0.9),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
