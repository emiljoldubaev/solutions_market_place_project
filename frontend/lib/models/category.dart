class Category {
  final int id;
  final String name;
  final String nameRu;
  final String slug;
  final bool isActive;
  final int displayOrder;

  const Category({
    required this.id,
    required this.name,
    required this.nameRu,
    required this.slug,
    required this.isActive,
    required this.displayOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'] ?? '',
      nameRu: json['name_ru'] ?? json['name'] ?? '',
      slug: json['slug'] ?? '',
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
    );
  }
}
