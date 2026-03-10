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
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? address;
  final bool isActive;
  final DateTime createdAt;

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        logoUrl: json['logo_url'] as String?,
        address: json['address'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
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
      };
}


