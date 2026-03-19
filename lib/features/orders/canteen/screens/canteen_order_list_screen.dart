import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:fpteen/features/home/providers/stores_provider.dart';
import 'package:fpteen/features/orders/canteen/providers/canteen_orders_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/empty_state_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
final _timeFormat = DateFormat('HH:mm');

class CanteenOrderListScreen extends ConsumerWidget {
  const CanteenOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(myStoreProvider);
    final ordersState = ref.watch(canteenOrdersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: storeAsync.when(
          data: (s) => Text(s?.name ?? 'Cửa hàng'),
          loading: () => const Text('Cửa hàng'),
          error: (_, _) => const Text('Cửa hàng'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Phân tích cửa hàng',
            onPressed: () => context.push('/canteen/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu_outlined),
            tooltip: 'Quản lý menu',
            onPressed: () => context.push('/canteen/menu'),
          ),
          IconButton(
            icon: const Icon(Icons.store_outlined),
            tooltip: 'Thông tin cửa hàng',
            onPressed: () => context.push('/canteen/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Đăng xuất',
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          ordersState.when(
            data: (orders) {
              final paid = orders.where((o) => o.isPaid).length;
              final confirmed = orders.where((o) => o.isConfirmed).length;
              return Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _SummaryChip(
                        label: 'Tổng hôm nay', count: orders.length, color: Colors.grey),
                    const SizedBox(width: 12),
                    _SummaryChip(
                        label: 'Chờ lấy', count: paid, color: Colors.orange),
                    const SizedBox(width: 12),
                    _SummaryChip(
                        label: 'Đã xong', count: confirmed, color: Colors.green),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: ordersState.when(
              loading: () =>
                  const AppLoadingWidget(message: 'Đang tải đơn hàng...'),
              error: (e, _) => AppErrorWidget(
                message: e.toString(),
                onRetry: () =>
                    ref.read(canteenOrdersProvider.notifier).refresh(),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'Chưa có đơn hàng hôm nay.',
                    icon: Icons.receipt_long_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(canteenOrdersProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) =>
                        _CanteenOrderCard(order: orders[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/canteen/scan'),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Quét QR'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 20, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _CanteenOrderCard extends ConsumerWidget {
  const _CanteenOrderCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isConfirmed = order.isConfirmed;
    final isCancelled = order.isCancelled;
    final canManualConfirm = order.isPaid && !isConfirmed;
    final canCancel = isConfirmed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Checkbox-style indicator
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: canManualConfirm
                      ? () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xác nhận đã giao món?'),
                              content: const Text(
                                'Bạn có chắc khách đã nhận món và muốn xác nhận đơn này?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Xác nhận'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;

                          try {
                            final supabase = ref.read(supabaseClientProvider);
                            final response = await supabase.functions.invoke(
                              'confirm-order',
                              body: {'order_id': order.id},
                            );

                            if (response.status == 200) {
                              ref
                                  .read(canteenOrdersProvider.notifier)
                                  .markConfirmed(order.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã xác nhận đơn hàng.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              final errorMsg = response.data?['error'] ??
                                  response.data?['current_status'] ??
                                  'Lỗi xác nhận đơn hàng';
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMsg.toString()),
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              }
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Không thể kết nối. Kiểm tra mạng và thử lại.'),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isConfirmed ? Colors.green : Colors.transparent,
                      border: Border.all(
                        color: isConfirmed
                            ? Colors.green
                            : isCancelled
                                ? theme.colorScheme.error
                                : canManualConfirm
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isConfirmed
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : isCancelled
                            ? Icon(Icons.close,
                                color: theme.colorScheme.error, size: 16)
                            : canManualConfirm
                                ? Icon(Icons.check,
                                    color: theme.colorScheme.primary, size: 16)
                                : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.customerName ?? 'Khách hàng',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      decoration: (isConfirmed || isCancelled)
                          ? TextDecoration.lineThrough
                          : null,
                      color: (isConfirmed || isCancelled) ? Colors.grey : null,
                    ),
                  ),
                ),
                Text(
                  _timeFormat.format(order.createdAt.toLocal()),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...order.items.map((item) => Text(
                        '• ${item.menuItemName ?? 'Món ăn'} x${item.quantity}',
                        style: TextStyle(
                          fontSize: 13,
                          color: (isConfirmed || isCancelled)
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      )),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _vndFormat.format(order.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: (isConfirmed || isCancelled)
                              ? Colors.grey
                              : theme.colorScheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? Colors.red.withValues(alpha: 0.1)
                              : isConfirmed
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isCancelled
                              ? 'Đã hủy đơn'
                              : isConfirmed
                                  ? 'Đã lấy món'
                                  : 'Chờ lấy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCancelled
                                ? Colors.red
                                : isConfirmed
                                    ? Colors.green
                                    : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canCancel) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hủy đơn đã lấy món?'),
                        content: const Text(
                          'Bạn muốn hủy đơn này. Hoàn tiền sẽ được xử lý bởi bên ngoài thực tế của bạn.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Không'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Hủy đơn'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    try {
                      final supabase = ref.read(supabaseClientProvider);
                      final response = await supabase.functions.invoke(
                        'cancel-order',
                        body: {'order_id': order.id},
                      );

                      if (response.status == 200) {
                        ref
                            .read(canteenOrdersProvider.notifier)
                            .markCancelled(order.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã hủy đơn.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } else {
                        final errorMsg = response.data?['error'] ??
                            response.data?['current_status'] ??
                            'Lỗi hủy đơn';
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg.toString()),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Hủy đơn thất bại: ${e.toString()}',
                            ),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.cancel_outlined,
                      color: theme.colorScheme.error),
                  label: Text(
                    'Hủy đơn',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


