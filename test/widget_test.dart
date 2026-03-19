import 'package:flutter_test/flutter_test.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';

void main() {
  test('placeholder test', () {
    expect(1 + 1, equals(2));
  });

  test('multi-store cart keeps selected store', () {
    final cart = CartNotifier();

    const s1 = 'store-1';
    const s2 = 'store-2';

    final itemA = MenuItemModel(
      id: 'item-A',
      storeId: s1,
      name: 'A',
      price: 100,
      isAvailable: true,
      createdAt: DateTime(2026, 1, 1),
    );
    final itemB = MenuItemModel(
      id: 'item-B',
      storeId: s2,
      name: 'B',
      price: 200,
      isAvailable: true,
      createdAt: DateTime(2026, 1, 1),
    );

    cart.addItem(itemA, s1);
    expect(cart.state.selectedStoreId, equals(s1));
    expect(cart.state.selectedTotalAmount, equals(100));
    expect(cart.state.containsStore(s2), isFalse);

    // Add item from another store -> keep selected store s1
    cart.addItem(itemB, s2);
    expect(cart.state.selectedStoreId, equals(s1));
    expect(cart.state.containsStore(s1), isTrue);
    expect(cart.state.containsStore(s2), isTrue);
    expect(cart.state.selectedItems, hasLength(1));
    expect(cart.state.selectedItems.single.menuItem.id, equals('item-A'));
  });

  test('selectedStoreId is cleared when its items are removed', () {
    final cart = CartNotifier();

    const s1 = 'store-1';
    const s2 = 'store-2';

    final itemA = MenuItemModel(
      id: 'item-A',
      storeId: s1,
      name: 'A',
      price: 100,
      isAvailable: true,
      createdAt: DateTime(2026, 1, 1),
    );
    final itemB = MenuItemModel(
      id: 'item-B',
      storeId: s2,
      name: 'B',
      price: 200,
      isAvailable: true,
      createdAt: DateTime(2026, 1, 1),
    );

    // Cart has items from both stores.
    cart.addItem(itemA, s1);
    cart.addItem(itemB, s2);
    // Select s2 for checkout.
    cart.selectStore(s2);
    expect(cart.state.selectedStoreId, equals(s2));
    expect(cart.state.selectedItems.single.menuItem.id, equals('item-B'));

    // Remove last item from s2 -> selection cleared.
    cart.removeItem(itemB.id);
    expect(cart.state.selectedStoreId, isNull);
    expect(cart.state.selectedItems, isEmpty);
    // s1 items remain.
    expect(cart.state.containsStore(s1), isTrue);
    expect(cart.state.containsStore(s2), isFalse);
  });
}
