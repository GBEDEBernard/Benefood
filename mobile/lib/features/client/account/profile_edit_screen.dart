import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Édition du profil client : photo (upload), nom et e-mail (J153).
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.marketplace,
    required this.session,
  });

  final MarketplaceApi marketplace;
  final SessionProvider session;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = widget.session.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
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
        showToast(context, 'Photo de profil mise à jour');
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.marketplace.updateMe(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      );
      await widget.session.refreshProfile();
      if (!mounted) {
        return;
      }
      showToast(context, 'Profil mis à jour');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final name = (user?.name ?? '').trim();
    final initials = _initials(name.isEmpty ? 'Utilisateur' : name);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Informations personnelles')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.greenLight,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: user?.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            user!.avatarUrl!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Text(
                              initials,
                              style: const TextStyle(
                                color: AppColors.green,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          initials,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                if (_uploadingAvatar)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.surface,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _uploadingAvatar ? null : _pickAvatar,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Changer la photo'),
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              boxShadow: AppTheme.softShadow(),
            ),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.orangeLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_outlined,
                    size: 20,
                    color: AppColors.orange,
                  ),
                ),
                title: const Text('Téléphone'),
                subtitle: Text(
                  (user?.phone ?? '').isEmpty ? '—' : user!.phone,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: user?.phoneVerifiedAt != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusPill,
                          ),
                        ),
                        child: const Text(
                          'Vérifié',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le numéro de téléphone est lié à votre compte vérifié par SMS '
            'et ne peut pas être modifié ici.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Enregistrer'),
          ),
          const SizedBox(height: AppDimens.lg),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first[0]
        : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}
