import 'geo_point.dart';

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    this.reference,
    this.status,
    this.total,
    this.subtotal,
    this.deliveryFee,
    this.address,
    this.addressSnapshot,
    this.client,
    this.items = const [],
  });

  final String id;
  final String? reference;
  final String? status;
  final int? total;
  final int? subtotal;
  final int? deliveryFee;
  final String? address;

  /// Adresse de livraison figée (coordonnées + libellé) : sert au guidage GPS.
  final AddressSnapshot? addressSnapshot;

  final DeliveryClient? client;

  /// Contenu du colis (lignes de commande + photos) pour le livreur.
  final List<DeliveryOrderItem> items;

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final rawClient = json['client'];
    final rawAddress = json['address'];
    final rawItems = json['items'];
    // L'API renvoie l'objet `address_snapshot` ; on tolère aussi l'ancienne
    // forme (chaîne) pour les commandes créées avant le passage aux cartes.
    final snapshot = rawAddress == null ? null : AddressSnapshot.fromJson(rawAddress);
    final display = rawAddress is String && rawAddress.isNotEmpty
        ? rawAddress
        : (snapshot == null || snapshot.display.isEmpty)
            ? null
            : snapshot.display;
    return DeliveryOrder(
      id: _s(json['id']),
      reference: json['reference'] is String ? json['reference'] as String : null,
      status: json['status'] is String ? json['status'] as String : null,
      total: _iNull(json['total']),
      subtotal: _iNull(json['subtotal']),
      deliveryFee: _iNull(json['delivery_fee']),
      address: display,
      addressSnapshot: snapshot,
      client: rawClient is Map<String, dynamic> ? DeliveryClient.fromJson(rawClient) : null,
      items: rawItems is List
          ? rawItems.whereType<Map<String, dynamic>>().map(DeliveryOrderItem.fromJson).toList()
          : const [],
    );
  }
}

/// Ligne de colis vue par le livreur : produit, quantité et photo.
class DeliveryOrderItem {
  const DeliveryOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.imageUrl,
  });

  final String id;
  final String name;
  final int quantity;
  final String? imageUrl;

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> json) => DeliveryOrderItem(
        id: _s(json['id']),
        name: _s(json['name']),
        quantity: _i(json['quantity']),
        imageUrl: json['image_url'] is String ? json['image_url'] as String : null,
      );
}

class DeliveryClient {
  const DeliveryClient({required this.id, this.name, this.phone});

  final String id;
  final String? name;
  final String? phone;

  factory DeliveryClient.fromJson(Map<String, dynamic> json) => DeliveryClient(
        id: _s(json['id']),
        name: json['name'] is String ? json['name'] as String : null,
        phone: json['phone'] is String ? json['phone'] as String : null,
      );
}

class DeliveryVendor {
  const DeliveryVendor({
    required this.id,
    this.businessName,
    this.address,
    this.city,
    this.phone,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String? businessName;
  final String? address;
  final String? city;
  final String? phone;
  final double? latitude;
  final double? longitude;

  factory DeliveryVendor.fromJson(Map<String, dynamic> json) => DeliveryVendor(
        id: _s(json['id']),
        businessName: json['business_name'] is String ? json['business_name'] as String : null,
        address: json['address'] is String ? json['address'] as String : null,
        city: json['city'] is String ? json['city'] as String : null,
        phone: json['phone'] is String ? json['phone'] as String : null,
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
      );
}

class Delivery {
  const Delivery({
    required this.id,
    required this.status,
    required this.fee,
    this.partnerAmount,
    this.order,
    this.vendor,
    this.proofCode,
    this.createdAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.currency = 'XOF',
  });

  final String id;
  final String status;
  final int fee;
  final int? partnerAmount;
  final DeliveryOrder? order;
  final DeliveryVendor? vendor;
  final String? proofCode;
  final String? createdAt;
  final String? assignedAt;
  final String? pickedUpAt;
  final String? deliveredAt;
  final String currency;

  bool get isAvailable => status == 'available' || status == 'proposed';
  bool get isAssigned => status == 'assigned';
  bool get canPickup => status == 'assigned';
  bool get canStart => status == 'picked_up';
  bool get canDeliver => status == 'in_delivery';

  /// Point de collecte : les coordonnées du vendeur.
  GeoPoint? get pickupPoint {
    final lat = vendor?.latitude;
    final lng = vendor?.longitude;
    if (lat == null || lng == null) {
      return null;
    }
    return GeoPoint(lat, lng);
  }

  /// Point de livraison : les coordonnées figées dans la commande.
  GeoPoint? get dropoffPoint => order?.addressSnapshot?.point;

  factory Delivery.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'];
    final rawVendor = json['vendor'];
    DeliveryOrder? order;
    if (rawOrder is Map<String, dynamic>) {
      order = DeliveryOrder.fromJson(rawOrder);
    }
    DeliveryVendor? vendor;
    if (rawVendor is Map<String, dynamic>) {
      vendor = DeliveryVendor.fromJson(rawVendor);
    }

    return Delivery(
      id: _s(json['id']),
      status: _s(json['status']),
      fee: _i(json['fee']),
      partnerAmount: _iNull(json['partner_amount']),
      order: order,
      vendor: vendor,
      proofCode: json['proof_code'] is String ? json['proof_code'] as String : null,
      createdAt: _nullable(json['created_at']),
      assignedAt: _nullable(json['assigned_at']),
      pickedUpAt: _nullable(json['picked_up_at']),
      deliveredAt: _nullable(json['delivered_at']),
      currency: _s(json['currency'], 'XOF'),
    );
  }
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;

String? _nullable(dynamic value) => value is String ? value : null;

int _i(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

int? _iNull(dynamic value) => value == null ? null : _i(value);

double? _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}