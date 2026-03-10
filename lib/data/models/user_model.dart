import 'package:fpteen/core/constants/app_constants.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? phone;
  final DateTime createdAt;

  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isStoreOwner => role == AppConstants.roleStoreOwner;
  bool get isCustomer => role == AppConstants.roleCustomer;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String? ?? '',
        role: json['role'] as String? ?? AppConstants.roleCustomer,
        phone: json['phone'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'phone': phone,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? fullName,
    String? phone,
  }) =>
      UserModel(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        role: role,
        phone: phone ?? this.phone,
        createdAt: createdAt,
      );
}


