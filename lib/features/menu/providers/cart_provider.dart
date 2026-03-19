import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/cart_item_model.dart';
import 'package:fpteen/data/models/menu_item_model.dart';

class CartState {
  const CartState({
    this.selectedStoreId,
    this.items = const [],
  });

  final String? selectedStoreId;
  final List<CartItemModel> items;

  int get totalAmount =>
      items.fold(0, (sum, item) => sum + item.subtotal);

  int get totalAmountForAllStores => totalAmount;

  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity);

  List<String> get storeIds =>
      items.map((i) => i.menuItem.storeId).toSet().toList();

  bool get isEmpty => items.isEmpty;

  int quantityOf(String menuItemId) =>
      items
          .where((i) => i.menuItem.id == menuItemId)
          .fold(0, (_, i) => i.quantity);

  bool containsStore(String storeId) => storeIds.contains(storeId);

  List<CartItemModel> itemsForStore(String storeId) =>
      items.where((i) => i.menuItem.storeId == storeId).toList();

  int totalAmountForStore(String storeId) =>
      itemsForStore(storeId).fold(0, (sum, item) => sum + item.subtotal);

  int totalQuantityForStore(String storeId) =>
      itemsForStore(storeId).fold(0, (sum, item) => sum + item.quantity);

  List<CartItemModel> get selectedItems => selectedStoreId == null
      ? const []
      : itemsForStore(selectedStoreId!);

  int get selectedTotalAmount =>
      selectedStoreId == null ? 0 : totalAmountForStore(selectedStoreId!);

  int get selectedTotalQuantity => selectedStoreId == null
      ? 0
      : totalQuantityForStore(selectedStoreId!);

  CartState copyWith({
    String? selectedStoreId,
    bool clearSelectedStoreId = false,
    List<CartItemModel>? items,
  }) =>
      CartState(
        selectedStoreId: clearSelectedStoreId
            ? null
            : (selectedStoreId ?? this.selectedStoreId),
        items: items ?? this.items,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void selectStore(String storeId) {
    if (!state.containsStore(storeId)) return;
    state = state.copyWith(selectedStoreId: storeId);
  }

  void addItem(MenuItemModel menuItem, String storeId) {
    final existing = state.items.indexWhere((i) => i.menuItem.id == menuItem.id);
    if (existing >= 0) {
      final updated = List<CartItemModel>.from(state.items);
      updated[existing] =
          updated[existing].copyWith(quantity: updated[existing].quantity + 1);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        selectedStoreId:
            state.selectedStoreId ?? storeId, // keep_selected
        items: [...state.items, CartItemModel(menuItem: menuItem, quantity: 1)],
      );
    }

    // If cart has items already and selectedStoreId is null, set it.
    if (state.selectedStoreId == null) {
      state = state.copyWith(selectedStoreId: storeId);
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

    final newSelected = state.selectedStoreId == null
        ? null
        : updated.any((i) => i.menuItem.storeId == state.selectedStoreId)
            ? state.selectedStoreId
            : null;

    state = state.copyWith(
      items: updated,
      clearSelectedStoreId: newSelected == null,
      selectedStoreId: newSelected,
    );
  }

  void deleteItem(String menuItemId) {
    final updated =
        state.items.where((i) => i.menuItem.id != menuItemId).toList();

    final newSelected = state.selectedStoreId == null
        ? null
        : updated.any((i) => i.menuItem.storeId == state.selectedStoreId)
            ? state.selectedStoreId
            : null;

    state = state.copyWith(
      items: updated,
      clearSelectedStoreId: newSelected == null,
      selectedStoreId: newSelected,
    );
  }

  void clear() => state = const CartState(selectedStoreId: null);

}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());


