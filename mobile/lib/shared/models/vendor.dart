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
    this.address,
    this.status = 'active',
    this.logoUrl,
    this.coverUrl,
    this.isOpen,
    this.latitude,
    this.longitude,
    this.approvedAt,
    this.createdAt,
    this.maxPreparationMinutes,
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
  final String? address;
  final String status;
  final String? logoUrl;
  final String? coverUrl;
  final bool? isOpen;
  final double? latitude;
  final double? longitude;
  final String? approvedAt;
  final String? createdAt;
  final int? maxPreparationMinutes;

  bool get isActive => status == 'active';
  bool get isOpenResolved => isOpen ?? false;

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
        address: json['address'] is String ? json['address'] as String : null,
        status: _s(json['status'], 'active'),
        logoUrl: json['logo_url'] is String ? json['logo_url'] as String : null,
        coverUrl: json['cover_url'] is String ? json['cover_url'] as String : null,
        isOpen: json['is_open'] is bool ? json['is_open'] as bool : null,
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        approvedAt: json['approved_at'] is String ? json['approved_at'] as String : null,
        createdAt: json['created_at'] is String ? json['created_at'] as String : null,
        maxPreparationMinutes:
            json['max_preparation_minutes'] is int ? json['max_preparation_minutes'] as int : null,
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