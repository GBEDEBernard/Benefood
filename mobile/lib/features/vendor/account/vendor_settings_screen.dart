import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/feedback_widgets.dart';

/// Préférences de la boutique (J21 §3.6) : mode de reversement, préférences de
/// notifications et langue de l'espace vendeur.
class VendorSettingsScreen extends StatefulWidget {
  const VendorSettingsScreen({super.key, required this.marketplace});

  final MarketplaceApi marketplace;

  @override
  State<VendorSettingsScreen> createState() => _VendorSettingsScreenState();
}

class _VendorSettingsScreenState extends State<VendorSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _payoutMethod;
  final TextEditingController _payoutDetails = TextEditingController();
  bool _autoAccept = false;
  bool _notifyNewOrders = true;
  bool _notifyCancellations = true;
  bool _notifyPayments = true;
  String _locale = 'fr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _payoutDetails.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.marketplace.vendorSettings();
      if (!mounted) return;
      setState(() {
        _payoutMethod = data['payout_method'] as String?;
        _payoutDetails.text = (data['payout_details'] as String?) ?? '';
        _autoAccept = data['auto_accept'] as bool? ?? false;
        _notifyNewOrders = data['notify_new_orders'] as bool? ?? true;
        _notifyCancellations = data['notify_cancellations'] as bool? ?? true;
        _notifyPayments = data['notify_payments'] as bool? ?? true;
        _locale = (data['locale'] as String?) ?? 'fr';
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.marketplace.updateVendorSettings(
        autoAccept: _autoAccept,
        payoutMethod: _payoutMethod,
        payoutDetails: _payoutDetails.text.trim(),
        notifyNewOrders: _notifyNewOrders,
        notifyCancellations: _notifyCancellations,
        notifyPayments: _notifyPayments,
        locale: _locale,
      );
      if (!mounted) return;
      showToast(context, 'Préférences enregistrées.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text('Préférences boutique'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimens.md),
      children: [
        _sectionTitle('Mode de reversement'),
        _card(
          child: RadioGroup<String>(
            groupValue: _payoutMethod,
            onChanged: (value) => setState(() => _payoutMethod = value),
            child: Column(
              children: [
                for (final option in const [
                  ('mobile_money', 'Mobile Money', Icons.phone_android),
                  ('bank', 'Virement bancaire', Icons.account_balance),
                  ('cash', 'Espèces', Icons.payments_outlined),
                ])
                  RadioListTile<String>(
                    value: option.$1,
                    activeColor: AppColors.green,
                    title: Text(option.$2),
                    secondary: Icon(option.$3, color: AppColors.green),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _payoutDetails,
                    decoration: const InputDecoration(
                      labelText: 'Coordonnées de reversement',
                      hintText: 'N° Mobile Money ou IBAN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _sectionTitle('Commandes'),
        _card(
          child: SwitchListTile(
            value: _autoAccept,
            activeTrackColor: AppColors.green,
            onChanged: (v) => setState(() => _autoAccept = v),
            title: const Text('Acceptation automatique'),
            subtitle: const Text('Les commandes payées sont acceptées sans action manuelle'),
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _sectionTitle('Notifications'),
        _card(
          child: Column(
            children: [
              SwitchListTile(
                value: _notifyNewOrders,
                activeTrackColor: AppColors.green,
                onChanged: (v) => setState(() => _notifyNewOrders = v),
                title: const Text('Nouvelles commandes'),
              ),
              SwitchListTile(
                value: _notifyCancellations,
                activeTrackColor: AppColors.green,
                onChanged: (v) => setState(() => _notifyCancellations = v),
                title: const Text('Annulations'),
              ),
              SwitchListTile(
                value: _notifyPayments,
                activeTrackColor: AppColors.green,
                onChanged: (v) => setState(() => _notifyPayments = v),
                title: const Text('Paiements et reversements'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.lg),
        _sectionTitle('Langue'),
        _card(
          child: RadioGroup<String>(
            groupValue: _locale,
            onChanged: (value) => setState(() => _locale = value ?? 'fr'),
            child: const Column(
              children: [
                RadioListTile<String>(
                  value: 'fr',
                  activeColor: AppColors.green,
                  title: Text('Français'),
                ),
                RadioListTile<String>(
                  value: 'en',
                  activeColor: AppColors.green,
                  title: Text('English'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppColors.green,
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : const Text('Enregistrer les préférences'),
        ),
      ],
    );
  }

  Widget _sectionTitle(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}
