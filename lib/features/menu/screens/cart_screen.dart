import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';
import 'package:fpteen/shared/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

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
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (ctx, i) {
                final item = cart.items[i];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.menuItem.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            _vndFormat.format(item.menuItem.price),
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: theme.colorScheme.primary,
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .removeItem(item.menuItem.id),
                        ),
                        Text('${item.quantity}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: theme.colorScheme.primary,
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .addItem(item.menuItem, cart.storeId!),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        _vndFormat.format(item.subtotal),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              },
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
                          _vndFormat.format(cart.totalAmount),
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
                      onPressed: () => context.push('/home/checkout'),
                      child: const Text('Tiến hành đặt hàng'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}


