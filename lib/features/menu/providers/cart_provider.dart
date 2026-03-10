import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/cart_item_model.dart';
import 'package:fpteen/data/models/menu_item_model.dart';

class CartState {
  const CartState({
    this.storeId,
    this.items = const [],
  });

  final String? storeId;
  final List<CartItemModel> items;

  int get totalAmount =>
      items.fold(0, (sum, item) => sum + item.subtotal);

  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;

  int quantityOf(String menuItemId) =>
      items
          .where((i) => i.menuItem.id == menuItemId)
          .fold(0, (_, i) => i.quantity);

  CartState copyWith({
    String? storeId,
    List<CartItemModel>? items,
  }) =>
      CartState(
        storeId: storeId ?? this.storeId,
        items: items ?? this.items,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem(MenuItemModel menuItem, String storeId) {
    // If adding from a different store, clear cart first
    if (state.storeId != null && state.storeId != storeId) {
      state = const CartState();
    }

    final existing = state.items.indexWhere((i) => i.menuItem.id == menuItem.id);
    if (existing >= 0) {
      final updated = List<CartItemModel>.from(state.items);
      updated[existing] =
          updated[existing].copyWith(quantity: updated[existing].quantity + 1);
      state = state.copyWith(storeId: storeId, items: updated);
    } else {
      state = state.copyWith(
        storeId: storeId,
        items: [...state.items, CartItemModel(menuItem: menuItem, quantity: 1)],
      );
    }
  }

  void removeItem(String menuItemId) {
    final existing =
        state.items.indexWhere((i) => i.menuItem.id == menuItemId);
    if (existing < 0) return;

    final updated = List<CartItemModel>.from(state.items);
    if (updated[existing].quantity > 1) {
      updated[existing] =
          updated[existing].copyWith(quantity: updated[existing].quantity - 1);
    } else {
      updated.removeAt(existing);
    }
    state = state.copyWith(
      items: updated,
      storeId: updated.isEmpty ? null : state.storeId,
    );
  }

  void deleteItem(String menuItemId) {
    final updated =
        state.items.where((i) => i.menuItem.id != menuItemId).toList();
    state = state.copyWith(
        items: updated, storeId: updated.isEmpty ? null : state.storeId);
  }

  void clear() => state = const CartState();

}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());


