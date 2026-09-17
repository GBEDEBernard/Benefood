class ProductImage {
  const ProductImage({
    required this.id,
    required this.url,
    this.thumbUrl,
    this.isMain = false,
  });

  final String id;
  final String url;
  final String? thumbUrl;
  final bool isMain;

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
        id: _s(json['id']),
        url: _s(json['url']),
        thumbUrl: json['thumb_url'] is String ? json['thumb_url'] as String : null,
        isMain: json['is_main'] == true,
      );
}

class Product {
  const Product({
    required this.id,
    required this.vendorId,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description,
    required this.currency,
    required this.unit,
    this.stockQty,
    this.imageUrl,
    this.imageMain,
    this.images = const [],
    this.isActive = true,
    this.isAvailable = true,
    this.isOrderable = true,
    this.status = 'active',
    this.vendorName,
  });

  final String id;
  final String vendorId;
  final String categoryId;
  final String name;
  final String? description;
  final int price;
  final String currency;
  final String unit;
  final int? stockQty;
  final String? imageUrl;
  final String? imageMain;
  final List<ProductImage> images;
  final bool isActive;
  final bool isAvailable;
  final bool isOrderable;
  final String status;
  final String? vendorName;

  bool get isOutOfStock => stockQty != null && stockQty == 0;

  String get displayPrice => price.toString();

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    List<ProductImage> images = [];
    if (rawImages is List) {
      images = rawImages
          .whereType<Map<String, dynamic>>()
          .map(ProductImage.fromJson)
          .toList();
    }

    return Product(
      id: _s(json['id']),
      vendorId: _s(json['vendor_id']),
      categoryId: _s(json['category_id']),
      name: _s(json['name']),
      description: json['description'] is String ? json['description'] as String : null,
      price: _i(json['price']),
      currency: _s(json['currency'], 'XOF'),
      unit: _s(json['unit'], 'pce'),
      stockQty: json['stock_qty'] is int ? json['stock_qty'] as int : null,
      imageUrl: json['image_url'] is String ? json['image_url'] as String : null,
      imageMain: json['image_main'] is String ? json['image_main'] as String : null,
      images: images,
      isActive: json['is_active'] != false,
      isAvailable: json['is_available'] != false,
      isOrderable: json['is_orderable'] != false,
      status: _s(json['status'], 'active'),
      vendorName: json['vendor_name'] is String ? json['vendor_name'] as String : null,
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