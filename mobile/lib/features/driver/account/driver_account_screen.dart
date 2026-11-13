import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/services/driver_presence_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/models/parcel.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/drawer_kit.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/food_decor.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../wallet/widgets/payout_request_sheet.dart';

const _documentTypesCount = 5;

String _userName(User? user) => user?.name ?? 'Livreur';

String? _userAvatar(User? user) => user?.avatarUrl;

String buildDriverQrPayload(String profileId) =>
    'beninfood://driver/profile/$profileId';

class DriverAccountScreen extends StatefulWidget {
  const DriverAccountScreen({
    super.key,
    required this.session,
    required this.marketplace,
    required this.onSelectTab,
    this.onOpenMenu,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;
  final ValueChanged<int> onSelectTab;
  final VoidCallback? onOpenMenu;

  @override
  State<DriverAccountScreen> createState() => _DriverAccountScreenState();
}

class _DriverAccountScreenState extends State<DriverAccountScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _wallet;
  List<Delivery> _deliveries = const [];
  List<Parcel> _parcels = const [];
  bool _statusLoaded = false;
  bool _walletLoaded = false;
  bool _statsLoaded = false;
  bool _loading = true;
  String? _statusError;
  String? _walletError;
  bool _available = false;
  bool _toggling = false;
  bool _uploadingAvatar = false;
  bool _withdrawing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _available) {
      unawaited(DriverPresenceService.reportNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DriverPresenceService.pauseHeartbeat();
    super.dispose();
  }

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
    final raw = _profile?['vehicle'];
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  String? get _location {
    final city = _profile?['city'];
    final area = _profile?['area'];
    final parts = [
      if (city is String && city.trim().isNotEmpty) city.trim(),
      if (area is String && area.trim().isNotEmpty) area.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? get _driverProfileId {
    final profileId = _profile?['id'];
    if (profileId != null) {
      return '$profileId';
    }
    final userId = _profile?['user_id'];
    if (userId != null) {
      return '$userId';
    }
    return widget.session.user?.id;
  }

  String get _driverStatus {
    final raw = _profile?['status'];
    return raw is String ? raw : '';
  }

  bool get _canToggleAvailability => _statusLoaded && _driverStatus == 'active';

  int get _walletEarnings => _walletInt('earnings_total');

  int get _walletAvailable => _walletInt('available_balance');

  int get _walletPending => _walletInt('pending_balance');

  int get _minPayout {
    final value = _walletInt('min_payout');
    return value > 0 ? value : 1000;
  }

  int get _validDocumentCount =>
      _documents.where((doc) => doc['status'] == 'valid').length;

  int get _completedMissions =>
      _deliveries.where((delivery) => delivery.status == 'delivered').length +
      _parcels.where((parcel) => parcel.isDelivered).length;

  int get _totalMissions => _deliveries.length + _parcels.length;

  String get _ratingLabel {
    final raw = _profile?['rating'];
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (value == null || value <= 0) {
      return '—';
    }
    return value.toStringAsFixed(1);
  }

  String get _successRateLabel {
    if (!_statsLoaded || _totalMissions == 0) {
      return '—';
    }
    return '${(_completedMissions / _totalMissions * 100).round()}%';
  }

  int _walletInt(String key) {
    final raw = _wallet?[key];
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse('$raw') ?? 0;
  }

  (String, Color) get _statusInfo => switch (_driverStatus) {
    'active' => ('Actif', AppColors.greenFresh),
    'validated' => ('Vérifié', AppColors.greenFresh),
    'pending_validation' ||
    'pending' ||
    'candidate' => ('En attente de validation', AppColors.orangeVivid),
    'suspended' => ('Suspendu', AppColors.red),
    'closed' => ('Fermé', AppColors.red),
    _ => ('Statut inconnu', AppColors.neutralTextSecondary),
  };

  (String, Color) get _vehicleVerification {
    final registrations = _documents
        .where((doc) => doc['type'] == 'vehicle_registration')
        .toList(growable: false);
    if (registrations.any((doc) => doc['status'] == 'valid')) {
      return ('Vérifié', AppColors.greenFresh);
    }
    if (registrations.any((doc) => doc['status'] == 'invalid')) {
      return ('Refusé', AppColors.red);
    }
    if (registrations.isNotEmpty) {
      return ('En attente', AppColors.orangeVivid);
    }
    return ('Non vérifié', AppColors.neutralTextSecondary);
  }

  Future<_FetchResult<T>> _guard<T>(Future<T> future) async {
    try {
      return _FetchResult<T>(data: await future);
    } on ApiException catch (e) {
      return _FetchResult<T>(error: e.message);
    }
  }

  Future<void> _load() async {
    final firstLoad = !_statusLoaded;
    setState(() {
      _loading = true;
      if (firstLoad) {
        _statusError = null;
        _walletError = null;
      }
    });

    final statusFuture = _guard(widget.marketplace.driverStatus());
    final deliveriesFuture = _guard(widget.marketplace.myDeliveries());
    final parcelsFuture = _guard(widget.marketplace.myDriverParcels());
    final walletFuture = _guard(widget.marketplace.driverWallet());

    final statusResult = await statusFuture;
    final deliveriesResult = await deliveriesFuture;
    final parcelsResult = await parcelsFuture;
    final walletResult = await walletFuture;

    if (!mounted) {
      return;
    }

    final nextStatus = statusResult.data;
    final nextProfile = nextStatus?['profile'];
    final profile = nextProfile is Map<String, dynamic> ? nextProfile : null;

    setState(() {
      if (statusResult.ok && nextStatus != null) {
        _status = nextStatus;
        _statusLoaded = true;
        _statusError = null;
        _available = profile?['available'] == true;
      } else if (_status == null) {
        _statusError = statusResult.error;
      }

      if (deliveriesResult.ok && deliveriesResult.data != null) {
        _deliveries = deliveriesResult.data!;
      }
      if (parcelsResult.ok && parcelsResult.data != null) {
        _parcels = parcelsResult.data!;
      }
      if (deliveriesResult.ok && parcelsResult.ok) {
        _statsLoaded = true;
      }

      if (walletResult.ok && walletResult.data != null) {
        _wallet = walletResult.data;
        _walletLoaded = true;
        _walletError = null;
      } else if (!_walletLoaded) {
        _walletError = walletResult.error;
      }

      _loading = false;
    });

    if (statusResult.ok) {
      unawaited(DriverPresenceService.sync(widget.marketplace, _available));
    }
  }

  Future<void> _openRoute(String path) async {
    await context.push(path);
    if (mounted) {
      await _load();
    }
  }

  String get _profileEditPath {
    final location = _location;
    if (location == null) {
      return '/driver/profile/edit';
    }
    return Uri(
      path: '/driver/profile/edit',
      queryParameters: {'address': location},
    ).toString();
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
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
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) {
      return;
    }
    final source = await _chooseImageSource();
    if (source == null || !mounted) {
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 900,
        imageQuality: 88,
      );
      if (picked == null) {
        return;
      }
      setState(() => _uploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      await widget.marketplace.uploadAvatar(bytes, fileName: picked.name);
      await widget.session.refreshProfile();
      if (mounted) {
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          'Impossible de mettre à jour la photo pour le moment.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    if (!_canToggleAvailability || _toggling) {
      return;
    }
    HapticFeedback.mediumImpact();
    final previous = _available;
    setState(() {
      _available = value;
      _toggling = true;
    });
    try {
      if (value) {
        final failure = await DriverPresenceService.goOnline(
          widget.marketplace,
        );
        if (failure != null) {
          if (mounted) {
            setState(() {
              _available = previous;
              _toggling = false;
            });
            showToast(context, _locationFailureMessage(failure), isError: true);
          }
          return;
        }
      } else {
        await DriverPresenceService.goOffline(widget.marketplace);
      }
      if (mounted) {
        setState(() => _toggling = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _available = previous;
          _toggling = false;
        });
        showToast(context, e.message, isError: true);
      }
    }
  }

  static String _locationFailureMessage(LocationFailure failure) =>
      switch (failure) {
        LocationFailure.serviceDisabled =>
          'Activez le GPS de votre téléphone pour passer en ligne.',
        LocationFailure.permissionDenied =>
          'Autorisez la localisation pour recevoir des courses à proximité.',
        LocationFailure.unavailable =>
          'Position GPS introuvable. Réessayez dans un endroit dégagé.',
      };

  String get _availabilityHint {
    if (!_statusLoaded) {
      return 'Chargement de votre statut…';
    }
    if (!_canToggleAvailability) {
      return switch (_driverStatus) {
        'validated' =>
          'Votre compte doit être activé par la plateforme avant de passer en ligne.',
        'suspended' =>
          'Votre compte est suspendu. Contactez le support pour plus d’informations.',
        'closed' =>
          'Votre compte est fermé. Contactez le support pour plus d’informations.',
        _ =>
          'La disponibilité sera activable dès que votre compte sera validé.',
      };
    }
    return _available
        ? 'Vous recevez les missions disponibles dans votre zone.'
        : 'Passez en ligne pour recevoir des missions.';
  }

  Future<void> _withdraw() async {
    if (_withdrawing) {
      return;
    }
    if (!_walletLoaded) {
      showToast(context, 'Votre solde est en cours de chargement.');
      return;
    }
    if (_walletAvailable < _minPayout) {
      showToast(
        context,
        'Le montant minimum de retrait est de ${formatAmount(_minPayout)}.',
        isError: true,
      );
      return;
    }
    final request = await showPayoutRequestSheet(
      context,
      available: _walletAvailable,
      minPayout: _minPayout,
      phone: widget.session.user?.phone,
    );
    if (request == null || !mounted) {
      return;
    }
    setState(() => _withdrawing = true);
    try {
      await widget.marketplace.requestDriverPayout(
        request.amount,
        method: request.method,
        destination: request.destination,
      );
      if (!mounted) {
        return;
      }
      showToast(context, 'Votre demande de retrait a bien été envoyée.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _withdrawing = false);
      }
    }
  }

  void _showDriverQr() {
    final id = _driverProfileId;
    if (id == null) {
      showToast(
        context,
        'Votre profil livreur est en cours de chargement.',
        isError: true,
      );
      return;
    }
    final status = _statusLoaded ? _statusInfo : null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutralBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.orangeMist,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.orangeVivid,
                  size: 27,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Mon QR code livreur',
                style: TextStyle(
                  color: AppColors.neutralText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Présentez ce code pour identifier votre profil livreur.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.neutralTextSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.neutralBorder),
                ),
                child: QrImageView(
                  key: ValueKey(buildDriverQrPayload(id)),
                  data: buildDriverQrPayload(id),
                  size: 208,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _userName(widget.session.user),
                style: const TextStyle(
                  color: AppColors.neutralText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (status != null) ...[
                const SizedBox(height: 5),
                _StatusBadge(label: status.$1, color: status.$2),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Déconnexion',
      message: 'Voulez-vous vraiment vous déconnecter ?',
      confirmLabel: 'Déconnecter',
    );
    if (!confirmed || !mounted) {
      return;
    }
    DriverPresenceService.stop();
    await widget.session.logout();
    if (mounted) {
      context.go('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MediaQuery(
        data: media.copyWith(
          textScaler: media.textScaler.clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.15,
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: FoodDecorPageBackground()),
            Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.neutralBorder),
                    ),
                  ),
                  child: ProfileHeader(
                    marketplace: widget.marketplace,
                    uploadingAvatar: _uploadingAvatar,
                    onMenu: widget.onOpenMenu,
                    audience: NotificationAudience.driver,
                    notificationBadgeColor: AppColors.orangeVivid,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.orangeVivid,
                    onRefresh: _load,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (_loading && !_statusLoaded) {
                          return _buildSkeleton(constraints.maxWidth);
                        }
                        return _buildContent(constraints.maxWidth);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _contentSide(double width) {
    final side = (width - 980) / 2;
    return side < AppDimens.pagePadding
        ? AppDimens.pagePadding
        : side.toDouble();
  }

  Widget _buildSkeleton(double width) {
    final side = _contentSide(width);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 18, bottom: AppDimens.xxl),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: const _SkeletonBox(height: 146),
        ),
        const SizedBox(height: AppDimens.md),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: const Row(
            children: [
              Expanded(child: _SkeletonBox(height: 92)),
              SizedBox(width: AppDimens.md),
              Expanded(child: _SkeletonBox(height: 92)),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.md),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: const _SkeletonBox(height: 220),
        ),
        const SizedBox(height: AppDimens.md),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: const _SkeletonBox(height: 112),
        ),
      ],
    );
  }

  Widget _buildContent(double width) {
    final wide = width >= 720;
    final side = _contentSide(width);
    final horizontal = EdgeInsets.symmetric(horizontal: side);
    final user = widget.session.user;
    final statusInfo = _statusLoaded
        ? _statusInfo
        : ('Chargement…', AppColors.neutralTextSecondary);
    final vehicleInfo = _vehicleVerification;
    final hasSpaces = (user?.contexts.length ?? 1) > 1;

    final hero = _reveal(0, _buildProfileHero());
    final identity = _reveal(
      1,
      _buildIdentity(user, statusInfo, vehicleInfo, wide: wide),
    );
    final availability = _reveal(2, _buildAvailability());
    final revenue = _reveal(3, _buildRevenue());
    final stats = _reveal(4, _buildStats(width));
    final activity = _reveal(5, _buildActivityCard());
    final account = _reveal(
      6,
      _MenuCard(
        title: 'Mon compte',
        entries: [
          _MenuEntry(
            icon: Icons.person_outline_rounded,
            tint: AppColors.greenMist,
            accent: AppColors.greenDeep,
            title: 'Informations personnelles',
            subtitle: 'Nom, e-mail, téléphone et adresse',
            onTap: () => _openRoute(_profileEditPath),
          ),
          _MenuEntry(
            icon: Icons.two_wheeler_rounded,
            tint: AppColors.greenMist,
            accent: AppColors.greenDeep,
            title: 'Véhicule',
            subtitle:
                '${_vehicle ?? 'Aucun véhicule renseigné'} · ${vehicleInfo.$1}',
            onTap: () => _openRoute('/driver/verification?focus=vehicle'),
          ),
          _MenuEntry(
            icon: Icons.verified_user_outlined,
            tint: AppColors.orangeMist,
            accent: AppColors.orangeVivid,
            title: 'Documents',
            subtitle: _validDocumentCount == 0
                ? 'Transmettre vos justificatifs'
                : '$_validDocumentCount sur $_documentTypesCount validés',
            onTap: () => _openRoute('/driver/verification?focus=documents'),
          ),
          _MenuEntry(
            icon: Icons.notifications_none_rounded,
            tint: AppColors.orangeMist,
            accent: AppColors.orangeVivid,
            title: 'Notifications',
            subtitle: 'Missions, commandes et alertes',
            onTap: () => _openRoute('/driver/notifications'),
          ),
          _MenuEntry(
            icon: Icons.shield_outlined,
            tint: AppColors.greenMist,
            accent: AppColors.greenDeep,
            title: 'Sécurité',
            subtitle: 'Mot de passe et appareils connectés',
            onTap: () => _openRoute('/driver/security'),
          ),
        ],
      ),
    );
    final support = _reveal(
      7,
      _MenuCard(
        title: 'Support',
        entries: [
          _MenuEntry(
            icon: Icons.headset_mic_outlined,
            tint: AppColors.orangeMist,
            accent: AppColors.orangeVivid,
            title: 'Aide et support',
            subtitle: 'Questions fréquentes et contact',
            onTap: () => _openRoute('/driver/complaints'),
          ),
        ],
      ),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 18, bottom: AppDimens.xxl),
      children: [
        if (_statusError != null && !_statusLoaded)
          Padding(
            padding: horizontal,
            child: _InlineErrorCard(message: _statusError!, onRetry: _load),
          ),
        if (_statusError != null && !_statusLoaded)
          const SizedBox(height: AppDimens.md),
        Padding(padding: horizontal, child: hero),
        const SizedBox(height: AppDimens.md),
        Padding(padding: horizontal, child: identity),
        const SizedBox(height: AppDimens.md),
        if (wide)
          Padding(
            padding: horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: revenue),
                const SizedBox(width: AppDimens.md),
                SizedBox(width: 340, child: availability),
              ],
            ),
          )
        else ...[
          Padding(padding: horizontal, child: revenue),
          const SizedBox(height: AppDimens.md),
          Padding(padding: horizontal, child: availability),
        ],
        const SizedBox(height: AppDimens.xl),
        Padding(padding: horizontal, child: stats),
        const SizedBox(height: AppDimens.xl),
        if (wide)
          Padding(
            padding: horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: activity),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    children: [
                      account,
                      const SizedBox(height: AppDimens.md),
                      support,
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          Padding(padding: horizontal, child: activity),
          const SizedBox(height: AppDimens.md),
          Padding(padding: horizontal, child: account),
          const SizedBox(height: AppDimens.md),
          Padding(padding: horizontal, child: support),
        ],
        if (hasSpaces) ...[
          const SizedBox(height: AppDimens.xl),
          Padding(
            padding: horizontal,
            child: const _SectionLabel('Espaces accessibles'),
          ),
          const SizedBox(height: AppDimens.sm),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (side - AppDimens.pagePadding).clamp(
                0,
                double.infinity,
              ),
            ),
            child: ProfileSpacesMenu(
              session: widget.session,
              currentContext: AppContext.driver,
            ),
          ),
        ],
        const SizedBox(height: AppDimens.xl),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (side - AppDimens.pagePadding).clamp(
              0,
              double.infinity,
            ),
          ),
          child: ProfileLogoutButton(onConfirm: _confirmLogout),
        ),
      ],
    );
  }

  Widget _buildProfileHero() {
    return const _DriverProfileHero();
  }

  Widget _buildIdentity(
    User? user,
    (String, Color) status,
    (String, Color) vehicleInfo, {
    required bool wide,
  }) {
    final name = _userName(user);
    final location = _location;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DriverAvatar(
                name: name,
                url: _userAvatar(user),
                online: _available && _canToggleAvailability,
                uploading: _uploadingAvatar,
                size: wide ? 92 : 82,
                onTap: _pickAvatar,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.neutralText,
                        fontSize: wide ? 23 : 21,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppColors.neutralTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location ?? 'Localisation non renseignée',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.neutralTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: AppColors.orangeVivid,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _ratingLabel,
                          style: const TextStyle(
                            color: AppColors.neutralText,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'note livreur',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.neutralTextSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: AppColors.orangeMist,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: _showDriverQr,
                  borderRadius: BorderRadius.circular(15),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.qr_code_rounded,
                      color: AppColors.orangeVivid,
                      size: 23,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusBadge(label: status.$1, color: status.$2),
              _StatusBadge(
                label: 'Véhicule ${vehicleInfo.$1.toLowerCase()}',
                color: vehicleInfo.$2,
                icon: Icons.two_wheeler_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailability() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LivePulseDot(active: _available && _canToggleAvailability),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Disponibilité',
                  style: TextStyle(
                    color: AppColors.neutralText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _AvailabilitySwitch(
                value: _available && _canToggleAvailability,
                enabled: _canToggleAvailability && !_toggling,
                loading: _toggling,
                onChanged: _toggleAvailability,
              ),
            ],
          ),
          const SizedBox(height: 11),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: Text(
              _availabilityHint,
              key: ValueKey('${_available}_$_driverStatus'),
              style: const TextStyle(
                color: AppColors.neutralTextSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          if (_canToggleAvailability) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: _available
                    ? AppColors.greenMist
                    : AppColors.neutralSurfaceMuted,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(
                    _available
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 16,
                    color: _available
                        ? AppColors.greenDeep
                        : AppColors.neutralTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _available ? 'En ligne' : 'Hors ligne',
                      style: TextStyle(
                        color: _available
                            ? AppColors.greenDeep
                            : AppColors.neutralTextSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenue() {
    final progress = _walletLoaded && _walletEarnings > 0
        ? (_walletAvailable / _walletEarnings).clamp(0.0, 1.0)
        : 0.0;
    final reduceMotion = _reduceMotion;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.orangeMist,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.orangeVivid,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Revenus',
                  style: TextStyle(
                    color: AppColors.neutralText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_walletLoaded && _walletEarnings > 0)
                _StatusBadge(
                  label:
                      '${(_walletAvailable / _walletEarnings * 100).clamp(0, 100).round()}% dispo.',
                  color: AppColors.greenFresh,
                ),
            ],
          ),
          const SizedBox(height: 17),
          const Text(
            'Gains cumulés',
            style: TextStyle(
              color: AppColors.neutralTextSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: _walletLoaded ? _walletEarnings.toDouble() : 0,
            ),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Text(
              _walletLoaded ? formatAmount(value.round()) : '…',
              style: const TextStyle(
                color: AppColors.neutralText,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
          ),
          if (_walletError != null && !_walletLoaded) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.orangeVivid,
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'Solde indisponible pour le moment.',
                    style: TextStyle(
                      color: AppColors.neutralTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    foregroundColor: AppColors.orangeVivid,
                  ),
                  child: const Text(
                    'Réessayer',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: AppColors.neutralSurfaceMuted,
                valueColor: const AlwaysStoppedAnimation(AppColors.greenFresh),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MoneyMetric(
                  label: 'Disponible',
                  value: _walletLoaded ? formatAmount(_walletAvailable) : '…',
                  color: AppColors.greenDeep,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.neutralBorder),
              const SizedBox(width: 12),
              Expanded(
                child: _MoneyMetric(
                  label: 'En attente',
                  value: _walletLoaded ? formatAmount(_walletPending) : '…',
                  color: AppColors.orangeVivid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _withdrawing ? null : _withdraw,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orangeVivid,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.orangeVivid.withValues(
                      alpha: 0.45,
                    ),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: _withdrawing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.south_west_rounded, size: 18),
                  label: const Text('Retirer'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openRoute('/driver/wallet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.greenDeep,
                    side: const BorderSide(color: AppColors.neutralBorder),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 17),
                  label: const Text('Détails'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(double width) {
    final reduceMotion = _reduceMotion;
    final columns = width >= 720 ? 4 : 2;
    const gap = 10.0;
    final tileWidth =
        (width - _contentSide(width) * 2 - gap * (columns - 1)) / columns;
    final tiles = <Widget>[
      _StatTile(
        icon: Icons.delivery_dining_rounded,
        tint: AppColors.orangeMist,
        accent: AppColors.orangeVivid,
        label: 'Missions',
        value: _statsLoaded ? '$_totalMissions' : '—',
        onTap: () => widget.onSelectTab(0),
      ),
      _StatTile(
        icon: Icons.check_circle_outline_rounded,
        tint: AppColors.greenMist,
        accent: AppColors.greenDeep,
        label: 'Terminées',
        value: _statsLoaded ? '$_completedMissions' : '—',
        onTap: () => widget.onSelectTab(3),
      ),
      _StatTile(
        icon: Icons.star_outline_rounded,
        tint: AppColors.orangeMist,
        accent: AppColors.orangeVivid,
        label: 'Note moyenne',
        value: _ratingLabel,
      ),
      _StatTile(
        icon: Icons.trending_up_rounded,
        tint: AppColors.greenMist,
        accent: AppColors.greenDeep,
        label: 'Taux de réussite',
        value: _successRateLabel,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Votre activité',
                style: TextStyle(
                  color: AppColors.neutralText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openRoute('/driver/stats'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.orangeVivid,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 34),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 17),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < tiles.length; i++)
              SizedBox(
                width: tileWidth,
                child: _ProgressiveReveal(
                  index: i,
                  reduceMotion: reduceMotion,
                  child: tiles[i],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityCard() {
    return _MenuCard(
      title: 'Activité',
      entries: [
        _MenuEntry(
          icon: Icons.insights_rounded,
          tint: AppColors.orangeMist,
          accent: AppColors.orangeVivid,
          title: 'Mes statistiques',
          subtitle: 'Gains, missions et dernières livraisons',
          onTap: () => _openRoute('/driver/stats'),
        ),
        _MenuEntry(
          icon: Icons.account_balance_wallet_outlined,
          tint: AppColors.greenMist,
          accent: AppColors.greenDeep,
          title: 'Mes gains et retraits',
          subtitle: 'Solde disponible, séquestre et historique',
          onTap: () => _openRoute('/driver/wallet'),
        ),
        _MenuEntry(
          icon: Icons.people_alt_outlined,
          tint: AppColors.orangeMist,
          accent: AppColors.orangeVivid,
          title: 'Mes clients',
          subtitle: 'Demandes de favori à accepter',
          onTap: () => _openRoute('/driver/favorite-clients'),
        ),
      ],
    );
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  Widget _reveal(int index, Widget child) {
    if (_reduceMotion) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 430 + index * 65),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Transform.scale(scale: 0.985 + 0.015 * value, child: child),
        ),
      ),
    );
  }
}

class _DriverProfileHero extends StatefulWidget {
  const _DriverProfileHero();

  @override
  State<_DriverProfileHero> createState() => _DriverProfileHeroState();
}

class _DriverProfileHeroState extends State<_DriverProfileHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final angle = math.pi / 4 + 0.6 * math.sin(t * 2 * math.pi);
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment(math.cos(angle), math.sin(angle)),
              end: Alignment(-math.cos(angle), -math.sin(angle)),
              colors: const [
                Color(0xFF092417),
                Color(0xFF124B2A),
                Color(0xFF1E6935),
              ],
              stops: const [0, 0.55, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF17652F).withValues(alpha: 0.25),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Stack(
            children: [
              DrawerBubble(
                t: t,
                size: 126,
                alpha: 0.1,
                phase: 0,
                right: -34,
                top: -46,
              ),
              DrawerBubble(
                t: t,
                size: 72,
                alpha: 0.08,
                phase: 0.4,
                left: -28,
                bottom: -38,
              ),
              const DrawerFoodDecor(intensity: 0.95, compact: true),
              DrawerSheen(t: t),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.17),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.badge_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ESPACE PROFESSIONNEL',
                            style: TextStyle(
                              color: Color(0xFFD8EBDD),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Mon profil livreur',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.35,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Activité, revenus et informations',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFE1F0E4),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FetchResult<T> {
  const _FetchResult({this.data, this.error});

  final T? data;
  final String? error;

  bool get ok => error == null;
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D6B3E1C),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({
    required this.name,
    required this.url,
    required this.online,
    required this.uploading,
    required this.size,
    required this.onTap,
  });

  final String name;
  final String? url;
  final bool online;
  final bool uploading;
  final double size;
  final VoidCallback onTap;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'B';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: online ? AppColors.greenFresh : AppColors.neutralBorder,
              width: 2.2,
            ),
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(
                  url: url,
                  icon: Icons.person_rounded,
                  iconColor: AppColors.greenDeep,
                  iconBackground: AppColors.greenMist,
                  fallback: ColoredBox(
                    color: AppColors.greenMist,
                    child: Center(
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          color: AppColors.greenDeep,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                if (uploading)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (online)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: AppColors.greenFresh,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Material(
            color: AppColors.orangeVivid,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: uploading ? null : onTap,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 29,
                height: 29,
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (reduceMotion) {
      return avatar;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value.clamp(0, 1), child: child),
      ),
      child: avatar,
    );
  }
}

class _AvailabilitySwitch extends StatelessWidget {
  const _AvailabilitySwitch({
    required this.value,
    required this.enabled,
    required this.loading,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Disponibilité livreur',
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => onChanged(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 51,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.orangeVivid : AppColors.neutralBorder,
            borderRadius: BorderRadius.circular(30),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33202A33),
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orangeVivid,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot({required this.active});

  final bool active;

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _LivePulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.active && !reduceMotion) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = widget.active && !reduceMotion
              ? _controller.value
              : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (pulse > 0)
                Transform.scale(
                  scale: 1 + pulse * 0.9,
                  child: Opacity(
                    opacity: (1 - pulse) * 0.35,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.greenFresh,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.active
                      ? AppColors.greenFresh
                      : AppColors.neutralTextSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
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
    if (reduceMotion) {
      return badge;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(scale: value, child: child),
      ),
      child: badge,
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.neutralTextSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.neutralBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08202A33),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 33,
                  height: 33,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutralText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutralTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.title, required this.entries});

  final String title;
  final List<_MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.neutralBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D202A33),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 16, 17, 7),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.neutralText,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.1,
              ),
            ),
          ),
          for (var i = 0; i < entries.length; i++) ...[
            _ProgressiveReveal(
              index: i,
              reduceMotion: reduceMotion,
              child: _MenuTile(entry: entries[i]),
            ),
            if (i < entries.length - 1)
              const Divider(
                height: 1,
                indent: 65,
                endIndent: 15,
                color: AppColors.neutralBorder,
              ),
          ],
          const SizedBox(height: 7),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 9, 10, 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: entry.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(entry.icon, size: 19, color: entry.accent),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
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
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.neutralTextSecondary,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AppColors.neutralTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressiveReveal extends StatefulWidget {
  const _ProgressiveReveal({
    required this.index,
    required this.child,
    required this.reduceMotion,
  });

  final int index;
  final Widget child;
  final bool reduceMotion;

  @override
  State<_ProgressiveReveal> createState() => _ProgressiveRevealState();
}

class _ProgressiveRevealState extends State<_ProgressiveReveal> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _visible = true;
      return;
    }
    _timer = Timer(Duration(milliseconds: 70 + widget.index * 70), () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.neutralText,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeMist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.orangeVivid.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.orangeVivid,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.neutralText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orangeVivid,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Réessayer',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.orangeVivid,
          ),
        ),
      ),
    );
  }
}
