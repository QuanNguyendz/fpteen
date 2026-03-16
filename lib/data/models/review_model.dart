class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.menuItemId,
    required this.storeId,
    required this.reviewerId,
    required this.rating,
    this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String menuItemId;
  final String storeId;
  final String reviewerId;
  final int rating;
  final String? content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id: json['id'] as String,
        menuItemId: json['menu_item_id'] as String,
        storeId: json['store_id'] as String,
        reviewerId: json['reviewer_id'] as String,
        rating: (json['rating'] as num).toInt(),
        content: json['content'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

