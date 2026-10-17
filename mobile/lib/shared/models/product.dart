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
    this.videoUrl,
    this.images = const [],
    this.isActive = true,
    this.isAvailable = true,
    this.isOrderable = true,
    this.status = 'active',
    this.vendorName,
    this.rating,
    this.reviewsCount,
    this.likesCount,
    this.distanceKm,
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
  final String? videoUrl;
  final List<ProductImage> images;
  final bool isActive;
  final bool isAvailable;
  final bool isOrderable;
  final String status;
  final String? vendorName;

  /// Statistiques optionnelles exposées par le backend (souvent absentes en
  /// développement) : remplacées par des valeurs de démonstration sinon.
  final double? rating;
  final int? reviewsCount;
  final int? likesCount;

  /// Distance au vendeur (renseignée par la recherche par proximité).
  final double? distanceKm;

  bool get isOutOfStock => stockQty != null && stockQty == 0;

  /// Distance à l'utilisateur, ex. « 2,3 km » ou « 850 m ».
  String? get distanceLabel {
    final distance = distanceKm;
    if (distance == null) {
      return null;
    }
    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    }
    return '${distance.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// URL d'image principale réellement affichable : photo chargée (tableau
  /// `images`) sinon `image_url` résolue par le backend. `image_main` brut
  /// (chemin de stockage) n'est volontairement pas utilisé.
  String? get displayImageUrl {
    if (images.isNotEmpty) {
      final main = images.firstWhere((i) => i.isMain, orElse: () => images.first);
      if (main.url.isNotEmpty) {
        return main.url;
      }
    }
    return imageUrl;
  }

  /// URLs de la galerie produit (photos chargées sinon image principale).
  List<String> get galleryImageUrls {
    if (images.isNotEmpty) {
      final urls = images
          .map((i) => i.url)
          .where((url) => url.isNotEmpty)
          .toList();
      if (urls.isNotEmpty) {
        return urls;
      }
    }
    final url = imageUrl;
    return (url != null && url.isNotEmpty) ? [url] : const [];
  }

  /// Produit rangé dans l'archivage (désactivé — plus proposé à la vente).
  bool get archived => !isActive || status == 'archived';

  Product copyWith({bool? isAvailable, bool? isActive, String? status}) {
    return Product(
      id: id,
      vendorId: vendorId,
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      currency: currency,
      unit: unit,
      stockQty: stockQty,
      imageUrl: imageUrl,
      imageMain: imageMain,
      videoUrl: videoUrl,
      images: images,
      isActive: isActive ?? this.isActive,
      isAvailable: isAvailable ?? this.isAvailable,
      isOrderable: isOrderable,
      status: status ?? this.status,
      vendorName: vendorName,
      rating: rating,
      reviewsCount: reviewsCount,
      likesCount: likesCount,
      distanceKm: distanceKm,
    );
  }

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
      description: json['description'] is String
          ? json['description'] as String
          : null,
      price: _i(json['price']),
      currency: _s(json['currency'], 'XOF'),
      unit: _s(json['unit'], 'pce'),
      stockQty: json['stock_qty'] is int ? json['stock_qty'] as int : null,
      imageUrl: json['image_url'] is String
          ? json['image_url'] as String
          : null,
      imageMain: json['image_main'] is String
          ? json['image_main'] as String
          : null,
      videoUrl: json['video_url'] is String
          ? json['video_url'] as String
          : null,
      images: images,
      isActive: json['is_active'] != false,
      isAvailable: json['is_available'] != false,
      isOrderable: json['is_orderable'] != false,
      status: _s(json['status'], 'active'),
      vendorName: json['vendor_name'] is String
          ? json['vendor_name'] as String
          : null,
      rating: _d(json['rating']),
      reviewsCount: _i(json['reviews_count']),
      likesCount: _i(json['likes_count']),
      distanceKm: _d(json['distance_km']),
    );
  }
}

String _s(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

double? _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

int _i(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
