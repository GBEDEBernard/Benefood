import 'product.dart';

/// Promotion active d'un produit, telle que renvoyée par l'API vendeur/client.
class ProductPromotion {
  const ProductPromotion({
    required this.id,
    this.productId = '',
    this.vendorId = '',
    this.title,
    required this.promoPrice,
    this.originalPrice = 0,
    this.discountPercent = 0,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.isCurrentlyActive = true,
    this.product,
  });

  final String id;
  final String productId;
  final String vendorId;
  final String? title;
  final int promoPrice;
  final int originalPrice;
  final int discountPercent;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final bool isCurrentlyActive;
  final Product? product;

  bool get hasProduct => product != null;

  String? get productName => product?.name;

  String? get imageUrl => product?.displayImageUrl;

  /// Pourcentage affiché, recalculé si l'API ne le fournit pas.
  int get displayedDiscountPercent {
    if (discountPercent > 0) {
      return discountPercent;
    }
    if (originalPrice > 0 && promoPrice > 0 && promoPrice < originalPrice) {
      return ((originalPrice - promoPrice) / originalPrice * 100).round();
    }
    return 0;
  }

  int get savings => originalPrice > promoPrice ? originalPrice - promoPrice : 0;

  factory ProductPromotion.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'];
    final product = rawProduct is Map<String, dynamic>
        ? Product.fromJson(rawProduct)
        : null;
    final originalPrice = _intOr(
      json['original_price'],
      product?.price ?? _intOr(json['price'], 0),
    );
    final promoPrice = _intOr(
      json['promo_price'],
      _intOr(json['effective_price'], originalPrice),
    );
    final computedPercent = originalPrice > 0 && promoPrice < originalPrice
        ? ((originalPrice - promoPrice) / originalPrice * 100).round()
        : 0;

    return ProductPromotion(
      id: _string(json['id']),
      productId: _string(json['product_id'], product?.id ?? ''),
      vendorId: _string(json['vendor_id']),
      title: json['title'] is String ? json['title'] as String : null,
      promoPrice: promoPrice,
      originalPrice: originalPrice,
      discountPercent: _intOr(json['discount_percent'], computedPercent),
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      isActive: json['is_active'] != false,
      isCurrentlyActive: json['is_currently_active'] != false,
      product: product,
    );
  }

  ProductPromotion copyWith({
    String? title,
    int? promoPrice,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? isActive,
  }) {
    return ProductPromotion(
      id: id,
      productId: productId,
      vendorId: vendorId,
      title: title ?? this.title,
      promoPrice: promoPrice ?? this.promoPrice,
      originalPrice: originalPrice,
      discountPercent: discountPercent,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
      isCurrentlyActive: isCurrentlyActive,
      product: product,
    );
  }
}

String _string(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

int _intOr(dynamic value, int fallback) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

DateTime? _date(dynamic value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}
