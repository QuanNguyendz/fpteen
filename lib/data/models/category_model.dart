class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.displayOrder,
  });

  final String id;
  final String storeId;
  final String name;
  final int displayOrder;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        name: json['name'] as String,
        displayOrder: json['display_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'name': name,
        'display_order': displayOrder,
      };
}


