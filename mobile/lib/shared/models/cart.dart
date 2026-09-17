class CartItemProduct {
  const CartItemProduct({
    required this.id,
    this.name,
    this.unit,
    required this.unitPrice,
    this.imageUrl,
  });

  final String id;
  final String? name;
  final String? unit;
  final int unitPrice;
  final String? imageUrl;

  factory CartItemProduct.fromJson(Map<String, dynamic> json) => CartItemProduct(
        id: _s(json['id']),
        name: json['name'] is String ? json['name'] as String : null,
        unit: json['unit'] is String ? json['unit'] as String : null,
        unitPrice: _i(json['unit_price']),
        imageUrl: json['image_url'] is String ? json['image_url'] as String : null,
      );
}

class CartItem {
  const CartItem({required this.id, required this.product, required this.quantity, required this.subtotal});

  final String id;
  final CartItemProduct product;
  final int quantity;
  final int subtotal;

  String? get productId => product.id;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'];
    return CartItem(
      id: _s(json['id']),
      product: rawProduct is Map<String, dynamic> ? CartItemProduct.fromJson(rawProduct) : CartItemProduct(id: '', unitPrice: 0),
      quantity: _i(json['quantity']),
      subtotal: _i(json['subtotal']),
    );
  }
}

class CartVendor {
  const CartVendor({required this.id, required this.businessName, this.logoUrl});

  final String id;
  final String businessName;
  final String? logoUrl;

  factory CartVendor.fromJson(Map<String, dynamic> json) => CartVendor(
        id: _s(json['id']),
        businessName: _s(json['business_name']),
        logoUrl: json['logo_url'] is String ? json['logo_url'] as String : null,
      );
}

class Cart {
  const Cart({
    required this.id,
    required this.items,
    required this.subtotal,
    this.vendor,
    this.itemsCount = 0,
    this.currency = 'XOF',
    this.status,
  });

  final String id;
  final List<CartItem> items;
  final int subtotal;
  final CartVendor? vendor;
  final int itemsCount;
  final String currency;
  final String? status;

  bool get isEmpty => items.isEmpty;

  factory Cart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<CartItem> items = [];
    if (rawItems is List) {
      items = rawItems.whereType<Map<String, dynamic>>().map(CartItem.fromJson).toList();
    }

    final rawVendor = json['vendor'];
    CartVendor? vendor;
    if (rawVendor is Map<String, dynamic>) {
      vendor = CartVendor.fromJson(rawVendor);
    }

    return Cart(
      id: _s(json['id']),
      items: items,
      subtotal: _i(json['subtotal']),
      vendor: vendor,
      itemsCount: json['items_count'] is int ? json['items_count'] as int : items.length,
      currency: _s(json['currency'], 'XOF'),
      status: json['status'] is String ? json['status'] as String : null,
    );
  }
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;

int _i(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}