import 'delivery.dart';
import 'geo_point.dart';
import 'parcel.dart';

enum DriverMissionKind { order, parcel }

class DriverMissionStop {
  const DriverMissionStop({
    required this.title,
    required this.address,
    this.contactName,
    this.contactPhone,
    this.point,
    this.note,
  });

  final String title;
  final String address;
  final String? contactName;
  final String? contactPhone;
  final GeoPoint? point;
  final String? note;

  String get displayAddress {
    final parts = [
      address.trim(),
      note?.trim() ?? '',
    ].where((part) => part.isNotEmpty).toList(growable: false);
    return parts.isEmpty ? 'Adresse non précisée' : parts.join(' · ');
  }
}

class DriverMissionItem {
  const DriverMissionItem({
    required this.name,
    required this.quantity,
    this.imageUrl,
  });

  final String name;
  final int quantity;
  final String? imageUrl;
}

class DriverMission {
  const DriverMission({
    required this.id,
    required this.kind,
    required this.reference,
    required this.status,
    required this.pickup,
    required this.dropoff,
    this.items = const [],
    this.description,
    this.earnings = 0,
    this.clientFee = 0,
    this.merchantName,
    this.merchantType,
    this.merchantLogoUrl,
    this.distanceKm,
    this.createdAt,
    this.deliveredAt,
  });

  final String id;
  final DriverMissionKind kind;
  final String reference;
  final String status;
  final DriverMissionStop pickup;
  final DriverMissionStop dropoff;
  final List<DriverMissionItem> items;
  final String? description;
  final int earnings;
  final int clientFee;
  final String? merchantName;
  final String? merchantType;
  final String? merchantLogoUrl;
  final double? distanceKm;
  final String? createdAt;
  final String? deliveredAt;

  static const activeStatuses = {
    'assigned',
    'en_route_pickup',
    'picked_up',
    'in_delivery',
  };

  bool get isOrder => kind == DriverMissionKind.order;
  bool get isParcel => kind == DriverMissionKind.parcel;
  bool get isActive => activeStatuses.contains(status);
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isPickupPhase => status == 'assigned' || status == 'en_route_pickup';
  bool get isDropoffPhase => status == 'picked_up' || status == 'in_delivery';
  bool get canStartPickup => status == 'assigned';
  bool get canStartDelivery => status == 'picked_up';

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  String? get firstItemImage {
    for (final item in items) {
      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        return item.imageUrl;
      }
    }
    return null;
  }

  String? get imageUrl => merchantLogoUrl ?? firstItemImage;

  String get title {
    if (isParcel) {
      final sender = pickup.contactName ?? pickup.title;
      return sender.trim().isEmpty ? 'Colis' : sender;
    }
    return merchantName?.trim().isNotEmpty == true
        ? merchantName!.trim()
        : 'Commande';
  }

  String get kindLabel {
    if (isParcel) {
      return 'Colis';
    }
    return switch (merchantType) {
      'restaurant' => 'Commande restaurant',
      'maquis' => 'Commande maquis',
      'boutique' => 'Commande boutique',
      _ => 'Commande',
    };
  }

  String get shortKindLabel => isParcel ? 'Colis' : 'Commande';

  String get statusLabel => switch (status) {
    'assigned' => 'Acceptée',
    'en_route_pickup' => 'En route vers la collecte',
    'picked_up' => isParcel ? 'Colis récupéré' : 'Commande récupérée',
    'in_delivery' => 'En route vers le client',
    'delivered' => 'Livrée',
    'cancelled' => 'Annulée',
    _ => status.replaceAll('_', ' '),
  };

  String get actionLabel => switch (status) {
    'assigned' => 'Démarrer la récupération',
    'en_route_pickup' => 'Reprendre la navigation',
    'picked_up' => 'Démarrer la livraison',
    'in_delivery' => 'Continuer la livraison',
    'delivered' => 'Mission terminée',
    _ => 'Voir la mission',
  };

  int get currentStep => switch (status) {
    'assigned' => 0,
    'en_route_pickup' => 1,
    'picked_up' => 2,
    'in_delivery' => 3,
    'delivered' => 4,
    _ => 0,
  };

  DriverMissionStop get currentStop => isPickupPhase ? pickup : dropoff;

  String get phaseTitle =>
      isPickupPhase ? 'Rejoindre le point de collecte' : 'Rejoindre le client';

  DriverMission copyWithStatus(String value) => DriverMission(
    id: id,
    kind: kind,
    reference: reference,
    status: value,
    pickup: pickup,
    dropoff: dropoff,
    items: items,
    description: description,
    earnings: earnings,
    clientFee: clientFee,
    merchantName: merchantName,
    merchantType: merchantType,
    merchantLogoUrl: merchantLogoUrl,
    distanceKm: distanceKm,
    createdAt: createdAt,
    deliveredAt: deliveredAt,
  );

  factory DriverMission.fromDelivery(Delivery delivery) {
    final order = delivery.order;
    final vendor = delivery.vendor;
    final address = order?.addressSnapshot;
    final vendorAddress = [
      vendor?.address?.trim() ?? '',
      vendor?.city?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(', ');

    return DriverMission(
      id: delivery.id,
      kind: DriverMissionKind.order,
      reference: order?.reference?.trim().isNotEmpty == true
          ? order!.reference!
          : 'Commande',
      status: delivery.status,
      pickup: DriverMissionStop(
        title: vendor?.businessName?.trim().isNotEmpty == true
            ? vendor!.businessName!
            : 'Point de collecte',
        address: vendorAddress,
        contactName: vendor?.businessName,
        contactPhone: vendor?.phone,
        point: delivery.pickupPoint,
      ),
      dropoff: DriverMissionStop(
        title: order?.client?.name?.trim().isNotEmpty == true
            ? order!.client!.name!
            : 'Client',
        address: order?.address ?? address?.display ?? '',
        contactName: order?.client?.name,
        contactPhone: order?.client?.phone,
        point: delivery.dropoffPoint,
        note: address?.landmark,
      ),
      items: (order?.items ?? const <DeliveryOrderItem>[])
          .map(
            (item) => DriverMissionItem(
              name: item.name,
              quantity: item.quantity,
              imageUrl: item.imageUrl,
            ),
          )
          .toList(growable: false),
      earnings: delivery.netEarnings,
      clientFee: delivery.fee,
      merchantName: vendor?.businessName,
      merchantType: vendor?.type,
      merchantLogoUrl: vendor?.logoUrl ?? vendor?.coverUrl,
      createdAt: delivery.createdAt,
      deliveredAt: delivery.deliveredAt,
    );
  }

  factory DriverMission.fromParcel(Parcel parcel) {
    final pickup = parcel.pickup;
    final dropoff = parcel.dropoff;
    final sender = parcel.sender;

    return DriverMission(
      id: parcel.id,
      kind: DriverMissionKind.parcel,
      reference: parcel.reference.trim().isNotEmpty
          ? parcel.reference
          : 'Colis',
      status: parcel.status,
      pickup: DriverMissionStop(
        title: pickup?.label?.trim().isNotEmpty == true
            ? pickup!.label!
            : 'Point de collecte',
        address: pickup?.display ?? '',
        contactName: pickup?.contactName?.trim().isNotEmpty == true
            ? pickup!.contactName
            : sender?.name,
        contactPhone: pickup?.contactPhone?.trim().isNotEmpty == true
            ? pickup!.contactPhone
            : sender?.phone,
        point: parcel.pickupPoint,
        note: pickup?.landmark,
      ),
      dropoff: DriverMissionStop(
        title: dropoff?.contactName?.trim().isNotEmpty == true
            ? dropoff!.contactName!
            : 'Destinataire',
        address: dropoff?.display ?? '',
        contactName: dropoff?.contactName,
        contactPhone: dropoff?.contactPhone,
        point: parcel.dropoffPoint,
        note: dropoff?.landmark,
      ),
      description: parcel.description,
      earnings: parcel.partnerAmount,
      clientFee: parcel.deliveryFee,
      merchantName: sender?.name,
      distanceKm: parcel.distanceKm,
      createdAt: parcel.createdAt,
      deliveredAt: parcel.deliveredAt,
    );
  }
}
