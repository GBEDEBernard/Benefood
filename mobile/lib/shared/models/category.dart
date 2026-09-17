class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.iconPath,
    this.isActive = true,
    this.productsCount,
    this.children = const [],
  });

  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String? iconPath;
  final bool isActive;
  final int? productsCount;
  final List<Category> children;

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    List<Category> children = [];
    if (rawChildren is List) {
      children = rawChildren
          .whereType<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList();
    }

    return Category(
      id: _s(json['id']),
      parentId: json['parent_id'] is String ? json['parent_id'] as String : null,
      name: _s(json['name']),
      slug: _s(json['slug']),
      iconPath: json['icon_path'] is String ? json['icon_path'] as String : null,
      isActive: json['is_active'] == true,
      productsCount: json['products_count'] is int ? json['products_count'] as int : null,
      children: children,
    );
  }
}

String _s(dynamic value) => value is String ? value : '';