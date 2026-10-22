import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/navigation/notification_router.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/delivery.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/food_decor.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

// ───── À ADAPTER si les champs de ton modèle User ont d'autres noms ─────
String _userName(User? user) => user?.name ?? 'Livreur';
String? _userAvatar(User? user) => user?.avatarUrl;
// ─────────────────────────────────────────────────────────────────────────

const _ink = Color(0xFF2B1608); // brun très foncé (textes forts / icônes)
const _cream = Color(0xFFFFF3E6);
const _line = Color(0xFFF0E2D2); // contour chaud
const _muted = Color(0xFF6B5645); // texte secondaire chaud, bien lisible

/// Remplace toute teinte verte (statut « Actif » du back) par l'orange de la
/// marque : aucune couleur verte ne doit apparaître dans cet écran.
Color _noGreen(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return (hue >= 70 && hue <= 170) ? AppColors.orange : color;
}

/// Compte livreur : identité, disponibilité, gains, statistiques de missions
/// et menu groupé. Dominante orange, responsive (mobile / tablette) et animé.
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

  /// Ouvre le tiroir latéral (menu hamburger) — géré par le shell livreur.
  final VoidCallback? onOpenMenu;

  @override
  State<DriverAccountScreen> createState() => _DriverAccountScreenState();
}

class _DriverAccountScreenState extends State<DriverAccountScreen> {
  Map<String, dynamic>? _status;
  List<Delivery> _deliveries = [];
  bool _statsLoaded = false;
  bool _loading = true;
  String? _error;
  bool _available = false;
  bool _toggling = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? get _profile {
    final raw = _status?['profile'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.marketplace.driverStatus();
      final rawProfile = status['profile'];
      final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
      var deliveries = <Delivery>[];
      var statsLoaded = false;
      try {
        deliveries = await widget.marketplace.myDeliveries();
        statsLoaded = true;
      } on ApiException catch (_) {
        // Les compteurs restent au dernier état connu (ou « … »).
      }
      if (mounted) {
        setState(() {
          _status = status;
          _available = profile?['available'] == true;
          _deliveries = deliveries;
          _statsLoaded = _statsLoaded || statsLoaded;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  int get _deliveredCount =>
      _deliveries.where((d) => d.status == 'delivered').length;

  int get _earnings => _deliveries
      .where((d) => d.status == 'delivered')
      .fold(0, (sum, d) => sum + (d.partnerAmount ?? d.fee));

  Future<void> _openRoute(String path) async {
    await context.push(path);
    if (mounted) {
      await _load();
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
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
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    HapticFeedback.mediumImpact();
    final previous = _available;
    setState(() {
      _available = value;
      _toggling = true;
    });
    try {
      await widget.marketplace.setAvailability(value);
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
    await widget.session.logout();
    if (mounted) {
      context.go('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      // Taille de texte système plafonnée : l'interface reste lisible et ne
      // casse pas quand l'utilisateur agrandit les polices.
      body: MediaQuery(
        data: media.copyWith(
          textScaler: media.textScaler.clamp(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.15,
          ),
        ),
        child: Stack(
          children: [
            // Décor food discret en fond de profil.
            const Positioned.fill(child: FoodDecorPageBackground()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileHeader(
                  marketplace: widget.marketplace,
                  uploadingAvatar: _uploadingAvatar,
                  onMenu: widget.onOpenMenu,
                  audience: NotificationAudience.driver,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.orange,
                    onRefresh: _load,
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildContent(user, constraints.maxWidth),
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

  Widget _buildContent(User? user, double width) {
    // Responsive : échelle fluide, contenu centré et limité en largeur,
    // deux colonnes sur tablette / grand écran.
    final wide = width >= 720;
    final s = (width / 390).clamp(0.88, 1.12).toDouble();
    const maxWidth = 980.0;
    final side = math.max(AppDimens.pagePadding, (width - maxWidth) / 2);
    const gap = AppDimens.md;

    final identity = _reveal(0, _buildIdentity(user, s));
    final availability = _reveal(1, _buildAvailabilitySlot());
    final earnings = _reveal(
      2,
      _EarningsCard(
        loaded: _statsLoaded,
        earnings: _earnings,
        delivered: _deliveredCount,
        total: _deliveries.length,
        scale: s,
        onTap: () => _openRoute('/driver/wallet'),
      ),
    );
    final stats = _reveal(3, _buildMiniStats());

    final activity = _reveal(
      4,
      _MenuSection(
        title: 'Activité',
        entries: [
          _MenuEntry(
            icon: Icons.insights_rounded,
            color: AppColors.orange,
            title: 'Mes statistiques',
            subtitle: 'Gains, missions et dernières livraisons',
            onTap: () => _openRoute('/driver/stats'),
          ),
          _MenuEntry(
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.orangeDark,
            title: 'Mes gains & retraits',
            subtitle: 'Solde disponible, séquestre, retirer',
            onTap: () => _openRoute('/driver/wallet'),
          ),
          _MenuEntry(
            icon: Icons.people_alt_rounded,
            color: AppColors.goldDark,
            title: 'Mes clients',
            subtitle: 'Demandes de favori à accepter',
            onTap: () => _openRoute('/driver/favorite-clients'),
          ),
        ],
      ),
    );
    final account = _reveal(
      5,
      _MenuSection(
        title: 'Compte',
        entries: [
          _MenuEntry(
            icon: Icons.person_rounded,
            color: AppColors.orangeDark,
            title: 'Informations personnelles',
            subtitle: 'Nom, e-mail, photo',
            onTap: () => _openRoute('/driver/profile/edit'),
          ),
          _MenuEntry(
            icon: Icons.notifications_rounded,
            color: AppColors.orange,
            title: 'Notifications',
            subtitle: 'Commandes, alertes, offres',
            onTap: () => _openRoute('/driver/notifications'),
          ),
          _MenuEntry(
            icon: Icons.shield_rounded,
            color: AppColors.goldDark,
            title: 'Sécurité',
            subtitle: 'Mot de passe, appareils',
            onTap: () => _openRoute('/driver/security'),
          ),
        ],
      ),
    );
    final support = _reveal(
      6,
      _MenuSection(
        title: 'Support',
        entries: [
          _MenuEntry(
            icon: Icons.headset_mic_rounded,
            color: AppColors.orange,
            title: 'Aide et support',
            subtitle: 'Questions fréquentes, nous contacter',
            onTap: () => _openRoute('/driver/complaints'),
          ),
        ],
      ),
    );

    final hasSpaces = (user?.contexts.length ?? 1) > 1;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, AppDimens.lg, side, AppDimens.xxl),
      children: [
        identity,
        const SizedBox(height: AppDimens.lg),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: availability),
              const SizedBox(width: gap),
              Expanded(child: earnings),
            ],
          )
        else ...[
          availability,
          const SizedBox(height: gap),
          earnings,
        ],
        const SizedBox(height: gap),
        stats,
        const SizedBox(height: AppDimens.xl),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    activity,
                    const SizedBox(height: AppDimens.lg),
                    support,
                  ],
                ),
              ),
              const SizedBox(width: gap),
              Expanded(child: account),
            ],
          )
        else ...[
          activity,
          const SizedBox(height: AppDimens.lg),
          account,
          const SizedBox(height: AppDimens.lg),
          support,
        ],
        if (hasSpaces) ...[
          const SizedBox(height: AppDimens.lg),
          const _SectionTitle('Espaces accessibles'),
          ProfileSpacesMenu(
            session: widget.session,
            currentContext: AppContext.driver,
          ),
        ],
        const SizedBox(height: AppDimens.lg),
        ProfileLogoutButton(onConfirm: _confirmLogout),
      ],
    );
  }

  /// Apparition en cascade (une seule fois) : fondu + remontée + léger zoom.
  Widget _reveal(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 100),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Transform.scale(scale: 0.95 + 0.05 * value, child: child),
        ),
      ),
    );
  }

  // ───────────────────────── Identité ─────────────────────────

  Widget _buildIdentity(User? user, double s) {
    final name = _userName(user);
    final rawStatus = _profile?['status'];
    final palette = BadgePalette.driver(rawStatus is String ? rawStatus : null);

    return Row(
      children: [
        _Avatar(
          name: name,
          url: _userAvatar(user),
          uploading: _uploadingAvatar,
          online: _available,
          onEdit: _pickAvatar,
          size: 96 * s,
        ),
        const SizedBox(width: AppDimens.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 23 * s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (palette != null)
                    _StatusPill(label: palette.$1, color: _noGreen(palette.$2)),
                  const _InfoPill(
                    icon: Icons.delivery_dining_rounded,
                    label: 'Espace livreur',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.sm),
        _SquareButton(
          icon: Icons.qr_code_2_rounded,
          onTap: () => showContactQrSheet(context, widget.session.user),
        ),
      ],
    );
  }

  // ───────────────────────── Disponibilité + véhicule ─────────────────────────

  Widget _buildAvailabilitySlot() {
    if (_loading && _status == null) {
      return Container(
        height: 150,
        decoration: _cardDecoration(),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
      );
    }
    if (_error != null && _status == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final rawVehicle = _profile?['vehicle'];
    final vehicle = rawVehicle is String && rawVehicle.isNotEmpty ? rawVehicle : null;
    final rating = _profile?['rating'];
    final rawStatus = _profile?['status'];
    final palette = BadgePalette.driver(rawStatus is String ? rawStatus : null);

    return _AvailabilityCard(
      available: _available,
      busy: _toggling,
      onChanged: _toggleAvailability,
      vehicle: vehicle ?? 'Livreur Béninfood',
      ratingLabel: rating is num ? '$rating'.replaceAll('.', ',') : null,
      badge: palette == null
          ? null
          : StatusBadge(label: palette.$1, color: _noGreen(palette.$2), small: true),
    );
  }

  // ───────────────────────── Mini statistiques ─────────────────────────

  Widget _buildMiniStats() {
    final rating = _profile?['rating'];
    final ratingLabel = rating is num ? '$rating'.replaceAll('.', ',') : '—';

    const valueStyle = TextStyle(
      color: AppColors.text,
      fontSize: 22,
      fontWeight: FontWeight.w800,
    );

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            index: 0,
            icon: Icons.two_wheeler_rounded,
            color: AppColors.orange,
            value: _statsLoaded
                ? _CountUp(value: _deliveries.length, style: valueStyle)
                : const Text('…', style: valueStyle),
            label: 'Missions',
            onTap: () => widget.onSelectTab(0),
          ),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: _MiniStat(
            index: 1,
            icon: Icons.check_circle_rounded,
            color: AppColors.orangeDark,
            value: _statsLoaded
                ? _CountUp(value: _deliveredCount, style: valueStyle)
                : const Text('…', style: valueStyle),
            label: 'Livrées',
            onTap: () => widget.onSelectTab(3),
          ),
        ),
        const SizedBox(width: AppDimens.md),
        Expanded(
          child: _MiniStat(
            index: 2,
            icon: Icons.star_rounded,
            color: AppColors.goldDark,
            value: Text(_statsLoaded ? ratingLabel : '…', style: valueStyle),
            label: 'Note',
            onTap: _showRatingSheet,
          ),
        ),
      ],
    );
  }

  /// Feuille de détail de la note moyenne du livreur (pas d'écran d'avis
  /// dédié côté livreur : la note provient du profil `GET /driver/me/status`).
  void _showRatingSheet() {
    final rating = _profile?['rating'];
    final value = rating is num ? rating.toDouble() : null;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: AppColors.goldLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded,
                      size: 38, color: AppColors.goldDark),
                ),
              ),
              const SizedBox(height: AppDimens.md),
              Text(
                value == null
                    ? 'Aucune note'
                    : value.toStringAsFixed(1).replaceAll('.', ','),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Note moyenne attribuée par les clients.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: AppDimens.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────

BoxDecoration _cardDecoration({Color? color, Color? border}) => BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      border: Border.all(color: border ?? _line),
      boxShadow: const [
        BoxShadow(color: Color(0x14B45309), blurRadius: 18, offset: Offset(0, 7)),
      ],
    );

/// Compteur animé : monte de 0 jusqu'à la valeur (et glisse si elle change).
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style, this.format});

  final int value;
  final TextStyle style;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        return Text(format != null ? format!(n) : '$n', style: style);
      },
    );
  }
}

/// Effet de pression : légère réduction à l'appui + vibration au toucher.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de statut lisible sur fond clair (texte foncé, pastille colorée).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = HSLColor.fromColor(color).withLightness(0.24).toColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: color, size: 7),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge neutre blanc, texte sombre.
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.orange),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar : anneau orange qui tourne, halo qui respire quand le livreur est
/// en ligne, entrée en zoom élastique, badge d'édition et indicateur d'envoi.
class _Avatar extends StatefulWidget {
  const _Avatar({
    required this.name,
    required this.url,
    required this.uploading,
    required this.online,
    required this.onEdit,
    required this.size,
  });

  final String name;
  final String? url;
  final bool uploading;
  final bool online;
  final VoidCallback onEdit;
  final double size;

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final url = widget.url;
    final resolved =
        (url == null || url.trim().isEmpty) ? null : resolveMediaUrl(url);

    final fallback = Container(
      color: AppColors.orangeLight,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.orangeDark,
          fontSize: size * 0.29,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final breathe = (math.sin(_c.value * 2 * math.pi * 2) + 1) / 2;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      transform: GradientRotation(_c.value * 2 * math.pi),
                      colors: const [
                        AppColors.orange,
                        AppColors.gold,
                        Color(0xFFFFE2C2),
                        AppColors.orange,
                      ],
                    ),
                    boxShadow: widget.online
                        ? [
                            BoxShadow(
                              color: AppColors.orange
                                  .withValues(alpha: 0.25 + 0.25 * breathe),
                              blurRadius: 14 + 12 * breathe,
                              spreadRadius: 1 + 2 * breathe,
                            ),
                          ]
                        : const [],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (resolved != null)
                            Image.network(
                              resolved,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => fallback,
                            )
                          else
                            fallback,
                          if (widget.uploading)
                            Container(
                              color: Colors.black.withValues(alpha: 0.42),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: widget.uploading
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            widget.onEdit();
                          },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 15, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(color: Color(0x14B45309), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.qr_code_2_rounded, size: 25, color: AppColors.orangeDark),
      ),
    );
  }
}

/// Point qui pulse (statuts « en ligne » / « actif »).
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    return SizedBox(
      width: d * 2,
      height: d * 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: d + d * t,
                height: d + d * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.4 * (1 - t)),
                ),
              ),
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ondes concentriques qui partent de l'icône quand on est en ligne.
class _Ripple extends StatefulWidget {
  const _Ripple({required this.active, required this.child, this.size = 48});

  final bool active;
  final Widget child;
  final double size;

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _Ripple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size + 20;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active)
                for (final phase in const [0.0, 0.5])
                  Builder(builder: (_) {
                    final t = (_c.value + phase) % 1.0;
                    return Container(
                      width: widget.size + 20 * t,
                      height: widget.size + 20 * t,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18 + 10 * t),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.5 * (1 - t)),
                          width: 2,
                        ),
                      ),
                    );
                  }),
              child!,
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Carte « Disponibilité » : change de couleur selon l'état et affiche le
/// véhicule et la note en dessous.
class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.available,
    required this.busy,
    required this.onChanged,
    required this.vehicle,
    required this.ratingLabel,
    required this.badge,
  });

  final bool available;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final String vehicle;
  final String? ratingLabel;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 400);
    final accent = available ? AppColors.orange : const Color(0xFF8A7566);

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        color: available ? _cream : Colors.white,
        border: Border.all(
          color: available ? AppColors.orange.withValues(alpha: 0.6) : _line,
          width: available ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: available
                ? AppColors.orange.withValues(alpha: 0.22)
                : const Color(0x14B45309),
            blurRadius: available ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Ripple(
                active: available,
                child: AnimatedContainer(
                  duration: duration,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: available
                        ? [
                            BoxShadow(
                              color: AppColors.orange.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : const [],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: Tween(begin: 0.85, end: 1.0).animate(anim),
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: Icon(
                      available ? Icons.bolt_rounded : Icons.bedtime_rounded,
                      key: ValueKey(available),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Row(
                        key: ValueKey(available),
                        children: [
                          if (available) ...[
                            const _PulseDot(color: AppColors.orange, size: 8),
                            const SizedBox(width: 2),
                          ],
                          Flexible(
                            child: Text(
                              available ? 'En ligne' : 'Hors ligne',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      available
                          ? 'Vous recevez les nouvelles missions'
                          : 'Activez pour recevoir des missions',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.05,
                child: Switch(
                  value: available,
                  onChanged: busy ? null : onChanged,
                  activeTrackColor: AppColors.orange,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFEADBCB),
                  inactiveThumbColor: Colors.white,
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          const Divider(height: 1, color: _line),
          const SizedBox(height: AppDimens.md),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: const Icon(Icons.two_wheeler_rounded,
                    size: 20, color: AppColors.orange),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (ratingLabel != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 16, color: AppColors.goldDark),
                          const SizedBox(width: 3),
                          Text(
                            'Note $ratingLabel',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
        ],
      ),
    );
  }
}

/// Carte « Gains » orange : dégradé qui tourne, bulles flottantes, reflet,
/// montant animé, barre de progression lumineuse et flèche qui pulse.
class _EarningsCard extends StatefulWidget {
  const _EarningsCard({
    required this.loaded,
    required this.earnings,
    required this.delivered,
    required this.total,
    required this.scale,
    required this.onTap,
  });

  final bool loaded;
  final int earnings;
  final int delivered;
  final int total;
  final double scale;
  final VoidCallback onTap;

  @override
  State<_EarningsCard> createState() => _EarningsCardState();
}

class _EarningsCardState extends State<_EarningsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bubble(double t, {
    required double size,
    required double alpha,
    required double phase,
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) {
    final a = (t + phase) * 2 * math.pi;
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Transform.translate(
        offset: Offset(10 * math.sin(a), 8 * math.cos(a)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rate = widget.total == 0 ? 0.0 : widget.delivered / widget.total;
    final amountSize = (36 * widget.scale).clamp(30.0, 42.0).toDouble();

    return _Pressable(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final angle = math.pi / 4 + 0.6 * math.sin(t * 2 * math.pi);
          final arrowShift = 4 * (math.sin(t * 2 * math.pi * 4) + 1) / 2;

          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              gradient: LinearGradient(
                begin: Alignment(math.cos(angle), math.sin(angle)),
                end: Alignment(-math.cos(angle), -math.sin(angle)),
                colors: const [
                  AppColors.orange,
                  AppColors.orangeDark,
                  Color(0xFFFF9A3D),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.38),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                _bubble(t, size: 140, alpha: 0.13, phase: 0.0, right: -40, top: -40),
                _bubble(t, size: 110, alpha: 0.09, phase: 0.35, left: -34, bottom: -50),
                _bubble(t, size: 46, alpha: 0.12, phase: 0.7, right: 70, bottom: 36),
                // Reflet diagonal qui traverse la carte.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment(-1.9 + 3.8 * t, 0),
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 80,
                          height: 460,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppDimens.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.payments_rounded,
                                size: 19, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Gains cumulés',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: widget.loaded
                                  ? _CountUp(
                                      value: widget.earnings,
                                      format: (n) =>
                                          formatAmount(n, showSymbol: false).trim(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: amountSize,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1,
                                      ),
                                    )
                                  : Text(
                                      '…',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: amountSize,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 7),
                            child: Text(
                              'FCFA',
                              style: TextStyle(
                                color: Color(0xFFFFE9C7),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Taux de livraison',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: widget.loaded ? rate : 0),
                            duration: const Duration(milliseconds: 1300),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => Text(
                              '${(v * 100).round()} %',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: widget.loaded ? rate : 0),
                        duration: const Duration(milliseconds: 1300),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: v.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.loaded
                                  ? '${widget.delivered} livraison${widget.delivered > 1 ? 's' : ''} effectuée${widget.delivered > 1 ? 's' : ''}'
                                  : 'Chargement…',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusPill),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Retirer',
                                  style: TextStyle(
                                    color: AppColors.orangeDark,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Transform.translate(
                                  offset: Offset(arrowShift, 0),
                                  child: const Icon(Icons.arrow_forward_rounded,
                                      size: 17, color: AppColors.orangeDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.index,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final Color color;
  final Widget value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            // L'icône « rebondit » à l'apparition, décalée selon la tuile.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 1100 + index * 150),
              curve: Interval(
                0.25 + index * 0.08,
                1.0,
                curve: Curves.elasticOut,
              ),
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: color),
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(fit: BoxFit.scaleDown, child: value),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            // Petite barre d'accent qui se déploie.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 900 + index * 150),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Container(
                width: 28 * v,
                height: 3.5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// Groupe de lignes de menu dans une carte ; chaque ligne glisse en cascade.
class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.entries});

  final String title;
  final List<_MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: _cardDecoration(),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 450 + i * 110),
                    curve: Curves.easeOutCubic,
                    child: _MenuRow(entry: entries[i]),
                    builder: (context, v, child) => Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(26 * (1 - v), 0),
                        child: child,
                      ),
                    ),
                  ),
                  if (i < entries.length - 1)
                    const Divider(height: 1, indent: 70, color: _line),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        entry.onTap();
      },
      splashColor: entry.color.withValues(alpha: 0.14),
      highlightColor: entry.color.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: entry.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, size: 22, color: entry.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 24, color: entry.color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}