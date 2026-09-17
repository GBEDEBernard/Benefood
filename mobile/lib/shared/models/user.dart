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
  bool get hasRoleVendor => roles.any((r) => r.slug == 'vendor');
  bool get hasRoleDriver => roles.any((r) => r.slug == 'driver');
  bool get hasRoleClient => roles.any((r) => r.slug == 'client');

  List<String> get roleSlugs => roles.map((r) => r.slug).toList();

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