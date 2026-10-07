import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/profile_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Compte vendeur (J157) : carte verte, statistiques boutique, menu « Mon
/// compte » et sections routées — même langage visuel que le profil client
/// (J171).
class VendorAccountScreen extends StatefulWidget {
  const VendorAccountScreen({
    super.key,
    required this.session,
    required this.marketplace,
    required this.onSelectTab,
  });

  final SessionProvider session;
  final MarketplaceApi marketplace;
  final ValueChanged<int> onSelectTab;

  @override
  State<VendorAccountScreen> createState() => _VendorAccountScreenState();
}

class _VendorAccountScreenState extends State<VendorAccountScreen> {
  Map<String, dynamic>? _status;
  List<Product> _products = [];
  List<Order> _orders = [];
  bool _statsLoaded = false;
  bool _loading = true;
  String? _error;
  bool _uploadingAvatar = false;
  bool _uploadingLogo = false;
  bool _uploadingCover = false;

  Uint8List? _logoBytes;
  Uint8List? _coverBytes;

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
      final status = await widget.marketplace.vendorStatus();
      var products = <Product>[];
      var orders = <Order>[];
      var statsLoaded = false;
      try {
        final results = await Future.wait<List<Object>>([
          widget.marketplace.vendorProducts(),
          widget.marketplace.vendorOrders(perPage: 50),
        ]);
        products = results[0].cast<Product>();
        orders = results[1].cast<Order>();
        statsLoaded = true;
      } on ApiException catch (_) {
        // Les compteurs restent au dernier état connu (ou « … »).
      }
      if (mounted) {
        setState(() {
          _status = status;
          _products = products;
          _orders = orders;
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

  int get _pendingOrders => _orders
      .where(
        (o) =>
            o.canVendorAccept ||
            o.canVendorRefuse ||
            o.canVendorPrepare ||
            o.canVendorReady,
      )
      .length;

  int get _revenue => _orders
      .where((o) => o.status == 'delivered')
      .fold(0, (sum, o) => sum + o.total);

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

  Future<void> _pickImage({required bool isLogo}) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
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
      await _uploadMedia(isLogo: isLogo, bytes: bytes);
    } catch (_) {
      if (mounted) {
        showToast(context, 'Impossible de charger l\'image.', isError: true);
      }
    }
  }

  Future<void> _uploadMedia({
    required bool isLogo,
    required List<int> bytes,
  }) async {
    setState(() {
      if (isLogo) {
        _uploadingLogo = true;
      } else {
        _uploadingCover = true;
      }
    });
    try {
      if (isLogo) {
        await widget.marketplace.updateVendorMedia(logo: bytes);
      } else {
        await widget.marketplace.updateVendorMedia(cover: bytes);
      }
      if (mounted) {
        showToast(
          context,
          isLogo ? 'Logo mis à jour.' : 'Photo de couverture mise à jour.',
        );
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingLogo = false;
          _uploadingCover = false;
        });
      }
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
                    const ProfileSectionTitle('Ma boutique'),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      ErrorState(message: _error!, onRetry: _load)
                    else ...[
                      _buildVendorCard(),
                      const SizedBox(height: 16),
                      _buildMediaSection(),
                    ],
                    const SizedBox(height: AppDimens.xl),
                    const ProfileSectionTitle('Mon compte'),
                    ProfileMenuCard(entries: _buildMenuEntries()),
                    if ((user?.contexts.length ?? 1) > 1) ...[
                      const ProfileSectionTitle('Espaces accessibles'),
                      ProfileSpacesMenu(
                        session: widget.session,
                        currentContext: AppContext.vendor,
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
    final rawVendor = _status?['vendor'];
    final vendor = rawVendor is Map<String, dynamic> ? rawVendor : null;
    final palette = BadgePalette.vendor(_stringOrNull(vendor?['status']));

    return [
      if (palette != null)
        ProfileStatusPill(label: palette.$1, color: palette.$2),
      const ProfileLabelBadge(
        icon: Icons.storefront_outlined,
        label: 'Espace vendeur',
      ),
    ];
  }

  List<ProfileStat> _buildStats() {
    return [
      ProfileStat(
        icon: Icons.shopping_bag_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        value: _statsLoaded ? '${_products.length}' : '…',
        label: 'Produits',
        onTap: () => widget.onSelectTab(1),
      ),
      ProfileStat(
        icon: Icons.receipt_long_outlined,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        value: _statsLoaded ? '${_orders.length}' : '…',
        label: 'Commandes',
        onTap: () => widget.onSelectTab(2),
      ),
      ProfileStat(
        icon: Icons.schedule_outlined,
        tint: AppColors.goldLight,
        accent: AppColors.goldDark,
        value: _statsLoaded ? '$_pendingOrders' : '…',
        label: 'En attente',
        onTap: () => widget.onSelectTab(2),
      ),
      ProfileStat(
        icon: Icons.payments_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        value: _statsLoaded
            ? formatAmount(_revenue, showSymbol: false).trim()
            : '…',
        suffix: 'FCFA',
        label: 'Revenus',
        onTap: () => widget.onSelectTab(0),
      ),
    ];
  }

  List<ProfileMenuEntry> _buildMenuEntries() {
    return [
      ProfileMenuEntry(
        icon: Icons.person_outline,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        title: 'Informations personnelles',
        subtitle: 'Nom, e-mail, photo...',
        onTap: () => _openRoute('/vendor/profile/edit'),
      ),
      ProfileMenuEntry(
        icon: Icons.notifications_none,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        title: 'Notifications',
        subtitle: 'Commandes, alertes, offres...',
        onTap: () => _openRoute('/vendor/notifications'),
      ),
      ProfileMenuEntry(
        icon: Icons.shield_outlined,
        tint: AppColors.greenLight,
        accent: AppColors.green,
        title: 'Sécurité',
        subtitle: 'Mot de passe, appareils...',
        onTap: () => _openRoute('/vendor/security'),
      ),
      ProfileMenuEntry(
        icon: Icons.help_outline,
        tint: AppColors.orangeLight,
        accent: AppColors.orange,
        title: 'Aide et support',
        subtitle: 'Questions fréquentes, nous contacter...',
        onTap: () => _openRoute('/vendor/complaints'),
      ),
    ];
  }

  Widget _buildVendorCard() {
    final theme = Theme.of(context);
    final rawVendor = _status?['vendor'];
    final vendor = rawVendor is Map<String, dynamic> ? rawVendor : null;
    final status = _stringOrNull(vendor?['status']);
    final palette = BadgePalette.vendor(status);
    final businessName =
        _stringOrNull(vendor?['business_name']) ?? 'Ma boutique';
    final city = _stringOrNull(vendor?['city']);
    final phone = _stringOrNull(vendor?['phone']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            if (city != null && city.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(city, style: theme.textTheme.bodyMedium),
            ],
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(phone, style: theme.textTheme.bodyMedium),
            ],
            if (status != null && status != 'active') ...[
              const SizedBox(height: 8),
              Text(
                'Votre dossier est en cours de vérification. Vous pourrez gérer vos produits dès validation.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    final theme = Theme.of(context);
    final rawVendor = _status?['vendor'];
    final vendor = rawVendor is Map<String, dynamic> ? rawVendor : null;
    final logoUrl = _stringOrNull(vendor?['logo_url']);
    final coverUrl = _stringOrNull(vendor?['cover_url']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo de la boutique', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildMediaTile(
          title: 'Logo',
          subtitle: 'Le logo est affiché dans le catalogue',
          bytes: _logoBytes,
          remoteUrl: logoUrl,
          isLoading: _uploadingLogo,
          onPick: () => _pickImage(isLogo: true),
        ),
        const SizedBox(height: 12),
        _buildMediaTile(
          title: 'Couverture',
          subtitle: 'La photo de couverture en haut de la fiche boutique',
          bytes: _coverBytes,
          remoteUrl: coverUrl,
          isLoading: _uploadingCover,
          onPick: () => _pickImage(isLogo: false),
        ),
      ],
    );
  }

  Widget _buildMediaTile({
    required String title,
    required String subtitle,
    required Uint8List? bytes,
    required String? remoteUrl,
    required bool isLoading,
    required VoidCallback onPick,
  }) {
    final theme = Theme.of(context);
    final preview = bytes != null
        ? Image.memory(bytes, fit: BoxFit.cover)
        : AppNetworkImage(url: remoteUrl, icon: Icons.storefront);
    final hasImage =
        bytes != null || (remoteUrl != null && remoteUrl.isNotEmpty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (hasImage) const SizedBox(width: 8),
                if (hasImage)
                  TextButton(onPressed: onPick, child: const Text('Modifier')),
              ],
            ),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 96,
                width: double.infinity,
                child: preview,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(hasImage ? 'Changer la photo' : 'Ajouter une photo'),
              onPressed: isLoading ? null : onPick,
            ),
          ],
        ),
      ),
    );
  }
}

String? _stringOrNull(dynamic value) => value is String ? value : null;
