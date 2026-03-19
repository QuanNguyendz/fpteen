import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';
import 'package:fpteen/shared/widgets/empty_state_widget.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/features/home/providers/stores_provider.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

final _storeNameProvider = FutureProvider.family.autoDispose<String, String>(
  (ref, storeId) async {
    final repo = ref.watch(storeRepositoryProvider);
    final StoreModel store = await repo.fetchStore(storeId);
    return store.name;
  },
);

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final selectedStoreId = cart.selectedStoreId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              child: Text('Xóa tất cả',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const EmptyStateWidget(
              message: 'Giỏ hàng trống.\nHãy thêm món ăn vào!',
              icon: Icons.shopping_cart_outlined,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final storeId in cart.storeIds) ...[
                    _CartStoreGroup(
                      storeId: storeId,
                      isSelected: selectedStoreId == storeId,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng cộng',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(
                          _vndFormat.format(cart.selectedTotalAmount),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: selectedStoreId == null
                          ? null
                          : () => context.push('/home/checkout'),
                      child: const Text('Tiến hành đặt hàng'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CartStoreGroup extends ConsumerWidget {
  const _CartStoreGroup({
    required this.storeId,
    required this.isSelected,
  });

  final String storeId;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final storeNameAsync = ref.watch(_storeNameProvider(storeId));
    final storeTotalAmount = cart.totalAmountForStore(storeId);
    final storeTotalQty = cart.totalQuantityForStore(storeId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Radio<String>(
                  value: storeId,
                  // ignore: deprecated_member_use
                  groupValue: cart.selectedStoreId,
                  // ignore: deprecated_member_use
                  onChanged: (_) {
                    ref.read(cartProvider.notifier).selectStore(storeId);
                  },
                ),
                Expanded(
                  child: storeNameAsync.when(
                    loading: () => Text('Cửa hàng...',
                        style: Theme.of(context).textTheme.titleSmall),
                    error: (_, _) => Text('Cửa hàng',
                        style: Theme.of(context).textTheme.titleSmall),
                    data: (name) => Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Text(
                  'x$storeTotalQty',
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (cart.itemsForStore(storeId).isEmpty)
              const SizedBox.shrink()
            else
              Column(
                children: cart.itemsForStore(storeId).map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.menuItem.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _vndFormat.format(item.menuItem.price),
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected) ...[
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color:
                                    Theme.of(context).colorScheme.primary,
                                onPressed: () {
                                  ref
                                      .read(cartProvider.notifier)
                                      .removeItem(item.menuItem.id);
                                },
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color:
                                    Theme.of(context).colorScheme.primary,
                                onPressed: () {
                                  ref.read(cartProvider.notifier).addItem(
                                        item.menuItem,
                                        storeId,
                                      );
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          // Nhóm không được chọn: grey + disable +/- theo yêu cầu.
                          Row(
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.remove_circle_outline),
                                color: Colors.grey.shade400,
                                onPressed: null,
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ).copyWith(color: Colors.grey),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.grey.shade400,
                                onPressed: null,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 90,
                          child: Text(
                            _vndFormat.format(item.subtotal),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _vndFormat.format(storeTotalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


