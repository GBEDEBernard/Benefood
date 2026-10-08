import 'geo_point.dart';

class OrderVendor {
  const OrderVendor({required this.id, required this.businessName, this.logoUrl});

  final String id;
  final String businessName;
  final String? logoUrl;

  factory OrderVendor.fromJson(Map<String, dynamic> json) => OrderVendor(
        id: _s(json['id']),
        businessName: _s(json['business_name']),
        logoUrl: json['logo_url'] is String ? json['logo_url'] as String : null,
      );
}

class OrderPayment {
  const OrderPayment({
    required this.id,
    required this.reference,
    this.gateway,
    required this.amount,
    required this.status,
    this.currency = 'XOF',
  });

  final String id;
  final String reference;
  final String? gateway;
  final int amount;
  final String status;
  final String currency;

  bool get isPaid => status == 'confirmed' || status == 'paid';

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        id: _s(json['id']),
        reference: _s(json['reference']),
        gateway: json['gateway'] is String ? json['gateway'] as String : null,
        amount: _i(json['amount']),
        status: _s(json['status']),
        currency: _s(json['currency'], 'XOF'),
      );
}

class OrderFinancials {
  const OrderFinancials({
    this.commissionRate,
    this.commissionAmount,
    this.vendorAmount,
    this.platformAmount,
    this.deliveryPartnerAmount,
    this.totalClient,
  });

  final int? commissionRate;
  final int? commissionAmount;
  final int? vendorAmount;
  final int? platformAmount;
  final int? deliveryPartnerAmount;
  final int? totalClient;

  factory OrderFinancials.fromJson(Map<String, dynamic> json) => OrderFinancials(
        commissionRate: _iNull(json['commission_rate']),
        commissionAmount: _iNull(json['commission_amount']),
        vendorAmount: _iNull(json['vendor_amount']),
        platformAmount: _iNull(json['platform_amount']),
        deliveryPartnerAmount: _iNull(json['delivery_partner_amount']),
        totalClient: _iNull(json['total_client']),
      );
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.currency = 'XOF',
    this.imageUrl,
  });

  final String id;
  final String productId;
  final String name;
  final int quantity;
  final int unitPrice;
  final int subtotal;
  final String currency;

  /// Photo du produit (pour le récapitulatif visuel du colis).
  final String? imageUrl;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: _s(json['id']),
        productId: _s(json['product_id']),
        name: _s(json['name']),
        quantity: _i(json['quantity']),
        unitPrice: _i(json['unit_price']),
        subtotal: _i(json['subtotal']),
        currency: _s(json['currency'], 'XOF'),
        imageUrl: json['image_url'] is String ? json['image_url'] as String : null,
      );
}

class OrderStatusHistory {
  const OrderStatusHistory({
    this.fromStatus,
    required this.toStatus,
    this.actorType,
    this.reason,
    this.createdAt,
  });

  final String? fromStatus;
  final String toStatus;
  final String? actorType;
  final String? reason;
  final String? createdAt;

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) => OrderStatusHistory(
        fromStatus: json['from_status'] is String ? json['from_status'] as String : null,
        toStatus: _s(json['to_status']),
        actorType: json['actor_type'] is String ? json['actor_type'] as String : null,
        reason: json['reason'] is String ? json['reason'] as String : null,
        createdAt: json['created_at'] is String ? json['created_at'] as String : null,
      );
}

class OrderRefund {
  const OrderRefund({
    required this.id,
    required this.amount,
    this.reason,
    required this.status,
    this.createdAt,
  });

  final String id;
  final int amount;
  final String? reason;
  final String status;
  final String? createdAt;

  factory OrderRefund.fromJson(Map<String, dynamic> json) => OrderRefund(
        id: _s(json['id']),
        amount: _i(json['amount']),
        reason: json['reason'] is String ? json['reason'] as String : null,
        status: _s(json['status']),
        createdAt: json['created_at'] is String ? json['created_at'] as String : null,
      );
}

class OrderDriver {
  const OrderDriver({required this.id, this.name, this.vehicle, this.rating, this.phone});

  final String id;
  final String? name;
  final String? vehicle;
  final double? rating;

  /// Téléphone du livreur : visible par le client dès qu'il est assigné à la
  /// commande (bouton « Appeler » du suivi).
  final String? phone;

  factory OrderDriver.fromJson(Map<String, dynamic> json) => OrderDriver(
        id: _s(json['id']),
        name: json['name'] is String ? json['name'] as String : null,
        vehicle: json['vehicle'] is String ? json['vehicle'] as String : null,
        rating: _dNull(json['rating']),
        phone: json['phone'] is String ? json['phone'] as String : null,
      );
}

class OrderDeliveryPosition {
  const OrderDeliveryPosition({
    required this.latitude,
    required this.longitude,
    this.lastLocationAt,
    this.distanceKm,
    this.heading,
  });

  final double latitude;
  final double longitude;
  final String? lastLocationAt;
  final double? distanceKm;

  /// Cap du véhicule en degrés (0 = Nord) si l'API le fournit.
  final double? heading;

  GeoPoint get point => GeoPoint(latitude, longitude);

  factory OrderDeliveryPosition.fromJson(Map<String, dynamic> json) => OrderDeliveryPosition(
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        lastLocationAt: json['last_location_at'] is String ? json['last_location_at'] as String : null,
        distanceKm: _dNull(json['distance_km']),
        heading: _dNull(json['heading']),
      );
}

class OrderDelivery {
  const OrderDelivery({
    required this.id,
    required this.status,
    this.driver,
    this.position,
  });

  final String id;
  final String status;
  final OrderDriver? driver;
  final OrderDeliveryPosition? position;

  bool get hasActiveDriver => driver != null;

  bool get isTracking => position != null;

  factory OrderDelivery.fromJson(Map<String, dynamic> json) {
    final rawDriver = json['driver'];
    final rawPosition = json['position'];
    return OrderDelivery(
      id: _s(json['id']),
      status: _s(json['status']),
      driver: rawDriver is Map<String, dynamic> ? OrderDriver.fromJson(rawDriver) : null,
      position: rawPosition is Map<String, dynamic> ? OrderDeliveryPosition.fromJson(rawPosition) : null,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.reference,
    required this.status,
    required this.paymentStatus,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.vendor,
    this.payment,
    this.financials,
    this.deliveryAddress,
    this.deliveryAddressSnapshot,
    this.delivery,
    this.statusHistory = const [],
    this.refunds = const [],
    this.currency = 'XOF',
    this.discount = 0,
    this.paymentDeadlineAt,
    this.vendorAcceptanceDeadlineAt,
    this.acceptedAt,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerPhone,
    this.notes,
  });

  final String id;
  final String reference;
  final String status;
  final String paymentStatus;
  final List<OrderItem> items;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final OrderVendor? vendor;
  final OrderPayment? payment;
  final OrderFinancials? financials;
  final String? deliveryAddress;

  /// Adresse de livraison complète (coordonnées + libellé) pour la carte de
  /// suivi : l'API renvoie l'objet `address_snapshot`, pas une chaîne.
  final AddressSnapshot? deliveryAddressSnapshot;

  final OrderDelivery? delivery;
  final List<OrderStatusHistory> statusHistory;
  final List<OrderRefund> refunds;
  final String currency;
  final int discount;
  final String? paymentDeadlineAt;
  final String? vendorAcceptanceDeadlineAt;
  final String? acceptedAt;
  final String? cancellationReason;
  final String? cancelledBy;
  final String? cancelledAt;
  final String? createdAt;
  final String? updatedAt;

  /// Client de la commande (fiche détail vendeur) : exposé par l'API quand
  /// le serveur renvoie l'objet `customer`.
  final String? customerName;
  final String? customerPhone;

  /// Note de livraison laissée par le client (« Bien cuire les frites… »).
  final String? notes;

  bool get isAwaitingPayment => status == 'awaiting_payment';
  bool get isPaid => status == 'paid';
  bool get isCancelled => status == 'cancelled';
  bool get isDelivered => status == 'delivered';
  bool get isRefunded => status == 'refunded';

  /// Point GPS de la destination (suivi client).
  GeoPoint? get dropoffPoint => deliveryAddressSnapshot?.point;

  bool get canCancel =>
      status == 'awaiting_payment' || status == 'paid' || status == 'accepted' || status == 'preparing';

  bool get canVendorAccept => status == 'awaiting_payment' || status == 'paid';
  bool get canVendorPrepare => status == 'accepted';
  bool get canVendorReady => status == 'preparing';
  bool get canVendorRefuse => status == 'awaiting_payment' || status == 'paid';

  /// Copie de la commande avec un nouveau statut : utilisé par les actions
  /// du vendeur pour mettre à jour l'état local (mode démo et mise à jour
  /// optimiste) sans reconstruire toute la liste.
  Order withStatus(String status) => Order(
        id: id,
        reference: reference,
        status: status,
        paymentStatus: paymentStatus,
        items: items,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        vendor: vendor,
        payment: payment,
        financials: financials,
        deliveryAddress: deliveryAddress,
        deliveryAddressSnapshot: deliveryAddressSnapshot,
        delivery: delivery,
        statusHistory: statusHistory,
        refunds: refunds,
        currency: currency,
        discount: discount,
        paymentDeadlineAt: paymentDeadlineAt,
        vendorAcceptanceDeadlineAt: vendorAcceptanceDeadlineAt,
        acceptedAt: acceptedAt,
        cancellationReason: cancellationReason,
        cancelledBy: cancelledBy,
        cancelledAt: cancelledAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        customerName: customerName,
        customerPhone: customerPhone,
        notes: notes,
      );

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<OrderItem> items = [];
    if (rawItems is List) {
      items = rawItems.whereType<Map<String, dynamic>>().map(OrderItem.fromJson).toList();
    }

    final rawVendor = json['vendor'];
    OrderVendor? vendor;
    if (rawVendor is Map<String, dynamic>) {
      vendor = OrderVendor.fromJson(rawVendor);
    }

    final rawPayment = json['payment'];
    OrderPayment? payment;
    if (rawPayment is Map<String, dynamic>) {
      payment = OrderPayment.fromJson(rawPayment);
    }

    final rawFinancials = json['financials'];
    OrderFinancials? financials;
    if (rawFinancials is Map<String, dynamic>) {
      financials = OrderFinancials.fromJson(rawFinancials);
    }

    final rawDelivery = json['delivery'];
    OrderDelivery? delivery;
    if (rawDelivery is Map<String, dynamic>) {
      delivery = OrderDelivery.fromJson(rawDelivery);
    }

    final rawHistory = json['status_history'];
    List<OrderStatusHistory> history = [];
    if (rawHistory is List) {
      history = rawHistory.whereType<Map<String, dynamic>>().map(OrderStatusHistory.fromJson).toList();
    }

    final rawRefunds = json['refunds'];
    List<OrderRefund> refunds = [];
    if (rawRefunds is List) {
      refunds = rawRefunds.whereType<Map<String, dynamic>>().map(OrderRefund.fromJson).toList();
    }

    return Order(
      id: _s(json['id']),
      reference: _s(json['reference']),
      status: _s(json['status']),
      paymentStatus: _s(json['payment_status']),
      items: items,
      subtotal: _i(json['subtotal']),
      deliveryFee: _i(json['delivery_fee']),
      total: _i(json['total']),
      vendor: vendor,
      payment: payment,
      financials: financials,
      deliveryAddress: _deliveryAddressLabel(json['delivery_address']),
      deliveryAddressSnapshot: json['delivery_address'] == null
          ? null
          : AddressSnapshot.fromJson(json['delivery_address']),
      delivery: delivery,
      statusHistory: history,
      refunds: refunds,
      currency: _s(json['currency'], 'XOF'),
      discount: _i(json['discount']),
      paymentDeadlineAt: _nullable(json['payment_deadline_at']),
      vendorAcceptanceDeadlineAt: _nullable(json['vendor_acceptance_deadline_at']),
      acceptedAt: _nullable(json['accepted_at']),
      cancellationReason: json['cancellation_reason'] is String ? json['cancellation_reason'] as String : null,
      cancelledBy: json['cancelled_by'] is String ? json['cancelled_by'] as String : null,
      cancelledAt: _nullable(json['cancelled_at']),
      createdAt: _nullable(json['created_at']),
      updatedAt: _nullable(json['updated_at']),
      customerName: _customerField(json['customer'], 'name') ?? _stringOrNull(json['customer_name']),
      customerPhone: _customerField(json['customer'], 'phone') ?? _stringOrNull(json['customer_phone']),
      notes: _stringOrNull(json['notes']),
    );
  }
}

/// Champ d'un objet client `{"name": …, "phone": …}` renvoyé par l'API.
String? _customerField(dynamic customer, String key) {
  if (customer is Map<String, dynamic> && customer[key] is String) {
    final value = (customer[key] as String).trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

String? _stringOrNull(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;

/// Libellé de l'adresse de livraison, compatible objet `address_snapshot` et
/// ancienne chaîne.
String? _deliveryAddressLabel(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  final snapshot = AddressSnapshot.fromJson(value);
  return snapshot.display.isEmpty ? null : snapshot.display;
}

String? _nullable(dynamic value) => value is String ? value : null;

int _i(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

int? _iNull(dynamic value) {
  if (value == null) {
    return null;
  }
  return _i(value);
}

double _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return _dNull(value) ?? 0;
}

double? _dNull(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}