import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/data/models/order_item_model.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.storeId,
    required this.customerId,
    required this.status,
    required this.totalAmount,
    this.paymentMethod,
    this.paymentRef,
    this.note,
    required this.createdAt,
    this.items = const [],
    this.storeName,
    this.customerName,
  });

  final String id;
  final String storeId;
  final String customerId;
  final String status;
  final int totalAmount;
  final String? paymentMethod;
  final String? paymentRef;
  final String? note;
  final DateTime createdAt;
  final List<OrderItemModel> items;
  final String? storeName; // populated from join
  final String? customerName; // populated from join

  bool get isPending => status == AppConstants.statusPending;
  bool get isPaid => status == AppConstants.statusPaid;
  bool get isConfirmed => status == AppConstants.statusConfirmed;
  bool get isCancelled => status == AppConstants.statusCancelled;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['order_items'] as List<dynamic>? ?? [];
    final storeJson = json['stores'] as Map<String, dynamic>?;
    final customerJson = json['users'] as Map<String, dynamic>?;

    return OrderModel(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      customerId: json['customer_id'] as String,
      status: json['status'] as String,
      totalAmount: (json['total_amount'] as num).toInt(),
      paymentMethod: json['payment_method'] as String?,
      paymentRef: json['payment_ref'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: itemsJson
          .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      storeName: storeJson?['name'] as String?,
      customerName: customerJson?['full_name'] as String?,
    );
  }

  OrderModel copyWith({String? status}) => OrderModel(
        id: id,
        storeId: storeId,
        customerId: customerId,
        status: status ?? this.status,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        paymentRef: paymentRef,
        note: note,
        createdAt: createdAt,
        items: items,
        storeName: storeName,
        customerName: customerName,
      );
}


