/// Rôle dans l'application (client/vendeur/livreur).
class UserRole {
  const UserRole({required this.slug, required this.name, this.isActive = false});

  final String slug;
  final String name;
  final bool isActive;

  factory UserRole.fromJson(Map<String, dynamic> json) => UserRole(
        slug: _string(json['slug']),
        name: _string(json['name']),
        isActive: _bool(json['is_active']),
      );
}

/// Contexte d'utilisation de l'application.
///
/// Le backend distingue plusieurs slugs de livreur (`driver-independent`,
/// `driver-beninfood`) ; l'app les regroupe dans un contexte unique.
class AppContext {
  const AppContext._();

  static const String client = 'client';
  static const String vendor = 'vendor';
  static const String driver = 'driver';

  static const List<String> driverSlugs = ['driver', 'driver-independent', 'driver-beninfood'];

  /// Slug envoyé à `POST /auth/register` pour demander l'espace livreur.
  /// L'API n'accepte que `client`, `vendor` et `driver-independent`.
  static const String driverRegistrationSlug = 'driver-independent';

  /// Contexte correspondant à un slug de rôle backend (null si inconnu).
  static String? fromSlug(String slug) {
    if (slug == client || slug == vendor) {
      return slug;
    }
    if (driverSlugs.contains(slug)) {
      return driver;
    }
    return null;
  }
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.status = 'active',
    this.locale = 'fr',
    this.phoneVerifiedAt,
    this.createdAt,
    this.roles = const [],
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String status;
  final String locale;
  final String? phoneVerifiedAt;
  final String? createdAt;
  final List<UserRole> roles;

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';
  bool get hasRoleVendor => roles.any((r) => r.slug == AppContext.vendor);
  bool get hasRoleDriver => roles.any((r) => AppContext.driverSlugs.contains(r.slug));
  bool get hasRoleClient => roles.any((r) => r.slug == AppContext.client);

  /// Contexte `client` / `vendor` / `driver` accessibles par cet utilisateur.
  Set<String> get contexts => roles
      .map((r) => AppContext.fromSlug(r.slug))
      .whereType<String>()
      .toSet();

  List<String> get roleSlugs => roles.map((r) => r.slug).toList();

  /// Slug réel du rôle correspondant à un contexte (pour l'API `/me/active-role`).
  String? slugForContext(String context) {
    for (final role in roles) {
      if (AppContext.fromSlug(role.slug) == context) {
        return role.slug;
      }
    }
    return null;
  }

  factory User.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('User JSON null');
    }
    final rawRoles = json['roles'];
    List<UserRole> roles = [];
    if (rawRoles is List) {
      roles = rawRoles
          .whereType<Map<String, dynamic>>()
          .map(UserRole.fromJson)
          .toList();
    }

    return User(
      id: _string(json['id']),
      name: _string(json['name']),
      phone: _string(json['phone']),
      email: _nullableString(json['email']),
      status: _string(json['status'], 'active'),
      locale: _string(json['locale'], 'fr'),
      phoneVerifiedAt: _nullableString(json['phone_verified_at']),
      createdAt: _nullableString(json['created_at']),
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'status': status,
        'locale': locale,
        'roles': roles
            .map((r) => {'slug': r.slug, 'name': r.name, 'is_active': r.isActive})
            .toList(),
      };

  User copyWith({String? email, String? name}) => User(
        id: id,
        name: name ?? this.name,
        phone: phone,
        email: email,
        status: status,
        locale: locale,
        phoneVerifiedAt: phoneVerifiedAt,
        createdAt: createdAt,
        roles: roles,
      );
}

String _string(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

String? _nullableString(dynamic value) => value is String ? value : null;

bool _bool(dynamic value) => value == true || value == 1 || value == '1';