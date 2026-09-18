class Address {
  const Address({
    required this.id,
    this.label,
    this.zoneId,
    this.fullAddress,
    this.landmark,
    this.latitude,
    this.longitude,
    this.city,
    this.area,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? label;
  final String? zoneId;
  final String? fullAddress;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? area;
  final bool isDefault;
  final String? createdAt;
  final String? updatedAt;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: _s(json['id']),
        label: json['label'] is String ? json['label'] as String : null,
        zoneId: json['zone_id'] is String ? json['zone_id'] as String : null,
        fullAddress: json['full_address'] is String ? json['full_address'] as String : null,
        landmark: json['landmark'] is String ? json['landmark'] as String : null,
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        city: json['city'] is String ? json['city'] as String : null,
        area: json['area'] is String ? json['area'] as String : null,
        isDefault: json['is_default'] == true,
        createdAt: json['created_at'] is String ? json['created_at'] as String : null,
        updatedAt: json['updated_at'] is String ? json['updated_at'] as String : null,
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