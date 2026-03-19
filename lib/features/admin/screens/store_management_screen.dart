import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/features/admin/providers/admin_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/empty_state_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';

class StoreManagementScreen extends ConsumerWidget {
  const StoreManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(allStoresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý cửa hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allStoresProvider),
          ),
        ],
      ),
      body: storesAsync.when(
        loading: () => const AppLoadingWidget(message: 'Đang tải...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(allStoresProvider),
        ),
        data: (stores) {
          if (stores.isEmpty) {
            return const EmptyStateWidget(
              message: 'Chưa có cửa hàng nào.',
              icon: Icons.store_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allStoresProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: stores.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _StoreAdminCard(store: stores[i]),
            ),
          );
        },
      ),
    );
  }
}

class _StoreAdminCard extends ConsumerWidget {
  const _StoreAdminCard({required this.store});
  final StoreModel store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final toggleState = ref.watch(storeToggleProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: store.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: store.logoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade200,
                      child: Icon(Icons.store_outlined,
                          color: Colors.grey.shade400),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  if (store.address != null)
                    Text(store.address!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: store.isActive
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      store.isActive ? 'Đang hoạt động' : 'Đã tắt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: store.isActive
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: store.isActive,
              activeThumbColor: Colors.green,
              onChanged: toggleState.isLoading
                  ? null
                  : (_) async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(store.isActive
                              ? 'Tắt cửa hàng?'
                              : 'Bật cửa hàng?'),
                          content: Text(store.isActive
                              ? 'Sinh viên sẽ không thể đặt hàng tại "${store.name}".'
                              : 'Cửa hàng "${store.name}" sẽ xuất hiện trở lại cho sinh viên.'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, false),
                              child: const Text('Hủy'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, true),
                              style: store.isActive
                                  ? ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.error)
                                  : null,
                              child: Text(store.isActive
                                  ? 'Tắt'
                                  : 'Bật'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(storeToggleProvider.notifier)
                            .toggle(store.id, store.isActive);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
