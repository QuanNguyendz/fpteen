import 'package:fpteen/data/models/menu_item_model.dart';

class CartItemModel {
  const CartItemModel({
    required this.menuItem,
    required this.quantity,
  });

  final MenuItemModel menuItem;
  final int quantity;

  int get subtotal => menuItem.price * quantity;

  CartItemModel copyWith({int? quantity}) => CartItemModel(
        menuItem: menuItem,
        quantity: quantity ?? this.quantity,
      );
}


