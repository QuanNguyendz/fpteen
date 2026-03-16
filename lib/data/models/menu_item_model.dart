class MenuItemModel {
  const MenuItemModel({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    required this.createdAt,
    this.avgRating,
    this.ratingCount,
  });

  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? description;
  final int price; // VNĐ integer
  final String? imageUrl;
  final bool isAvailable;
  final DateTime createdAt;
  final double? avgRating;
  final int? ratingCount;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        categoryId: json['category_id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: (json['price'] as num).toInt(),
        imageUrl: json['image_url'] as String?,
        isAvailable: json['is_available'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        ratingCount: (json['rating_count'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'category_id': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'image_url': imageUrl,
        'is_available': isAvailable,
        'created_at': createdAt.toIso8601String(),
        'avg_rating': avgRating,
        'rating_count': ratingCount,
      };

  MenuItemModel copyWith({
    String? name,
    String? description,
    int? price,
    String? imageUrl,
    bool? isAvailable,
    String? categoryId,
    double? avgRating,
    int? ratingCount,
  }) =>
      MenuItemModel(
        id: id,
        storeId: storeId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        imageUrl: imageUrl ?? this.imageUrl,
        isAvailable: isAvailable ?? this.isAvailable,
        createdAt: createdAt,
        avgRating: avgRating ?? this.avgRating,
        ratingCount: ratingCount ?? this.ratingCount,
      );
}


