import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Sécurité du compte : changement de mot de passe et appareils connectés.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  late Future<List<Map<String, dynamic>>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _devicesFuture = widget.marketplace.myDevices();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.marketplace.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      setState(() => _devicesFuture = widget.marketplace.myDevices());
      if (mounted) {
        showToast(context, 'Mot de passe modifié avec succès');
      }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sécurité')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              boxShadow: AppTheme.softShadow(),
            ),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Changer le mot de passe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppDimens.lg),
                      TextFormField(
                        controller: _currentController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe actuel',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Saisissez votre mot de passe actuel.'
                            : null,
                      ),
                      const SizedBox(height: AppDimens.lg),
                      TextFormField(
                        controller: _newController,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        validator: (value) {
                          final text = value ?? '';
                          if (text.length < 8) {
                            return '8 caractères minimum.';
                          }
                          if (text == _currentController.text) {
                            return 'Choisissez un mot de passe différent.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimens.lg),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) => value != _newController.text
                            ? 'Les mots de passe ne correspondent pas.'
                            : null,
                      ),
                      const SizedBox(height: AppDimens.sm),
                      const Text(
                        'Après modification, les autres appareils seront '
                        'déconnectés.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Modifier le mot de passe'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          const Padding(
            padding: EdgeInsets.only(bottom: AppDimens.sm),
            child: Text(
              'Appareils connectés',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              boxShadow: AppTheme.softShadow(),
            ),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _devicesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(AppDimens.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const ListTile(
                      leading: Icon(Icons.error_outline),
                      title: Text('Appareils indisponibles'),
                    );
                  }
                  final devices = snapshot.data ?? const [];
                  if (devices.isEmpty) {
                    return const ListTile(
                      leading: Icon(Icons.phonelink_lock_outlined),
                      title: Text('Aucun appareil enregistré'),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < devices.length; i++) ...[
                        _DeviceTile(device: devices[i]),
                        if (i < devices.length - 1)
                          const Divider(
                            height: 1,
                            indent: 64,
                            endIndent: 16,
                            color: AppColors.border,
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppDimens.xl),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final Map<String, dynamic> device;

  @override
  Widget build(BuildContext context) {
    final platform = device['platform'] is String
        ? device['platform'] as String
        : '';
    final version = device['app_version'] is String
        ? device['app_version'] as String
        : '';
    final lastSeen = device['last_seen_at'] is String
        ? device['last_seen_at'] as String
        : '';
    final isActive = device['is_active'] == true;

    final icon = switch (platform) {
      'android' => Icons.android,
      'ios' => Icons.phone_iphone,
      _ => Icons.phonelink_outlined,
    };

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.greenLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.green),
      ),
      title: Text(
        platform.isEmpty ? 'Appareil' : platform.toUpperCase(),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          if (version.isNotEmpty) 'v$version',
          if (lastSeen.isNotEmpty) 'Vu ${formatDateTime(lastSeen)}',
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: isActive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: const Text(
                'Actif',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
            )
          : null,
    );
  }
}
