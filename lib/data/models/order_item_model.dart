class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.quantity,
    required this.unitPrice,
    this.menuItemName,
    this.menuItemStoreId,
  });

  final String id;
  final String orderId;
  final String menuItemId;
  final int quantity;
  final int unitPrice;
  final String? menuItemName; // populated from join
  final String? menuItemStoreId; // populated from join when needed

  int get subtotal => unitPrice * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // menu_items join: {name: ...}
    final menuItem = json['menu_items'] as Map<String, dynamic>?;
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      menuItemId: json['menu_item_id'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toInt(),
      menuItemName: menuItem?['name'] as String?,
      menuItemStoreId: menuItem?['store_id'] as String?,
    );
  }
}


