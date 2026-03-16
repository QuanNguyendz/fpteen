import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/features/home/providers/stores_provider.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';
import 'package:fpteen/features/menu/providers/menu_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

final _storeProvider = FutureProvider.family.autoDispose<StoreModel, String>(
    (ref, storeId) {
  return ref.watch(storeRepositoryProvider).fetchStore(storeId);
});

class StoreMenuScreen extends ConsumerWidget {
  const StoreMenuScreen({super.key, required this.storeId});
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(storeMenuProvider(storeId));
    final cart = ref.watch(cartProvider);
    final storeAsync = ref.watch(_storeProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.report_outlined),
            tooltip: 'Báo cáo canteen',
            onPressed: () {
              final storeName = storeAsync.valueOrNull?.name ?? 'Canteen';
              context.push(
                '/home/report/$storeId',
                extra: {'storeName': storeName},
              );
            },
          ),
          if (!cart.isEmpty)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => context.push('/home/cart'),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.totalQuantity}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: menuAsync.when(
        loading: () => const AppLoadingWidget(message: 'Đang tải menu...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(storeMenuProvider(storeId)),
        ),
        data: (menuData) {
          final allCategories = [
            ...menuData.categories,
          ];
          return CustomScrollView(
            slivers: [
              // Category chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      for (final cat in allCategories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(cat.name),
                            onPressed: () {},
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Items grouped by category
              for (final cat in allCategories)
                ..._buildCategorySliver(
                    context, ref, cat.name, menuData.itemsByCategory(cat.id),
                    storeId),
              // Uncategorized
              if (menuData.uncategorized.isNotEmpty)
                ..._buildCategorySliver(context, ref, 'Khác',
                    menuData.uncategorized, storeId),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
      bottomNavigationBar: cart.storeId == storeId && !cart.isEmpty
          ? _CartBar(cart: cart)
          : null,
    );
  }

  List<Widget> _buildCategorySliver(BuildContext context, WidgetRef ref,
      String catName, List<MenuItemModel> items, String storeId) {
    if (items.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            catName,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _MenuItemTile(item: items[i], storeId: storeId),
          childCount: items.length,
        ),
      ),
    ];
  }
}

class _MenuItemTile extends ConsumerWidget {
  const _MenuItemTile({required this.item, required this.storeId});
  final MenuItemModel item;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) => c.quantityOf(item.id)));
    final theme = Theme.of(context);

    return Opacity(
      opacity: item.isAvailable ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade200,
                      child: Icon(Icons.fastfood_outlined,
                          color: Colors.grey.shade400),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  if ((item.ratingCount ?? 0) > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.star,
                            size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${(item.avgRating ?? 0).toStringAsFixed(1)} (${item.ratingCount})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.description != null)
                    Text(item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(
                    _vndFormat.format(item.price),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            if (item.isAvailable) _QuantityControl(item: item, qty: qty, storeId: storeId)
            else Text('Hết hàng',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _QuantityControl extends ConsumerWidget {
  const _QuantityControl(
      {required this.item, required this.qty, required this.storeId});
  final MenuItemModel item;
  final int qty;
  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    final color = Theme.of(context).colorScheme.primary;

    if (qty == 0) {
      return GestureDetector(
        onTap: () => cart.addItem(item, storeId),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => cart.removeItem(item.id),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: color),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.remove, color: color, size: 18),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        GestureDetector(
          onTap: () => cart.addItem(item, storeId),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => context.push('/home/cart'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${cart.totalQuantity} món',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const Text('Xem giỏ hàng',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(
                _vndFormat.format(cart.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


