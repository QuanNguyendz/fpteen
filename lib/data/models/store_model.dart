class StoreModel {
  const StoreModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.logoUrl,
    this.address,
    required this.isActive,
    required this.createdAt,
    this.avgRating,
    this.ratingCount,
    this.slotSizeMinutes,
    this.maxOrdersPerSlot,
    this.openingTime,
    this.closingTime,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? address;
  final bool isActive;
  final DateTime createdAt;
  final double? avgRating;
  final int? ratingCount;
  final int? slotSizeMinutes;
  final int? maxOrdersPerSlot;
  // Stored in DB as TIME (e.g. "10:00:00") and parsed as string here.
  final String? openingTime;
  final String? closingTime;

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        logoUrl: json['logo_url'] as String?,
        address: json['address'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        ratingCount: (json['rating_count'] as num?)?.toInt(),
        slotSizeMinutes: (json['slot_size_minutes'] as num?)?.toInt(),
        maxOrdersPerSlot: (json['max_orders_per_slot'] as num?)?.toInt(),
        openingTime: json['opening_time'] as String?,
        closingTime: json['closing_time'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'description': description,
        'logo_url': logoUrl,
        'address': address,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'slot_size_minutes': slotSizeMinutes,
        'max_orders_per_slot': maxOrdersPerSlot,
        'opening_time': openingTime,
        'closing_time': closingTime,
      };
}


