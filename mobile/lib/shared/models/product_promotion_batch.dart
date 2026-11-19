import 'product_promotion.dart';

/// Résultat de l'application d'un pourcentage à plusieurs plats.
class ProductPromotionBatch {
  const ProductPromotionBatch({
    required this.promotions,
    required this.skipped,
    this.createdCount = 0,
    this.skippedCount = 0,
  });

  final List<ProductPromotion> promotions;
  final List<ProductPromotionSkip> skipped;
  final int createdCount;
  final int skippedCount;

  bool get hasCreated => promotions.isNotEmpty;

  int get totalCount => createdCount + skippedCount;

  factory ProductPromotionBatch.fromJson(Map<String, dynamic> json) {
    final rawPromotions = json['promotions'];
    final rawSkipped = json['skipped'];

    return ProductPromotionBatch(
      promotions: rawPromotions is List
          ? rawPromotions
              .whereType<Map<String, dynamic>>()
              .map(ProductPromotion.fromJson)
              .toList()
          : const [],
      skipped: rawSkipped is List
          ? rawSkipped
              .whereType<Map<String, dynamic>>()
              .map(ProductPromotionSkip.fromJson)
              .toList()
          : const [],
      createdCount: _int(json['created_count']),
      skippedCount: _int(json['skipped_count']),
    );
  }
}

/// Plat pour lequel la promotion n'a pas pu être créée.
class ProductPromotionSkip {
  const ProductPromotionSkip({
    required this.productId,
    required this.productName,
    required this.code,
    required this.message,
  });

  final String productId;
  final String productName;
  final String code;
  final String message;

  factory ProductPromotionSkip.fromJson(Map<String, dynamic> json) =>
      ProductPromotionSkip(
        productId: json['product_id']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? 'Produit',
        code: json['code']?.toString() ?? 'unknown',
        message: json['message']?.toString() ?? 'Offre impossible sur ce plat.',
      );
}

int _int(dynamic value) => value is num ? value.toInt() : 0;
