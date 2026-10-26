import 'geo_point.dart';

/// Envoi de colis (cahier de conception v1.0, phase 3).
///
/// Reflet du `ParcelResource` : statut, adresses (ramassage/dépose), frais de
/// livraison + frais de création, livreur assigné et journal d'état.
class Parcel {
  const Parcel({
    required this.id,
    required this.reference,
    this.status = '',
    this.paymentStatus = '',
    this.paymentMethod = '',
    this.description,
    this.currency = 'XOF',
    this.pickup,
    this.dropoff,
    this.distanceKm,
    this.deliveryFee = 0,
    this.creationFee = 0,
    this.totalAmount = 0,
    this.commissionRate = 20,
    this.commissionAmount = 0,
    this.partnerAmount = 0,
    this.platformAmount = 0,
    this.proofCode,
    this.confirmationCode,
    this.sender,
    this.driver,
    this.position,
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
  final String paymentMethod;
  final String? description;
  final String currency;
  final ParcelAddress? pickup;
  final ParcelAddress? dropoff;
  final double? distanceKm;
  final int deliveryFee;

  /// Frais fixes payés par le créateur du colis, en plus de la livraison.
  final int creationFee;

  /// Total payé par le créateur (livraison + création).
  final int totalAmount;
  final int commissionRate;
  final int commissionAmount;
  final int partnerAmount;
  final int platformAmount;
  final String? proofCode;

  /// Code remis à l'expéditeur/destinataire, à saisir par le livreur.
  final String? confirmationCode;

  /// Expéditeur du colis (utile au livreur pour joindre le point de collecte).
  final ParcelSender? sender;
  final ParcelDriver? driver;

  /// Dernière position partagée par le livreur pendant la course.
  final ParcelPosition? position;
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
  bool get isCash => paymentMethod == 'cash';
  bool get isPaid =>
      status == 'paid' ||
      paymentStatus == 'confirmed' ||
      paymentStatus == 'paid';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';

  /// Course active : le suivi doit continuer tant que le colis roule.
  bool get isTrackingActive => const {
    'assigned',
    'en_route_pickup',
    'picked_up',
    'in_delivery',
  }.contains(status);

  bool get isPickupPhase => status == 'assigned' || status == 'en_route_pickup';

  /// Le colis a été payé et attend encore un livreur (offre disponible).
  bool get isAvailable => status == 'paid';

  /// Actions livreur.
  bool get isEnRoutePickup => status == 'en_route_pickup';
  bool get canStartPickup => status == 'assigned';
  bool get canPickup => status == 'assigned' || status == 'en_route_pickup';
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
    final rawSender = json['sender'];
    final rawDriver = json['driver'];
    final rawPosition = json['position'];
    final rawPayment = json['payment'];
    final rawHistory = json['status_history'];

    return Parcel(
      id: _s(json['id']),
      reference: _s(json['reference']),
      status: _s(json['status']),
      paymentStatus: _s(json['payment_status']),
      paymentMethod: _s(json['payment_method']),
      description: json['description'] is String
          ? json['description'] as String
          : null,
      currency: _s(json['currency'], 'XOF'),
      pickup: rawPickup is Map<String, dynamic>
          ? ParcelAddress.fromJson(rawPickup)
          : null,
      dropoff: rawDropoff is Map<String, dynamic>
          ? ParcelAddress.fromJson(rawDropoff)
          : null,
      distanceKm: _d(json['distance_km']),
      deliveryFee: _i(json['delivery_fee']),
      creationFee: _i(json['creation_fee']),
      totalAmount: json['total_amount'] != null
          ? _i(json['total_amount'])
          : _i(json['delivery_fee']) + _i(json['creation_fee']),
      commissionRate: _i(json['commission_rate'], 20),
      commissionAmount: _i(json['commission_amount']),
      partnerAmount: _i(json['partner_amount']),
      platformAmount: _i(json['platform_amount']),
      proofCode: json['proof_code'] is String
          ? json['proof_code'] as String
          : null,
      confirmationCode: json['confirmation_code'] is String
          ? json['confirmation_code'] as String
          : null,
      sender: rawSender is Map<String, dynamic>
          ? ParcelSender.fromJson(rawSender)
          : null,
      driver: rawDriver is Map<String, dynamic>
          ? ParcelDriver.fromJson(rawDriver)
          : null,
      position: rawPosition is Map<String, dynamic>
          ? ParcelPosition.fromJson(rawPosition)
          : null,
      payment: rawPayment is Map<String, dynamic>
          ? ParcelPayment.fromJson(rawPayment)
          : null,
      statusHistory: rawHistory is List
          ? rawHistory
                .whereType<Map<String, dynamic>>()
                .map(ParcelStatusStep.fromJson)
                .toList()
          : const [],
      paymentDeadlineAt: _nullable(json['payment_deadline_at']),
      assignedAt: _nullable(json['assigned_at']),
      pickedUpAt: _nullable(json['picked_up_at']),
      deliveredAt: _nullable(json['delivered_at']),
      cancelledAt: _nullable(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] is String
          ? json['cancellation_reason'] as String
          : null,
      createdAt: _nullable(json['created_at']),
    );
  }
}

/// Adresse figée d'un colis (ramassage ou dépose).
class ParcelAddress {
  const ParcelAddress({
    this.label,
    this.addressText,
    this.landmark,
    this.area,
    this.city,
    this.latitude,
    this.longitude,
    this.contactName,
    this.contactPhone,
  });

  final String? label;
  final String? addressText;
  final String? landmark;
  final String? area;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? contactName;
  final String? contactPhone;

  bool get hasCoordinates => latitude != null && longitude != null;
  GeoPoint? get point =>
      hasCoordinates ? GeoPoint(latitude!, longitude!) : null;

  /// Libellé compact affiché sur les cartes : « Quartier — Ville ».
  String get display {
    final parts = [
      label,
      area,
      addressText,
      if (landmark != null && landmark!.trim().isNotEmpty)
        'près de ${landmark!.trim()}',
      city,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Adresse non précisée' : parts.join(' · ');
  }

  factory ParcelAddress.fromJson(Map<String, dynamic> json) => ParcelAddress(
    label: json['label'] is String ? json['label'] as String : null,
    addressText: json['address_text'] is String
        ? json['address_text'] as String
        : null,
    landmark: json['landmark'] is String ? json['landmark'] as String : null,
    area: json['area'] is String ? json['area'] as String : null,
    city: json['city'] is String ? json['city'] as String : null,
    latitude: _d(json['latitude']),
    longitude: _d(json['longitude']),
    contactName: json['contact_name'] is String
        ? json['contact_name'] as String
        : null,
    contactPhone: json['contact_phone'] is String
        ? json['contact_phone'] as String
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (label != null && label!.isNotEmpty) 'label': label,
    if (addressText != null && addressText!.isNotEmpty)
      'address_text': addressText,
    if (landmark != null && landmark!.isNotEmpty) 'landmark': landmark,
    if (area != null && area!.isNotEmpty) 'area': area,
    if (city != null && city!.isNotEmpty) 'city': city,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (contactName != null && contactName!.isNotEmpty)
      'contact_name': contactName,
    if (contactPhone != null && contactPhone!.isNotEmpty)
      'contact_phone': contactPhone,
  };
}

/// Expéditeur d'un colis.
class ParcelSender {
  const ParcelSender({required this.id, this.name, this.phone, this.avatarUrl});

  final String id;
  final String? name;
  final String? phone;

  /// Photo de profil de l'expéditeur (marqueur de collecte).
  final String? avatarUrl;

  factory ParcelSender.fromJson(Map<String, dynamic> json) => ParcelSender(
    id: _s(json['id']),
    name: json['name'] is String ? json['name'] as String : null,
    phone: json['phone'] is String ? json['phone'] as String : null,
    avatarUrl: json['avatar_url'] is String
        ? json['avatar_url'] as String
        : null,
  );
}

/// Livreur assigné au colis (tel que renvoyé par le API).
class ParcelDriver {
  const ParcelDriver({
    required this.id,
    this.name,
    this.phone,
    this.avatarUrl,
    this.vehicle,
    this.rating,
  });

  final String id;
  final String? name;
  final String? phone;

  /// Photo de profil du livreur, affichée sur les cartes de suivi.
  final String? avatarUrl;
  final String? vehicle;
  final double? rating;

  factory ParcelDriver.fromJson(Map<String, dynamic> json) => ParcelDriver(
    id: _s(json['id']),
    name: json['name'] is String ? json['name'] as String : null,
    phone: json['phone'] is String ? json['phone'] as String : null,
    avatarUrl: json['avatar_url'] is String
        ? json['avatar_url'] as String
        : null,
    vehicle: json['vehicle'] is String ? json['vehicle'] as String : null,
    rating: _d(json['rating']),
  );
}

/// Position GPS du livreur pendant la course colis.
class ParcelPosition {
  const ParcelPosition({
    required this.latitude,
    required this.longitude,
    this.lastLocationAt,
    this.distanceKm,
    this.heading,
    this.ageSeconds,
  });

  final double latitude;
  final double longitude;
  final String? lastLocationAt;
  final double? distanceKm;
  final double? heading;
  final int? ageSeconds;

  GeoPoint get point => GeoPoint(latitude, longitude);

  factory ParcelPosition.fromJson(Map<String, dynamic> json) => ParcelPosition(
    latitude: _d(json['latitude']) ?? 0,
    longitude: _d(json['longitude']) ?? 0,
    lastLocationAt: json['last_location_at'] is String
        ? json['last_location_at'] as String
        : null,
    distanceKm: _d(json['distance_km']),
    heading: _d(json['heading']),
    ageSeconds: _iNullable(json['age_seconds']),
  );
}

/// Paiement du colis.
class ParcelPayment {
  const ParcelPayment({
    required this.id,
    this.reference,
    this.status,
    this.amount = 0,
  });

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

  factory ParcelStatusStep.fromJson(Map<String, dynamic> json) =>
      ParcelStatusStep(
        fromStatus: json['from_status'] is String
            ? json['from_status'] as String
            : null,
        toStatus: json['to_status'] is String
            ? json['to_status'] as String
            : null,
        actorType: json['actor_type'] is String
            ? json['actor_type'] as String
            : null,
        reason: json['reason'] is String ? json['reason'] as String : null,
        createdAt: json['created_at'] is String
            ? json['created_at'] as String
            : null,
      );
}

String _s(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

String? _nullable(dynamic value) => value is String ? value : null;

int? _iNullable(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

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
