import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/state_widgets.dart';

/// Compte vendeur (J157) : profil, statut boutique, espaces et déconnexion.
class VendorAccountScreen extends StatefulWidget {
  const VendorAccountScreen({super.key, required this.session, required this.marketplace});

  final SessionProvider session;
  final MarketplaceApi marketplace;

  @override
  State<VendorAccountScreen> createState() => _VendorAccountScreenState();
}

class _VendorAccountScreenState extends State<VendorAccountScreen> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;
  bool _switching = false;
  bool _loggingOut = false;
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
      if (mounted) {
        setState(() {
          _status = status;
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

  Future<void> _switchToClient() async {
    setState(() => _switching = true);
    try {
      await widget.session.switchRole('client');
      if (mounted) {
        context.go('/client');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _switching = false);
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
    setState(() => _loggingOut = true);
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

  Future<void> _uploadMedia({required bool isLogo, required List<int> bytes}) async {
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
        showToast(context, isLogo ? 'Logo mis à jour.' : 'Photo de couverture mise à jour.');
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      _initials(user?.name ?? '?'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (user != null) Text(user.phone, style: theme.textTheme.bodySmall),
                        if (user?.email != null) Text(user!.email!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ma boutique', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else
            _buildVendorCard(),
          if (!_loading && _error == null) ...[
            const SizedBox(height: 16),
            _buildMediaSection(),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Rafraîchir',
            variant: AppButtonVariant.outline,
            icon: Icons.refresh,
            onPressed: _load,
          ),
          if (user?.hasRoleClient ?? false) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Retour à l\'espace client',
              icon: Icons.shopping_bag_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _switching ? null : _switchToClient,
              loading: _switching,
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: 'Se déconnecter',
            icon: Icons.logout,
            variant: AppButtonVariant.danger,
            onPressed: _loggingOut ? null : _confirmLogout,
            loading: _loggingOut,
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard() {
    final theme = Theme.of(context);
    final rawVendor = _status?['vendor'];
    final vendor = rawVendor is Map<String, dynamic> ? rawVendor : null;
    final status = _stringOrNull(vendor?['status']);
    final palette = BadgePalette.vendor(status);
    final businessName = _stringOrNull(vendor?['business_name']) ?? 'Ma boutique';
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
                Icon(Icons.storefront_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(businessName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (palette != null) StatusBadge(label: palette.$1, color: palette.$2, small: true),
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
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
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
    final hasImage = bytes != null || (remoteUrl != null && remoteUrl.isNotEmpty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                if (hasImage) const SizedBox(width: 8),
                if (hasImage)
                  TextButton(
                    onPressed: onPick,
                    child: const Text('Modifier'),
                  ),
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
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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