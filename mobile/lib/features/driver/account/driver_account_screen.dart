import 'package:flutter/material.dart';
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
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

const _ink = Color(0xFF151B2B);
const _inkDeep = Color(0xFF0A0E1A);
const _line = Color(0xFFEDEFEA);
const _violet = Color(0xFF7C3AED);
const _sky = Color(0xFF0EA5E9);
const _rose = Color(0xFFE11D48);

/// Compte livreur : identité, disponibilité, gains, statistiques de missions
/// et menu groupé « Activité / Compte / Support ».
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
    final pad = AppDimens.pagePadding;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
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
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(pad, AppDimens.lg, pad, AppDimens.xxl),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 14),
                    child: Text(
                      'Mon profil',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  _reveal(0, _buildHero(user)),
                  const SizedBox(height: AppDimens.lg),
                  _reveal(1, _buildAvailabilitySlot()),
                  const SizedBox(height: AppDimens.md),
                  _reveal(2, _buildEarningsCard()),
                  const SizedBox(height: AppDimens.xl),
                  _reveal(
                    3,
                    _MenuSection(
                      title: 'Activité',
                      entries: [
                        _MenuEntry(
                          icon: Icons.insights_rounded,
                          color: _violet,
                          title: 'Mes statistiques',
                          subtitle: 'Gains, missions et dernières livraisons',
                          onTap: () => _openRoute('/driver/stats'),
                        ),
                        _MenuEntry(
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.goldDark,
                          title: 'Mes gains & retraits',
                          subtitle: 'Solde disponible, séquestre, retirer',
                          onTap: () => _openRoute('/driver/wallet'),
                        ),
                        _MenuEntry(
                          icon: Icons.people_alt_rounded,
                          color: AppColors.orange,
                          title: 'Mes clients',
                          subtitle: 'Demandes de favori à accepter',
                          onTap: () => _openRoute('/driver/favorite-clients'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.lg),
                  _reveal(
                    4,
                    _MenuSection(
                      title: 'Compte',
                      entries: [
                        _MenuEntry(
                          icon: Icons.person_rounded,
                          color: _sky,
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
                          color: _rose,
                          title: 'Sécurité',
                          subtitle: 'Mot de passe, appareils',
                          onTap: () => _openRoute('/driver/security'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.lg),
                  _reveal(
                    5,
                    _MenuSection(
                      title: 'Support',
                      entries: [
                        _MenuEntry(
                          icon: Icons.headset_mic_rounded,
                          color: _violet,
                          title: 'Aide et support',
                          subtitle: 'Questions fréquentes, nous contacter',
                          onTap: () => _openRoute('/driver/complaints'),
                        ),
                      ],
                    ),
                  ),
                  if ((user?.contexts.length ?? 1) > 1) ...[
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Apparition en cascade (une seule fois) : fondu + légère remontée.
  Widget _reveal(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 70),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
    );
  }

  // ───────────────────────── Identité (bannière) ─────────────────────────

  /// Bannière d'identité : carte verte (photo de profil, badges, QR code)
  /// + bandeau de statistiques en surimpression.
  Widget _buildHero(User? user) {
    final status = _profile?['status'];
    final palette = BadgePalette.driver(status is String ? status : null);
    final rating = _profile?['rating'];
    final ratingLabel = rating is num ? '$rating'.replaceAll('.', ',') : '—';

    return ProfileHero(
      user: user,
      padding: EdgeInsets.zero,
      badges: [
        if (palette != null)
          ProfileStatusPill(label: palette.$1, color: palette.$2),
        const ProfileLabelBadge(
          icon: Icons.delivery_dining_outlined,
          label: 'Espace livreur',
        ),
      ],
      stats: [
        ProfileStat(
          icon: Icons.two_wheeler_rounded,
          tint: AppColors.greenLight,
          accent: AppColors.green,
          value: _statsLoaded ? '${_deliveries.length}' : '…',
          label: 'Missions',
          onTap: () => widget.onSelectTab(0),
        ),
        ProfileStat(
          icon: Icons.check_circle_rounded,
          tint: AppColors.orangeLight,
          accent: AppColors.orange,
          value: _statsLoaded ? '$_deliveredCount' : '…',
          label: 'Livrées',
          onTap: () => widget.onSelectTab(3),
        ),
        ProfileStat(
          icon: Icons.star_rounded,
          tint: AppColors.goldLight,
          accent: AppColors.goldDark,
          value: _statsLoaded ? ratingLabel : '…',
          label: 'Note',
          onTap: _showRatingSheet,
        ),
      ],
      uploadingAvatar: _uploadingAvatar,
      onEditAvatar: _pickAvatar,
      onShowQr: () => showContactQrSheet(context, widget.session.user),
    );
  }

  // ───────────────────────── Disponibilité + véhicule ─────────────────────────

  Widget _buildAvailabilitySlot() {
    if (_loading && _status == null) {
      return Container(
        height: 150,
        decoration: _cardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
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
          : StatusBadge(label: palette.$1, color: palette.$2, small: true),
    );
  }

  // ───────────────────────── Gains ─────────────────────────

  Widget _buildEarningsCard() {
    final amount = _statsLoaded
        ? formatAmount(_earnings, showSymbol: false).trim()
        : '…';

    return _Pressable(
      onTap: () => _openRoute('/driver/wallet'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_ink, _inkDeep],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x3315203A), blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -34,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orange.withValues(alpha: 0.16),
                ),
              ),
            ),
            Positioned(
              right: 26,
              bottom: -44,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.10),
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
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.payments_rounded,
                            size: 18, color: AppColors.gold),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Gains cumulés',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              amount,
                              key: ValueKey(amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: Text(
                          'FCFA',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _statsLoaded
                              ? '$_deliveredCount livraison${_deliveredCount > 1 ? 's' : ''} effectuée${_deliveredCount > 1 ? 's' : ''}'
                              : 'Chargement…',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Retirer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                size: 16, color: Colors.white),
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
      ),
    );
  }

  // ───────────────────────── Mini statistiques ─────────────────────────

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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded,
                    size: 36, color: AppColors.goldDark),
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
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
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
        BoxShadow(color: Color(0x0D18231F), blurRadius: 14, offset: Offset(0, 5)),
      ],
    );

/// Effet de pression : légère réduction à l'appui.
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
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
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
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
        ),
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
    const duration = Duration(milliseconds: 320);
    final accent = available ? AppColors.orange : const Color(0xFF94A3B8);

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        color: available ? const Color(0xFFFFF6EE) : Colors.white,
        border: Border.all(
          color: available ? AppColors.orange.withValues(alpha: 0.4) : _line,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0D18231F), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: duration,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  available ? Icons.bolt_rounded : Icons.bedtime_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        available ? 'En ligne' : 'Hors ligne',
                        key: ValueKey(available),
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      available
                          ? 'Vous recevez les nouvelles missions'
                          : 'Activez pour recevoir des missions',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: available,
                onChanged: busy ? null : onChanged,
                activeTrackColor: AppColors.orange,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          const Divider(height: 1, color: _line),
          const SizedBox(height: AppDimens.md),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.two_wheeler_rounded,
                    size: 19, color: AppColors.orange),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (ratingLabel != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 15, color: AppColors.goldDark),
                          const SizedBox(width: 3),
                          Text(
                            'Note $ratingLabel',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ?badge,
            ],
          ),
        ],
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

/// Groupe de lignes de menu dans une carte, avec titre de section.
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
                  _MenuRow(entry: entries[i]),
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
      onTap: entry.onTap,
      splashColor: entry.color.withValues(alpha: 0.10),
      highlightColor: entry.color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: entry.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, size: 21, color: entry.color),
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
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: Color(0xFFB4BCC8)),
          ],
        ),
      ),
    );
  }
}