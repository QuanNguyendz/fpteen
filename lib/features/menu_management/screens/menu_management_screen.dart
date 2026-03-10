import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/features/menu_management/providers/menu_management_provider.dart';
import 'package:fpteen/shared/widgets/empty_state_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

class MenuManagementScreen extends ConsumerWidget {
  const MenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(menuManagementProvider);
    final theme = Theme.of(context);

    ref.listen(menuManagementProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(menuManagementProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.isLoading
          ? const AppLoadingWidget(message: 'Đang tải...')
          : state.items.isEmpty
              ? EmptyStateWidget(
                  message: 'Chưa có món ăn nào.\nThêm món đầu tiên!',
                  icon: Icons.fastfood_outlined,
                  actionLabel: 'Thêm món',
                  onAction: () => context.push('/canteen/menu/add'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) =>
                      _MenuItemTile(item: state.items[i]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/canteen/menu/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MenuItemTile extends ConsumerWidget {
  const _MenuItemTile({required this.item});
  final MenuItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mgmt = ref.read(menuManagementProvider.notifier);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: item.imageUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              )
            : Container(
                width: 56,
                height: 56,
                color: Colors.grey.shade200,
                child: Icon(Icons.fastfood_outlined,
                    color: Colors.grey.shade400),
              ),
      ),
      title: Text(item.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_vndFormat.format(item.price)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Available toggle
          Switch(
            value: item.isAvailable,
            activeThumbColor: theme.colorScheme.primary,
            onChanged: (_) => mgmt.toggleAvailability(item),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                context.push('/canteen/menu/edit', extra: item);
              } else if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xóa món ăn?'),
                    content:
                        Text('Xác nhận xóa "${item.name}" khỏi menu?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Xóa',
                            style: TextStyle(
                                color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await mgmt.deleteItem(item.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Sửa'),
                  ])),
              PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18,
                        color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text('Xóa',
                        style:
                            TextStyle(color: theme.colorScheme.error)),
                  ])),
            ],
          ),
        ],
      ),
    );
  }
}


