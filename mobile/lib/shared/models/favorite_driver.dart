/// Livreur favori d'un client/vendeur, ou demande vue par un livreur.
///
/// Reflet du `FavoriteDriverResource` : statut de la demande (en attente,
/// acceptée, refusée), fiche compacte du livreur et du demandeur.
class FavoriteDriver {
  const FavoriteDriver({
    required this.id,
    this.status = 'pending',
    this.driver,
    this.owner,
    this.requestedAt,
    this.respondedAt,
  });

  final String id;
  final String status;
  final DriverSummary? driver;
  final FavoriteOwner? owner;
  final String? requestedAt;
  final String? respondedAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  factory FavoriteDriver.fromJson(Map<String, dynamic> json) {
    final rawDriver = json['driver'];
    final rawOwner = json['owner'];

    return FavoriteDriver(
      id: _s(json['id']),
      status: _s(json['status'], 'pending'),
      driver: rawDriver is Map<String, dynamic> ? DriverSummary.fromJson(rawDriver) : null,
      owner: rawOwner is Map<String, dynamic> ? FavoriteOwner.fromJson(rawOwner) : null,
      requestedAt: _nullable(json['requested_at']),
      respondedAt: _nullable(json['responded_at']),
    );
  }
}

/// Fiche compacte d'un livreur (favoris, candidats, sélecteur).
class DriverSummary {
  const DriverSummary({
    required this.id,
    this.userId,
    this.name,
    this.phone,
    this.vehicle,
    this.rating,
    this.status,
  });

  final String id;
  final String? userId;
  final String? name;
  final String? phone;
  final String? vehicle;
  final double? rating;
  final String? status;

  String get displayName {
    final value = name?.trim();
    return value == null || value.isEmpty ? 'Livreur' : value;
  }

  factory DriverSummary.fromJson(Map<String, dynamic> json) => DriverSummary(
        id: _s(json['id']),
        userId: _nullable(json['user_id']),
        name: _nullable(json['name']),
        phone: _nullable(json['phone']),
        vehicle: _nullable(json['vehicle']),
        rating: _d(json['rating']),
        status: _nullable(json['status']),
      );
}

/// Demandeur d'un livreur favori (client ou boutique).
class FavoriteOwner {
  const FavoriteOwner({required this.id, this.name, this.phone, this.role});

  final String id;
  final String? name;
  final String? phone;
  final String? role;

  String get displayName {
    final value = name?.trim();
    return value == null || value.isEmpty ? 'Client' : value;
  }

  String get displayRole => switch (role) {
        'vendor' => 'Boutique',
        'client' => 'Client',
        _ => 'Client',
      };

  factory FavoriteOwner.fromJson(Map<String, dynamic> json) => FavoriteOwner(
        id: _s(json['id']),
        name: _nullable(json['name']),
        phone: _nullable(json['phone']),
        role: _nullable(json['role']),
      );
}

String _s(dynamic value, [String fallback = '']) => value is String ? value : fallback;

String? _nullable(dynamic value) => value is String ? value : null;

double? _d(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
