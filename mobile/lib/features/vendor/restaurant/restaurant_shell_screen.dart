import 'package:flutter/material.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/data/marketplace_api.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/vendor.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../account/vendor_account_screen.dart';
import '../products/products_screen.dart';
import 'restaurant_palette.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/revenues_screen.dart';
import 'screens/shop_screen.dart';
import 'widgets/restaurant_drawer.dart';
import 'widgets/vendor_bottom_bar.dart';

/// Écran racine vendeur « Le Délice Fast-Food » (mobile).
///
/// Scaffold avec menu latéral [RestaurantDrawer] (s'ouvre via le bouton
/// hamburger) et affichage UNIQUEMENT de l'écran sélectionné. Les données
/// (statut de la boutique, commandes, revenus) sont chargées depuis l'API
/// quand [marketplace] est fourni ; sinon un jeu de démonstration est utilisé.
class RestaurantShellScreen extends StatefulWidget {
  const RestaurantShellScreen({super.key, this.session, this.marketplace});

  final SessionProvider? session;
  final MarketplaceApi? marketplace;

  @override
  State<RestaurantShellScreen> createState() => _RestaurantShellScreenState();
}

class _RestaurantShellScreenState extends State<RestaurantShellScreen> {
  static const List<String> _titles = [
    'Tableau de bord',
    'Boutique',
    'Produits',
    'Commandes',
    'Revenus',
    'Profil & Paramètres',
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isOpen = true;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _status;
  List<Order> _orders = [];
  final Set<String> _busyOrders = {};

  bool get _live => widget.marketplace != null;

  @override
  void initState() {
    super.initState();
    if (_live) {
      _load();
    } else {
      _applyDemoStatus();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _loadStatusAndOrders();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadStatusAndOrders() async {
    final api = widget.marketplace!;
    final status = await api.vendorStatus();
    final orders = await api.vendorOrders(perPage: 50);
    if (!mounted) return;
    final rawVendor = status['vendor'];
    final vendor = rawVendor is Map<String, dynamic> ? rawVendor : null;
    final rawOpen = vendor == null ? null : vendor['is_open'];
    final open = rawOpen is bool ? rawOpen : true;
    setState(() {
      _status = status;
      _orders = orders;
      _isOpen = open;
      _loading = false;
    });
  }

  void _applyDemoStatus() {
    _status = {
      'vendor': {
        'business_name': 'Le Délice Fast-Food',
        'city': 'Cadjèhoun, Cotonou',
        'status': 'active',
        'is_open': true,
      },
    };
    _orders = _demoOrders();
    _isOpen = true;
    _loading = false;
  }

  static List<Order> _demoOrders() {
    final now = DateTime.now();

    Order demo(
      String ref,
      String status,
      int subtotal,
      int minutesAgo, {
      int deliveryFee = 500,
      int lines = 3,
      String customer = 'Client démo',
      String phone = '+229 90 12 34 56',
      String address = 'Cadjèhoun, Cotonou',
      String? notes,
      List<OrderItem>? items,
    }) {
      final lineItems = items ??
          List.generate(lines, (i) {
            final unit = subtotal ~/ lines;
            final amount = i == lines - 1 ? subtotal - unit * (lines - 1) : unit;
            return OrderItem(
              id: '$ref-item-$i',
              productId: 'p-$i',
              name: 'Plat n°${i + 1}',
              quantity: 1,
              unitPrice: amount,
              subtotal: amount,
            );
          });
      return Order(
        id: ref,
        reference: ref,
        status: status,
        paymentStatus: status == 'awaiting_payment' ? 'pending' : 'confirmed',
        items: lineItems,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: subtotal + deliveryFee,
        customerName: customer,
        customerPhone: phone,
        deliveryAddress: address,
        notes: notes,
        createdAt: now.subtract(Duration(minutes: minutesAgo)).toIso8601String(),
      );
    }

    return [
      demo(
        '#BF1256',
        'paid',
        13500,
        5,
        customer: 'Ulrich Hounkpe',
        phone: '+229 97 00 00 00',
        notes: 'Bien cuire les frites, pas de sauce piquante.',
        items: const [
          OrderItem(
            id: 'bf1256-0',
            productId: 'p-burger',
            name: 'Burger Délice',
            quantity: 3,
            unitPrice: 4000,
            subtotal: 12000,
          ),
          OrderItem(
            id: 'bf1256-1',
            productId: 'p-frites',
            name: 'Frites (M)',
            quantity: 1,
            unitPrice: 1500,
            subtotal: 1500,
          ),
        ],
      ),
      demo('#BF1255', 'paid', 8000, 12, lines: 2, customer: 'Aïcha Sossou'),
      demo('#BF1254', 'awaiting_payment', 14700, 18, lines: 4, customer: 'Koffi Adjovi'),
      demo('#BF1253', 'accepted', 9300, 32, lines: 3, customer: 'Mariam Touré'),
      demo('#BF1252', 'preparing', 11000, 40, lines: 3, customer: 'Serge Dossou'),
      demo('#BF1251', 'ready', 14000, 48, lines: 4, customer: 'Nadia Kpadonou'),
      demo('#BF1250', 'delivered', 5700, 65, lines: 2, customer: 'Yao Amoussou'),
      demo('#BF1249', 'cancelled', 20500, 130, lines: 5, customer: 'Estelle Hounkpatin'),
    ];
  }

  String get _businessName {
    if (_live) {
      final v = _status?['vendor'];
      if (v is Map<String, dynamic>) {
        final name = v['business_name'];
        if (name is String && name.trim().isNotEmpty) return name;
      }
    }
    return 'Le Délice Fast-Food';
  }

  String get _accountStatusLabel {
    if (_live) {
      final v = _status?['vendor'];
      if (v is Map<String, dynamic> && v['status'] is String) {
        final s = v['status'] as String;
        if (s == 'active') return 'Actif';
        if (s == 'suspended') return 'Suspendu';
        if (s == 'closed') return 'Fermé';
        return 'En vérification';
      }
    }
    return 'Actif';
  }

  /// Profil complet de la boutique (domaine vendeur) pour l'écran Boutique.
  Vendor get _shopVendor {
    if (_live) {
      final v = _status?['vendor'];
      if (v is Map<String, dynamic> && v['id'] is String) {
        return Vendor.fromJson(v);
      }
    }
    return const Vendor(
      id: '',
      businessName: 'Le Délice Fast-Food',
      status: 'active',
      description: 'Fast-food et cuisine locale livrée à domicile.',
      phone: '+229 01 02 03 04 05',
      city: 'Cadjèhoun, Cotonou',
      address: 'Carrefour des 3 collèges',
    );
  }

  List<OpeningHour> get _shopHours {
    if (_live) {
      final v = _status?['vendor'];
      if (v is Map<String, dynamic>) {
        final raw = v['hours'];
        if (raw is List) {
          final list = raw.whereType<Map<String, dynamic>>().map(OpeningHour.fromJson).toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    }
    return _demoHours();
  }

  static List<OpeningHour> _demoHours() {
    return List.generate(7, (day) {
      const closed = [5, 6];
      final isClosed = closed.contains(day);
      return OpeningHour(
        dayOfWeek: day,
        opensAt: isClosed ? null : '08:00',
        closesAt: isClosed ? null : '22:00',
        isClosed: isClosed,
      );
    });
  }

  /// Recharge statut + commandes sans repasser par l'écran de chargement.
  Future<void> _reloadData() async {
    if (!_live) {
      return;
    }
    try {
      await _loadStatusAndOrders();
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.message, isError: true);
      }
    }
  }

  List<Order> get _newOrders {
    if (!_live) {
      return _orders
          .where((o) => o.status == 'awaiting_payment' || o.status == 'paid' || o.status == 'accepted')
          .take(3)
          .toList();
    }
    final list = [..._orders];
    list.sort((a, b) => _compareDates(a.createdAt, b.createdAt));
    return list
        .where((o) => o.status == 'awaiting_payment' || o.status == 'paid' || o.status == 'accepted')
        .take(3)
        .toList();
  }

  List<Order> get _recentOrders {
    final newIds = _newOrders.map((o) => o.id).toSet();
    final list = [..._orders];
    list.sort((a, b) => _compareDates(a.createdAt, b.createdAt));
    return list.where((o) => !newIds.contains(o.id)).take(4).toList();
  }

  static int _compareDates(String? a, String? b) {
    final da = DateTime.tryParse(a ?? '');
    final db = DateTime.tryParse(b ?? '');
    if (da == null || db == null) return 0;
    return db.compareTo(da);
  }

  int get _pendingCount =>
      _orders.where((o) => o.status == 'awaiting_payment' || o.status == 'paid' || o.status == 'accepted').length;

  int get _revenueToday {
    final today = DateTime.now();
    var sum = 0;
    for (final o in _orders) {
      final created = DateTime.tryParse(o.createdAt ?? '')?.toLocal();
      if (created != null &&
          created.year == today.year &&
          created.month == today.month &&
          created.day == today.day &&
          o.status != 'cancelled') {
        sum += o.total;
      }
    }
    return sum;
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _select(int index) {
    setState(() => _selectedIndex = index);
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _toggleOpen(bool open) async {
    final previous = _isOpen;
    setState(() => _isOpen = open);
    if (!_live) {
      if (mounted) showToast(context, open ? 'Boutique ouverte.' : 'Boutique fermée.');
      return;
    }
    try {
      await widget.marketplace!.setVendorOpen(open: open);
      if (!mounted) return;
      showToast(context, open ? 'Boutique ouverte.' : 'Boutique fermée.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isOpen = previous);
      showToast(context, e.message, isError: true);
    }
  }

  /// Exécute une action de statut sur une commande et renvoie `true` si elle
  /// a bien été effectuée : les écrans (liste, détail) s'en servent pour
  /// mettre à jour leur état local.
  Future<bool> _runOrderAction(
    Order order,
    String nextStatus, {
    required Future<void> Function(Order order) call,
    required String doneMessage,
  }) async {
    if (_busyOrders.contains(order.id)) return false;
    if (!_live) {
      if (!mounted) return false;
      setState(() {
        _orders = [for (final o in _orders) o.id == order.id ? o.withStatus(nextStatus) : o];
      });
      showToast(context, doneMessage);
      return true;
    }
    setState(() => _busyOrders.add(order.id));
    try {
      await call(order);
      if (!mounted) return false;
      showToast(context, doneMessage);
      await _loadOrders();
      return true;
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _busyOrders.remove(order.id));
    }
  }

  Future<bool> _accept(Order order) => _runOrderAction(
        order,
        'accepted',
        call: (o) => widget.marketplace!.vendorAccept(o.id),
        doneMessage: '${order.reference} acceptée.',
      );

  Future<bool> _refuse(Order order) => _runOrderAction(
        order,
        'cancelled',
        call: (o) => widget.marketplace!.vendorRefuse(o.id, reason: 'Refusé par le vendeur'),
        doneMessage: '${order.reference} refusée.',
      );

  Future<bool> _prepare(Order order) => _runOrderAction(
        order,
        'preparing',
        call: (o) => widget.marketplace!.vendorPreparing(o.id),
        doneMessage: '${order.reference} : préparation démarrée.',
      );

  Future<bool> _ready(Order order) => _runOrderAction(
        order,
        'ready',
        call: (o) => widget.marketplace!.vendorReady(o.id),
        doneMessage: '${order.reference} prête à être livrée.',
      );

  /// Confirmation « Livrée » : proposée en démonstration uniquement — en
  /// production la livraison est confirmée par le livreur.
  Future<bool> _confirmDelivered(Order order) async {
    if (_live || !mounted) return false;
    setState(() {
      _orders = [for (final o in _orders) o.id == order.id ? o.withStatus('delivered') : o];
    });
    showToast(context, '${order.reference} livrée.');
    return true;
  }

  Future<void> _loadOrders() async {
    final orders = await widget.marketplace!.vendorOrders(perPage: 50);
    if (mounted) setState(() => _orders = orders);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: RestaurantPalette.background,
      drawer: RestaurantDrawer(
        currentIndex: _selectedIndex,
        isOpen: _isOpen,
        businessName: _businessName,
        logoUrl: _shopVendor.logoUrl,
        onSelect: _select,
      ),
      body: _buildBody(),
      bottomNavigationBar: VendorBottomBar(
        currentIndex: _selectedIndex,
        onSelect: _select,
        pendingOrders: _pendingCount,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_outlined, size: 48, color: RestaurantPalette.danger),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: RestaurantPalette.grayText)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          isOpen: _isOpen,
          onOpenDrawer: _openDrawer,
          onToggleOpen: _toggleOpen,
          orderCount: _orders.length,
          pendingCount: _pendingCount,
          revenueToday: _revenueToday,
          newOrders: _newOrders,
          recentOrders: _recentOrders,
          onAccept: _accept,
          onRefuse: _refuse,
          onAddProduct: () => _select(2),
          onGoToShop: () => _select(1),
        );
      case 1:
        return ShopScreen(
          onBack: () => _select(0),
          isOpen: _isOpen,
          onToggleOpen: _toggleOpen,
          vendor: _shopVendor,
          hours: _shopHours,
          statusLabel: _accountStatusLabel,
          marketplace: widget.marketplace,
          onDataChanged: _reloadData,
        );
      case 2:
        return widget.marketplace != null
            ? ProductsScreen(marketplace: widget.marketplace!, onBack: () => _select(0))
            : _PlaceholderScreen(
                title: _titles[2],
                onOpenDrawer: _openDrawer,
                onBack: () => _select(0),
              );
      case 3:
        return OrdersScreen(
          orders: _orders,
          onAccept: _accept,
          onRefuse: _refuse,
          onPrepare: _prepare,
          onReady: _ready,
          onConfirmDelivery: _live ? null : _confirmDelivered,
          busyOrderIds: _busyOrders,
          onOpenDrawer: _openDrawer,
          onRefresh: _reloadData,
        );
      case 4:
        return RevenusScreen(
          orders: _orders,
          onOpenDrawer: _openDrawer,
          onMonthTap: () =>
              showToast(context, 'Sélection du mois bientôt disponible.'),
          onSeeAllTap: () =>
              showToast(context, 'Historique complet bientôt disponible.'),
          onRefresh: _reloadData,
        );
      case 5:
        if (widget.marketplace != null && widget.session != null) {
          return VendorAccountScreen(
            session: widget.session!,
            marketplace: widget.marketplace!,
            onSelectTab: (index) => _select(_mapAccountTab(index)),
          );
        }
        return _PlaceholderScreen(
          title: _titles[5],
          onOpenDrawer: _openDrawer,
          onBack: () => _select(0),
        );
      default:
        return _PlaceholderScreen(
          title: _titles[_selectedIndex],
          onOpenDrawer: _openDrawer,
          onBack: () => _select(0),
        );
    }
  }

  /// Correspondance onglets du compte vendeur -> index du menu latéral.
  static int _mapAccountTab(int index) => switch (index) {
        1 => 2,
        2 => 3,
        _ => 0,
      };
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.onOpenDrawer, required this.onBack});

  final String title;
  final VoidCallback onOpenDrawer;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RestaurantPalette.background,
      child: SafeArea(
        child: Column(
          children: [
            Material(
              color: RestaurantPalette.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onOpenDrawer,
                      icon: const Icon(Icons.menu, color: RestaurantPalette.darkText),
                      tooltip: 'Ouvrir le menu',
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: RestaurantPalette.darkText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.construction_outlined,
                      size: 56,
                      color: RestaurantPalette.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$title — bientôt disponible',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: RestaurantPalette.grayText,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour au tableau de bord'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RestaurantPalette.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}