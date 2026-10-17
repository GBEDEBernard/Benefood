enum VendorType {
  boutique('boutique', 'Boutique'),
  restaurant('restaurant', 'Restaurant'),
  maquis('maquis', 'Maquis');

  const VendorType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static VendorType? fromApi(String? value) {
    for (final type in VendorType.values) {
      if (type.apiValue == value) {
        return type;
      }
    }
    return null;
  }
}

class Vendor {
  const Vendor({
    required this.id,
    required this.businessName,
    this.userId,
    this.legalName,
    this.ifu,
    this.description,
    this.phone,
    this.email,
    this.city,
    this.area,
    this.address,
    this.pickupAddress,
    this.pickupLandmark,
    this.deliveryInstructions,
    this.status = 'active',
    this.logoUrl,
    this.coverUrl,
    this.isOpen,
    this.latitude,
    this.longitude,
    this.approvedAt,
    this.createdAt,
    this.maxPreparationMinutes,
    this.rating,
    this.reviewsCount = 0,
    this.type,
    this.distanceKm,
  });

  final String id;
  final String? userId;
  final String businessName;
  final String? legalName;
  final String? ifu;
  final String? description;
  final String? phone;
  final String? email;
  final String? city;
  final String? area;
  final String? address;
  final String? pickupAddress;
  final String? pickupLandmark;
  final String? deliveryInstructions;
  final String status;
  final String? logoUrl;
  final String? coverUrl;
  final bool? isOpen;
  final double? latitude;
  final double? longitude;
  final String? approvedAt;
  final String? createdAt;
  final int? maxPreparationMinutes;
  final double? rating;
  final int reviewsCount;
  final VendorType? type;
  final double? distanceKm;

  bool get isActive => status == 'active';
  bool get isOpenResolved => isOpen ?? false;

  /// Délai estimé de livraison, ex. « 30-45 min » (même convention que /home).
  String? get etaLabel {
    final minutes = maxPreparationMinutes;
    if (minutes == null) {
      return null;
    }
    return '$minutes-${minutes + 15} min';
  }

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

  factory Vendor.fromJson(Map<String, dynamic> json) => Vendor(
        id: _s(json['id']),
        userId: json['user_id'] is String ? json['user_id'] as String : null,
        businessName: _s(json['business_name']),
        legalName: json['legal_name'] is String ? json['legal_name'] as String : null,
        ifu: json['ifu'] is String ? json['ifu'] as String : null,
        description: json['description'] is String ? json['description'] as String : null,
        phone: json['phone'] is String ? json['phone'] as String : null,
        email: json['email'] is String ? json['email'] as String : null,
        city: json['city'] is String ? json['city'] as String : null,
        area: json['area'] is String ? json['area'] as String : null,
        address: json['address'] is String ? json['address'] as String : null,
        pickupAddress: json['pickup_address'] is String ? json['pickup_address'] as String : null,
        pickupLandmark: json['pickup_landmark'] is String ? json['pickup_landmark'] as String : null,
        deliveryInstructions:
            json['delivery_instructions'] is String ? json['delivery_instructions'] as String : null,
        status: _s(json['status'], 'active'),
        logoUrl: json['logo_url'] is String ? json['logo_url'] as String : null,
        coverUrl: json['cover_url'] is String ? json['cover_url'] as String : null,
        isOpen: json['is_open'] is bool ? json['is_open'] as bool : null,
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        approvedAt: json['approved_at'] is String ? json['approved_at'] as String : null,
        createdAt: json['created_at'] is String ? json['created_at'] as String : null,
        maxPreparationMinutes:
            json['max_preparation_minutes'] is int
                ? json['max_preparation_minutes'] as int
                : (json['prep_minutes'] is int ? json['prep_minutes'] as int : null),
        rating: _d(json['rating']),
        reviewsCount: json['reviews_count'] is int ? json['reviews_count'] as int : 0,
        type: VendorType.fromApi(json['type'] is String ? json['type'] as String : null),
        distanceKm: _d(json['distance_km']),
      );
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;

double? _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}