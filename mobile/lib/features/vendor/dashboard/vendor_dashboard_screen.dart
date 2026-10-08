import 'package:flutter/material.dart';

import '../../../core/data/marketplace_api.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/models/order.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/status_badge.dart';

/// Tableau de bord vendeur — Layout 3 colonnes (menu gauche, centre, panneau boutique).
class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({
    super.key,
    required this.marketplace,
    required this.onGoToTab,
  });

  final MarketplaceApi marketplace;
  final ValueChanged<int> onGoToTab;

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  Map<String, dynamic>? _status;
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  bool _isOpen = true;

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
      final orders = await widget.marketplace.vendorOrders(perPage: 50);
      if (!mounted) return;
      final vendor = status['vendor'];
      final open = vendor is Map<String, dynamic> && vendor['is_open'] is bool
          ? vendor['is_open'] as bool
          : true;
      setState(() {
        _status = status;
        _orders = orders;
        _isOpen = open;
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

  /// Ouvre/ferme la boutique : mise à jour optimiste, rollback en cas d'erreur.
  Future<void> _toggleOpen(bool open) async {
    final previous = _isOpen;
    setState(() => _isOpen = open);
    try {
      await widget.marketplace.setVendorOpen(open: open);
      if (!mounted) return;
      showToast(context, open ? 'Boutique ouverte.' : 'Boutique fermée.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isOpen = previous);
      showToast(context, e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isOpen = previous);
      showToast(context, 'Une erreur est survenue. Réessayez.', isError: true);
    }
  }

  String get _businessName {
    final v = _status?['vendor'];
    if (v is Map<String, dynamic>) {
      return (v['business_name'] as String?) ?? 'Le Délice Fast-Food';
    }
    return 'Le Délice Fast-Food';
  }

  String get _city {
    final v = _status?['vendor'];
    if (v is Map<String, dynamic>) {
      return (v['city'] as String?) ?? 'Cadjèhoun, Cotonou';
    }
    return 'Cadjèhoun, Cotonou';
  }

  String? get _statusStr {
    final v = _status?['vendor'];
    if (v is Map<String, dynamic>) return v['status'] as String?;
    return null;
  }

  List<Order> get _newOrders {
    final list = [..._orders];
    list.sort((a, b) {
      final da = DateTime.tryParse(a.createdAt ?? '');
      final db = DateTime.tryParse(b.createdAt ?? '');
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return list.where((o) => o.status == 'awaiting_payment' || o.status == 'paid' || o.status == 'accepted').take(3).toList();
  }

  List<Order> get _recentOrdersList {
    final list = [..._orders];
    list.sort((a, b) {
      final da = DateTime.tryParse(a.createdAt ?? '');
      final db = DateTime.tryParse(b.createdAt ?? '');
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return list.take(4).toList();
  }

  int get _pendingCount => _orders.where((o) => o.status == 'awaiting_payment' || o.status == 'paid' || o.status == 'accepted' || o.status == 'preparing').length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        // Largeur de la colonne centrale selon le mode (sidebar + panneau
        // boutique masqués en mobile, remplacés par le panneau empilé).
        final centerW = constraints.maxWidth - (isWide ? 680 : 40);
        final sideBySide = isWide && centerW >= 700;
        final bg = const Color(0xFFF4F6F8);
        return Container(
          color: bg,
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWide) _Sidebar(onGoToTab: widget.onGoToTab, isOpen: _isOpen),
              if (isWide) const SizedBox(width: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 8),
                        child: Text(
                          'A. TABLEAU DE BORD',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.6,
                            color: Color(0xFF444B47),
                          ),
                        ),
                      ),
                      _CenterHeader(businessName: _businessName, isOpen: _isOpen, onRefresh: _load),
                      const SizedBox(height: 16),
                      _StatCards(pending: _pendingCount, orders: _orders.length),
                      const SizedBox(height: 16),
                      _QuickActions(
                        onAddProduct: () => widget.onGoToTab(1),
                        onToggleOpen: () => _toggleOpen(!_isOpen),
                        isOpen: _isOpen,
                      ),
                      const SizedBox(height: 16),
                      if (sideBySide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: centerW - 336, child: _NewOrdersList(orders: _newOrders)),
                            const SizedBox(width: 16),
                            SizedBox(width: 320, child: _RecentOrdersList(orders: _recentOrdersList)),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _NewOrdersList(orders: _newOrders),
                            const SizedBox(height: 16),
                            _RecentOrdersList(orders: _recentOrdersList),
                          ],
                        ),
                      if (!isWide) ...[
                        const SizedBox(height: 16),
                        _ShopPanel(
                          businessName: _businessName,
                          city: _city,
                          statusStr: _statusStr,
                          isOpen: _isOpen,
                          onToggle: _toggleOpen,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isWide) const SizedBox(width: 20),
              if (isWide)
                SizedBox(
                  width: 350,
                  child: _ShopPanel(
                    businessName: _businessName,
                    city: _city,
                    statusStr: _statusStr,
                    isOpen: _isOpen,
                    onToggle: _toggleOpen,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.onGoToTab, required this.isOpen});
  final ValueChanged<int> onGoToTab;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF0D3B2E), borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 36, height: 36, decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle), child: const Icon(Icons.fastfood, color: Colors.white, size: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('LE DÉLICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                  const Text('FAST-FOOD', style: TextStyle(color: Colors.white, fontSize: 9)),
                ]),
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)), child: Text(isOpen ? 'Ouvert' : 'Fermé', style: const TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 20),
          _NavItem(active: true, icon: Icons.home_outlined, label: 'Tableau de bord', onTap: () {}),
          const SizedBox(height: 8),
          _NavItem(icon: Icons.storefront_outlined, label: 'Boutique', onTap: () {}),
          const SizedBox(height: 8),
          _NavItem(icon: Icons.inventory_2_outlined, label: 'Produits', onTap: () => onGoToTab(1)),
          const SizedBox(height: 8),
          _NavItem(icon: Icons.receipt_long_outlined, label: 'Commandes', onTap: () => onGoToTab(2)),
          const SizedBox(height: 8),
          _NavItem(icon: Icons.bar_chart_outlined, label: 'Revenus', onTap: () {}),
          const SizedBox(height: 8),
          _NavItem(icon: Icons.person_outline, label: 'Profil & Paramètres', onTap: () => onGoToTab(3)),
          const Spacer(),
          TextButton.icon(onPressed: () {}, icon: const Icon(Icons.logout, color: AppColors.orange), label: const Text('Déconnexion', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({this.active = false, required this.icon, required this.label, required this.onTap});
  final bool active; final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, color: active ? AppColors.orange : Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: active ? AppColors.orange : Colors.white, fontWeight: active ? FontWeight.w700 : FontWeight.w400))),
          if (!active) const Icon(Icons.chevron_right, color: Colors.white, size: 18),
        ]),
      ),
    );
  }
}

class _CenterHeader extends StatelessWidget {
  const _CenterHeader({required this.businessName, required this.isOpen, required this.onRefresh});
  final String businessName; final bool isOpen; final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0,4))]),
      child: Row(children: [
        const Icon(Icons.menu, size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            businessName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)), child: Text(isOpen ? 'Ouvert' : 'Fermé', style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600))),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width >= 700)
          TextButton(onPressed: () {}, child: const Text('Voir tout', style: TextStyle(fontSize: 12, color: Colors.grey))),
        IconButton(onPressed: onRefresh, icon: const Icon(Icons.notifications_outlined), tooltip: 'Rafraîchir'),
        Container(width: 18, height: 18, alignment: Alignment.center, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10))),
      ]),
    );
  }
}

class _StatCards extends StatelessWidget {
  const _StatCards({required this.pending, required this.orders});
  final int pending, orders;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(title: 'Commandes du jour', value: '$orders', sub: '+15% vs hier', subColor: AppColors.green)),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(title: 'En attente d\'action', value: '$pending', sub: '! À traiter', subColor: Colors.red)),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(title: 'CA du jour', value: '125 500 FCFA', sub: '+8% vs hier', subColor: AppColors.green)),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(title: 'Note moyenne', value: '4,6/5', sub: '128 avis', subColor: Colors.grey)),
    ]);
  }
}

/// Actions rapides du tableau de bord : ajouter un produit, modifier la
/// boutique et ouvrir/fermer (interrupteur du panneau de droite).
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddProduct,
    required this.onToggleOpen,
    required this.isOpen,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onToggleOpen;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _QuickActionButton(
          icon: Icons.edit_outlined,
          label: 'Ajouter un produit',
          onPressed: onAddProduct,
        ),
        _QuickActionButton(
          icon: Icons.edit_outlined,
          label: 'Modifier la boutique',
          onPressed: () {},
        ),
        _QuickActionButton(
          icon: Icons.bolt,
          label: isOpen ? 'Ouvrir / Fermer' : 'Ouvrir / Fermer',
          filled: true,
          onPressed: onToggleOpen,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.orange : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: filled ? null : Border.all(color: const Color(0xFFD9DEDC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: filled ? Colors.white : AppColors.text),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.sub, required this.subColor});
  final String title,value,sub; final Color subColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(fontSize: 12, color: subColor)),
      ]),
    );
  }
}

class _NewOrdersList extends StatelessWidget {
  const _NewOrdersList({required this.orders});
  final List<Order> orders;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Nouvelles commandes', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: () {}, child: const Text('Voir tout', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
        const SizedBox(height: 8),
        if (orders.isEmpty) const Text('Aucune nouvelle commande.', style: TextStyle(color: Colors.grey)),
        ...orders.map((o) => _NewOrderRow(o)),
      ]),
    );
  }
}

class _NewOrderRow extends StatelessWidget {
  const _NewOrderRow(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) {
    // Wrap : une seule ligne quand la place le permet, sinon les métadonnées
    // passent sur plusieurs lignes (mobile) sans débordement.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(o.reference, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Text('Il y a 5 min', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('${o.total} FCFA', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${o.items.length} articles', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () {}, style: TextButton.styleFrom(backgroundColor: AppColors.greenLight, foregroundColor: AppColors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Accepter')),
              const SizedBox(width: 6),
              TextButton(onPressed: () {}, style: TextButton.styleFrom(backgroundColor: AppColors.redLight, foregroundColor: AppColors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Refuser')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersList extends StatelessWidget {
  const _RecentOrdersList({required this.orders});
  final List<Order> orders;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Commandes récentes', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: () {}, child: const Text('Voir tout', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
        const SizedBox(height: 8),
        ...orders.map((o) => _RecentRow(o)),
      ]),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow(this.o);
  final Order o;
  @override
  Widget build(BuildContext context) {
    final p = BadgePalette.order(o.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(o.reference, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (p != null) StatusBadge(label: p.$1, color: p.$2, small: true),
          Text('${o.total} FCFA', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ShopPanel extends StatelessWidget {
  const _ShopPanel({required this.businessName, required this.city, required this.statusStr, required this.isOpen, required this.onToggle});
  final String businessName, city; final String? statusStr; final bool isOpen; final ValueChanged<bool> onToggle;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('B. BOUTIQUE', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: Text('< Ma boutique', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600))),
          TextButton(onPressed: () {}, child: const Text('Modifier', style: TextStyle(color: AppColors.green, fontSize: 12))),
        ]),
        const SizedBox(height: 10),
        Container(height: 110, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.surfaceVariant), child: Stack(alignment: Alignment.center, children: [
          const Center(child: Text('LE DÉLICE FAST-FOOD', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8))),
        ])),
        const SizedBox(height: 12),
        Row(children: [
          Flexible(child: Text(businessName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6,vertical:2), decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)), child: Text(isOpen?'Ouvert':'Fermé', style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 4),
        Text('$city · Fast-food', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        const Row(children: [Icon(Icons.star, color: AppColors.gold, size: 16), Text(' 4,6 ', style: TextStyle(fontWeight: FontWeight.w700)), Text('(128 avis)', style: TextStyle(color: Colors.grey, fontSize: 12))]),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        _ShopTile(icon: Icons.description_outlined, label: 'Informations'),
        _ShopTile(icon: Icons.location_on_outlined, label: 'Adresse & zones desservies'),
        _ShopTile(icon: Icons.schedule_outlined, label: 'Horaires d\'ouverture'),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('Statut de la boutique'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [const Text('Ouvert', style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(width: 6), Switch(value: isOpen, onChanged: onToggle, activeTrackColor: AppColors.green)]),
        ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined),
          title: const Text('Statut du compte'),
          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8,vertical:4), decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)), child: const Text('Actif', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600))),
        ),
      ]),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) {
    return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(icon), title: Text(label), trailing: const Icon(Icons.chevron_right));
  }
}
