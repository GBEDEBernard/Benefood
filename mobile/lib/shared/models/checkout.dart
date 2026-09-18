/// Récapitulatif de commande renvoyé par `GET /orders/summary` (J83).
class OrderSummary {
  const OrderSummary({
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.vendorId,
    this.vendorName,
    this.commissionRate,
    this.commissionAmount,
    this.deliveryZoneName,
    this.currency = 'XOF',
  });

  final List<SummaryItem> items;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final String? vendorId;
  final String? vendorName;
  final int? commissionRate;
  final int? commissionAmount;
  final String? deliveryZoneName;
  final String currency;

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<SummaryItem> items = [];
    if (rawItems is List) {
      items = rawItems.whereType<Map<String, dynamic>>().map(SummaryItem.fromJson).toList();
    }

    final rawVendor = json['vendor'];
    String? vendorId;
    String? vendorName;
    if (rawVendor is Map<String, dynamic>) {
      vendorId = rawVendor['id'] is String ? rawVendor['id'] as String : null;
      vendorName = rawVendor['business_name'] is String ? rawVendor['business_name'] as String : null;
    }

    final rawCommission = json['commission'];
    int? rate;
    int? amount;
    if (rawCommission is Map<String, dynamic>) {
      rate = rawCommission['rate'] is int ? rawCommission['rate'] as int : null;
      amount = rawCommission['amount'] is int ? rawCommission['amount'] as int : null;
    }

    final rawZone = json['delivery_zone'];
    String? zoneName;
    if (rawZone is Map<String, dynamic>) {
      zoneName = rawZone['name'] is String ? rawZone['name'] as String : null;
    }

    return OrderSummary(
      items: items,
      subtotal: _i(json['subtotal']),
      deliveryFee: _i(json['delivery_fee']),
      total: _i(json['total']),
      vendorId: vendorId,
      vendorName: vendorName,
      commissionRate: rate,
      commissionAmount: amount,
      deliveryZoneName: zoneName,
      currency: _s(json['currency'], 'XOF'),
    );
  }
}

class SummaryItem {
  const SummaryItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final String productId;
  final String name;
  final int quantity;
  final int unitPrice;
  final int subtotal;

  factory SummaryItem.fromJson(Map<String, dynamic> json) => SummaryItem(
        productId: _s(json['product_id']),
        name: _s(json['name']),
        quantity: _i(json['quantity']),
        unitPrice: _i(json['unit_price']),
        subtotal: _i(json['subtotal']),
      );
}

/// Devis de livraison renvoyé par `POST /delivery/quote` (J73/J176).
class DeliveryQuote {
  const DeliveryQuote({
    required this.deliveryFee,
    this.zoneId,
    this.zoneName,
    this.matchedBy,
    this.distanceKm,
    this.currency = 'XOF',
  });

  final int deliveryFee;
  final String? zoneId;
  final String? zoneName;
  final String? matchedBy;
  final double? distanceKm;
  final String currency;

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    final rawZone = json['zone'];
    return DeliveryQuote(
      deliveryFee: _i(json['delivery_fee']),
      zoneId: rawZone is Map<String, dynamic> && rawZone['id'] is String ? rawZone['id'] as String : null,
      zoneName: rawZone is Map<String, dynamic> && rawZone['name'] is String ? rawZone['name'] as String : null,
      matchedBy: json['matched_by'] is String ? json['matched_by'] as String : null,
      distanceKm: json['distance_km'] is num ? (json['distance_km'] as num).toDouble() : null,
      currency: _s(json['currency'], 'XOF'),
    );
  }
}

class PaginationMeta {
  const PaginationMeta({
    this.total = 0,
    this.perPage = 15,
    this.currentPage = 1,
    this.lastPage = 1,
  });

  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  factory PaginationMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PaginationMeta();
    }
    return PaginationMeta(
      total: _i(json['total']),
      perPage: _i(json['per_page'], 15),
      currentPage: _i(json['current_page'], 1),
      lastPage: _i(json['last_page'], 1),
    );
  }
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;

int _i(dynamic value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}