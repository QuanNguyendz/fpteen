import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:fpteen/features/home/providers/stores_provider.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/empty_state_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final storesAsync = ref.watch(activeStoresProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('FPTeen'),
        actions: [
          // Cart
          if (!cart.isEmpty)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'Giỏ hàng',
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'Hiển thị dạng danh sách' : 'Hiển thị dạng lưới',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Lịch sử đơn hàng',
            onPressed: () => context.push('/home/orders'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, ${user?.fullName ?? 'bạn'} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chọn cửa hàng và đặt món ngay!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Cửa hàng có mặt',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: storesAsync.when(
              loading: () => const AppLoadingWidget(message: 'Đang tải...'),
              error: (e, _) => AppErrorWidget(
                message: e.toString(),
                onRetry: () => ref.read(activeStoresProvider.notifier).refresh(),
              ),
              data: (stores) {
                if (stores.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'Chưa có cửa hàng nào hoạt động.',
                    icon: Icons.store_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(activeStoresProvider.notifier).refresh(),
                  child: _isGridView
                      ? GridView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: stores.length,
                          itemBuilder: (ctx, i) =>
                              _StoreGridCard(store: stores[i]),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: stores.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) =>
                              _StoreCard(store: stores[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    final avgRating = store.avgRating ?? 0;
    final ratingCount = store.ratingCount ?? 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/home/store/${store.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: store.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: store.logoUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _PlaceholderImage(),
                      errorWidget: (_, _, _) => _PlaceholderImage(),
                    )
                  : _PlaceholderImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (ratingCount > 0) ...[
                              const SizedBox(height: 4),
                              _StoreRating(avgRating: avgRating, ratingCount: ratingCount),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Báo cáo cửa hàng',
                        onPressed: () {
                          context.push(
                            '/home/report/${store.id}',
                            extra: {'storeName': store.name},
                          );
                        },
                        icon: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (store.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      store.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                  if (store.address != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          store.address!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreGridCard extends StatelessWidget {
  const _StoreGridCard({required this.store});
  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    final avgRating = store.avgRating ?? 0;
    final ratingCount = store.ratingCount ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/home/store/${store.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: store.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: store.logoUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : _PlaceholderImage(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            store.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (ratingCount > 0) ...[
            const SizedBox(height: 4),
            _StoreRating(
              avgRating: avgRating,
              ratingCount: ratingCount,
              compact: true,
            ),
          ],
          if (store.address != null)
            Text(
              store.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Icon(Icons.restaurant, size: 48, color: Colors.grey.shade400),
    );
  }
}

class _StoreRating extends StatelessWidget {
  const _StoreRating({
    required this.avgRating,
    required this.ratingCount,
    this.compact = false,
  });

  final double avgRating;
  final int ratingCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final starColor = Colors.amber.shade700;
    final textColor = Colors.grey.shade700;
    final fontSize = compact ? 11.0 : 12.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: compact ? 14 : 15, color: starColor),
        const SizedBox(width: 4),
        Text(
          '${avgRating.toStringAsFixed(1)} ($ratingCount)',
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}


