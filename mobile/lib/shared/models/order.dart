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
  });

  final String id;
  final String productId;
  final String name;
  final int quantity;
  final int unitPrice;
  final int subtotal;
  final String currency;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: _s(json['id']),
        productId: _s(json['product_id']),
        name: _s(json['name']),
        quantity: _i(json['quantity']),
        unitPrice: _i(json['unit_price']),
        subtotal: _i(json['subtotal']),
        currency: _s(json['currency'], 'XOF'),
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

  bool get isAwaitingPayment => status == 'awaiting_payment';
  bool get isPaid => status == 'paid';
  bool get isCancelled => status == 'cancelled';
  bool get isDelivered => status == 'delivered';
  bool get isRefunded => status == 'refunded';

  bool get canCancel =>
      status == 'awaiting_payment' || status == 'paid' || status == 'accepted' || status == 'preparing';

  bool get canVendorAccept => status == 'awaiting_payment' || status == 'paid';
  bool get canVendorPrepare => status == 'accepted';
  bool get canVendorReady => status == 'preparing';
  bool get canVendorRefuse => status == 'awaiting_payment' || status == 'paid';

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
      deliveryAddress: json['delivery_address'] is String ? json['delivery_address'] as String : null,
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
    );
  }
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;

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