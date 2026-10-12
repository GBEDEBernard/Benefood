import 'geo_point.dart';

/// Envoi de colis (cahier de conception v1.0, phase 3).
///
/// Reflet du `ParcelResource` : statut, adresses (ramassage/dépose), tarif
/// réparti 80 % livreur / 20 % plateforme, livreur assigné et journal d'état.
class Parcel {
  const Parcel({
    required this.id,
    required this.reference,
    this.status = '',
    this.paymentStatus = '',
    this.description,
    this.currency = 'XOF',
    this.pickup,
    this.dropoff,
    this.distanceKm,
    this.deliveryFee = 0,
    this.commissionRate = 20,
    this.commissionAmount = 0,
    this.partnerAmount = 0,
    this.platformAmount = 0,
    this.proofCode,
    this.driver,
    this.payment,
    this.statusHistory = const [],
    this.paymentDeadlineAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
    this.createdAt,
  });

  final String id;
  final String reference;
  final String status;
  final String paymentStatus;
  final String? description;
  final String currency;
  final ParcelAddress? pickup;
  final ParcelAddress? dropoff;
  final double? distanceKm;
  final int deliveryFee;
  final int commissionRate;
  final int commissionAmount;
  final int partnerAmount;
  final int platformAmount;
  final String? proofCode;
  final ParcelDriver? driver;
  final ParcelPayment? payment;
  final List<ParcelStatusStep> statusHistory;
  final String? paymentDeadlineAt;
  final String? assignedAt;
  final String? pickedUpAt;
  final String? deliveredAt;
  final String? cancelledAt;
  final String? cancellationReason;
  final String? createdAt;

  bool get isAwaitingPayment => status == 'awaiting_payment';
  bool get isPaid => status == 'paid' || paymentStatus == 'confirmed' || paymentStatus == 'paid';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';

  /// Le colis a été payé et attend encore un livreur (offre disponible).
  bool get isAvailable => status == 'paid';

  /// Actions livreur.
  bool get canPickup => status == 'assigned';
  bool get canStart => status == 'picked_up';
  bool get canDeliver => status == 'in_delivery';

  /// Spécifique à Devis colis (avant création) : aucun id assigné.
  bool get isQuote => id.isEmpty;

  /// Point de ramassage pour la carte.
  GeoPoint? get pickupPoint => pickup?.point;

  /// Point de livraison pour la carte.
  GeoPoint? get dropoffPoint => dropoff?.point;

  factory Parcel.fromJson(Map<String, dynamic> json) {
    final rawPickup = json['pickup'];
    final rawDropoff = json['dropoff'];
    final rawDriver = json['driver'];
    final rawPayment = json['payment'];
    final rawHistory = json['status_history'];

    return Parcel(
      id: _s(json['id']),
      reference: _s(json['reference']),
      status: _s(json['status']),
      paymentStatus: _s(json['payment_status']),
      description: json['description'] is String ? json['description'] as String : null,
      currency: _s(json['currency'], 'XOF'),
      pickup: rawPickup is Map<String, dynamic> ? ParcelAddress.fromJson(rawPickup) : null,
      dropoff: rawDropoff is Map<String, dynamic> ? ParcelAddress.fromJson(rawDropoff) : null,
      distanceKm: _d(json['distance_km']),
      deliveryFee: _i(json['delivery_fee']),
      commissionRate: _i(json['commission_rate'], 20),
      commissionAmount: _i(json['commission_amount']),
      partnerAmount: _i(json['partner_amount']),
      platformAmount: _i(json['platform_amount']),
      proofCode: json['proof_code'] is String ? json['proof_code'] as String : null,
      driver: rawDriver is Map<String, dynamic> ? ParcelDriver.fromJson(rawDriver) : null,
      payment: rawPayment is Map<String, dynamic> ? ParcelPayment.fromJson(rawPayment) : null,
      statusHistory: rawHistory is List
          ? rawHistory.whereType<Map<String, dynamic>>().map(ParcelStatusStep.fromJson).toList()
          : const [],
      paymentDeadlineAt: _nullable(json['payment_deadline_at']),
      assignedAt: _nullable(json['assigned_at']),
      pickedUpAt: _nullable(json['picked_up_at']),
      deliveredAt: _nullable(json['delivered_at']),
      cancelledAt: _nullable(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] is String ? json['cancellation_reason'] as String : null,
      createdAt: _nullable(json['created_at']),
    );
  }
}

/// Adresse figée d'un colis (ramassage ou dépose).
class ParcelAddress {
  const ParcelAddress({
    this.label,
    this.addressText,
    this.area,
    this.city,
    this.latitude,
    this.longitude,
  });

  final String? label;
  final String? addressText;
  final String? area;
  final String? city;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
  GeoPoint? get point => hasCoordinates ? GeoPoint(latitude!, longitude!) : null;

  /// Libellé compact affiché sur les cartes : « Quartier — Ville ».
  String get display {
    final parts = [
      label,
      area,
      addressText,
      city,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Adresse non précisée' : parts.join(' · ');
  }

  factory ParcelAddress.fromJson(Map<String, dynamic> json) => ParcelAddress(
        label: json['label'] is String ? json['label'] as String : null,
        addressText: json['address_text'] is String ? json['address_text'] as String : null,
        area: json['area'] is String ? json['area'] as String : null,
        city: json['city'] is String ? json['city'] as String : null,
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
      );

  Map<String, dynamic> toJson() => {
        if (label != null && label!.isNotEmpty) 'label': label,
        if (addressText != null && addressText!.isNotEmpty) 'address_text': addressText,
        if (area != null && area!.isNotEmpty) 'area': area,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// Livreur assigné au colis (tel que renvoyé par le API).
class ParcelDriver {
  const ParcelDriver({required this.id, this.name, this.phone, this.vehicle, this.rating});

  final String id;
  final String? name;
  final String? phone;
  final String? vehicle;
  final double? rating;

  factory ParcelDriver.fromJson(Map<String, dynamic> json) => ParcelDriver(
        id: _s(json['id']),
        name: json['name'] is String ? json['name'] as String : null,
        phone: json['phone'] is String ? json['phone'] as String : null,
        vehicle: json['vehicle'] is String ? json['vehicle'] as String : null,
        rating: _d(json['rating']),
      );
}

/// Paiement du colis.
class ParcelPayment {
  const ParcelPayment({required this.id, this.reference, this.status, this.amount = 0});

  final String id;
  final String? reference;
  final String? status;
  final int amount;

  factory ParcelPayment.fromJson(Map<String, dynamic> json) => ParcelPayment(
        id: _s(json['id']),
        reference: json['reference'] is String ? json['reference'] as String : null,
        status: json['status'] is String ? json['status'] as String : null,
        amount: _i(json['amount']),
      );
}

/// Étape du journal d'état d'un colis.
class ParcelStatusStep {
  const ParcelStatusStep({
    this.fromStatus,
    this.toStatus,
    this.actorType,
    this.reason,
    this.createdAt,
  });

  final String? fromStatus;
  final String? toStatus;
  final String? actorType;
  final String? reason;
  final String? createdAt;

  factory ParcelStatusStep.fromJson(Map<String, dynamic> json) => ParcelStatusStep(
        fromStatus: json['from_status'] is String ? json['from_status'] as String : null,
        toStatus: json['to_status'] is String ? json['to_status'] as String : null,
        actorType: json['actor_type'] is String ? json['actor_type'] as String : null,
        reason: json['reason'] is String ? json['reason'] as String : null,
        createdAt: json['created_at'] is String ? json['created_at'] as String : null,
      );
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;

String? _nullable(dynamic value) => value is String ? value : null;

int _i(dynamic value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

double? _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}