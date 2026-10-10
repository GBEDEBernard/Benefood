import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
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

/// Compte livreur (J165) : carte verte, statistiques de missions, menu « Mon
/// compte » et sections routées — même langage visuel que le profil client
/// (J171).
class DriverAccountScreen extends StatefulWidget {
  const DriverAccountScreen({
    super.key,
    required this.session,
    required this.marketplace,
    required this.onSelectTab,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;
  final ValueChanged<int> onSelectTab;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileHeader(
              marketplace: widget.marketplace,
              uploadingAvatar: _uploadingAvatar,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    const ProfilePageTitle('Mon profil'),
                    ProfileHero(
                      user: user,
                      badges: _buildBadges(),
                      stats: _buildStats(),
                      uploadingAvatar: _uploadingAvatar,
                      onEditAvatar: _pickAvatar,
                      onShowQr: () => showContactQrSheet(context, user),
                    ),
                    const SizedBox(height: AppDimens.xl),
                    const ProfileSectionTitle('Mon profil livreur'),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      ErrorState(message: _error!, onRetry: _load)
                    else
                      _buildDriverCard(),
                    const SizedBox(height: AppDimens.xl),
                    const ProfileSectionTitle('Mon compte'),
                    ProfileMenuCard(entries: _buildMenuEntries()),
                    if ((user?.contexts.length ?? 1) > 1) ...[
                      const ProfileSectionTitle('Espaces accessibles'),
                      ProfileSpacesMenu(
                        session: widget.session,
                        currentContext: AppContext.driver,
                      ),
                    ],
                    const SizedBox(height: AppDimens.lg),
                    ProfileLogoutButton(onConfirm: _confirmLogout),
                    const SizedBox(height: AppDimens.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBadges() {
    final rawProfile = _status?['profile'];
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
    final rawStatus = profile?['status'];
    final status = rawStatus is String ? rawStatus : null;
    final palette = BadgePalette.driver(status);

    return [
      if (palette != null)
        ProfileStatusPill(label: palette.$1, color: palette.$2),
      const ProfileLabelBadge(
        icon: Icons.delivery_dining_outlined,
        label: 'Espace livreur',
      ),
    ];
  }

  List<ProfileStat> _buildStats() {
    final rawProfile = _status?['profile'];
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
    final rating = profile?['rating'];
    final ratingLabel = rating is num ? '$rating'.replaceAll('.', ',') : '—';

    return [
      ProfileStat(
        icon: Icons.delivery_dining_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        value: _statsLoaded ? '${_deliveries.length}' : '…',
        label: 'Missions',
        onTap: () => widget.onSelectTab(2),
      ),
      ProfileStat(
        icon: Icons.check_circle_outline,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        value: _statsLoaded ? '$_deliveredCount' : '…',
        label: 'Livrées',
        onTap: () => widget.onSelectTab(2),
      ),
      ProfileStat(
        icon: Icons.payments_outlined,
        tint: AppColors.goldLight,
        accent: AppColors.goldDark,
        value: _statsLoaded
            ? formatAmount(_earnings, showSymbol: false).trim()
            : '…',
        suffix: 'FCFA',
        label: 'Gains',
        onTap: () => widget.onSelectTab(2),
      ),
      ProfileStat(
        icon: Icons.star_rate,
        tint: AppColors.goldLight,
        accent: AppColors.goldDark,
        value: _statsLoaded ? ratingLabel : '…',
        label: 'Note',
      ),
    ];
  }

  List<ProfileMenuEntry> _buildMenuEntries() {
    return [
      ProfileMenuEntry(
        icon: Icons.account_balance_wallet_outlined,
        tint: AppColors.goldLight,
        accent: AppColors.goldDark,
        title: 'Mes gains & retraits',
        subtitle: 'Solde disponible, séquestre, retirer',
        onTap: () => _openRoute('/driver/wallet'),
      ),
      ProfileMenuEntry(
        icon: Icons.person_outline,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        title: 'Informations personnelles',
        subtitle: 'Nom, e-mail, photo...',
        onTap: () => _openRoute('/driver/profile/edit'),
      ),
      ProfileMenuEntry(
        icon: Icons.notifications_none,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        title: 'Notifications',
        subtitle: 'Commandes, alertes, offres...',
        onTap: () => _openRoute('/driver/notifications'),
      ),
      ProfileMenuEntry(
        icon: Icons.shield_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        title: 'Sécurité',
        subtitle: 'Mot de passe, appareils...',
        onTap: () => _openRoute('/driver/security'),
      ),
      ProfileMenuEntry(
        icon: Icons.help_outline,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        title: 'Aide et support',
        subtitle: 'Questions fréquentes, nous contacter...',
        onTap: () => _openRoute('/driver/complaints'),
      ),
    ];
  }

  Widget _buildDriverCard() {
    final theme = Theme.of(context);
    final rawProfile = _status?['profile'];
    final profile = rawProfile is Map<String, dynamic> ? rawProfile : null;
    final rawStatus = profile?['status'];
    final status = rawStatus is String ? rawStatus : null;
    final palette = BadgePalette.driver(status);
    final rawVehicle = profile?['vehicle'];
    final vehicle = rawVehicle is String ? rawVehicle : null;
    final rating = profile?['rating'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vehicle == null || vehicle.isEmpty
                        ? 'Livreur Béninfood'
                        : vehicle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (palette != null)
                  StatusBadge(
                    label: palette.$1,
                    color: palette.$2,
                    small: true,
                  ),
              ],
            ),
            if (rating != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.star_rate, size: 18, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text('Note : $rating', style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _available,
              onChanged: _toggling ? null : _toggleAvailability,
              title: const Text('Disponible pour les livraisons'),
            ),
          ],
        ),
      ),
    );
  }
}
