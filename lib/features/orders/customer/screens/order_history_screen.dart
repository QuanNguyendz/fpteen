import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/features/checkout/providers/checkout_provider.dart';
import 'package:fpteen/features/orders/customer/providers/order_history_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/empty_state_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  final Set<String> _expiredOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(orderHistoryProvider.notifier).refresh();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancelAndRefresh(String orderId) async {
    try {
      await ref.read(orderRepositoryProvider).cancelOrder(orderId);
      if (mounted) ref.read(orderHistoryProvider.notifier).refresh();
    } catch (_) {
      if (mounted) ref.read(orderHistoryProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đơn hàng')),
      body: ordersAsync.when(
        loading: () => const AppLoadingWidget(message: 'Đang tải...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.read(orderHistoryProvider.notifier).refresh(),
        ),
        data: (orders) {
          for (final order in orders) {
            if (order.isPending) {
              final expiresAt = order.createdAt
                  .add(Duration(minutes: AppConstants.paymentTimeoutMinutes));
              if (expiresAt.isBefore(_now) && !_expiredOrderIds.contains(order.id)) {
                _expiredOrderIds.add(order.id);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _cancelAndRefresh(order.id);
                });
              }
            }
          }
          if (orders.isEmpty) {
            return const EmptyStateWidget(
              message: 'Bạn chưa có đơn hàng nào.',
              icon: Icons.receipt_long_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(orderHistoryProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _OrderCard(
                order: orders[i],
                now: _now,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.now});
  final OrderModel order;
  final DateTime now;

  static String _formatRemaining(Duration d) {
    if (d.isNegative) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = order.isPending;
    Duration? remaining;
    bool expired = false;
    if (isPending) {
      final expiresAt = order.createdAt
          .add(Duration(minutes: AppConstants.paymentTimeoutMinutes));
      remaining = expiresAt.difference(now);
      expired = remaining.isNegative || remaining.inSeconds == 0;
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (order.isPaid || order.isConfirmed) {
            context.push('/home/invoice/${order.id}');
          } else if (order.isPending) {
            context.push('/home/order/${order.id}/continue-payment', extra: order);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.storeName ?? 'Cửa hàng',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.items.length} món · ${_dateFormat.format(order.createdAt.toLocal())}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (isPending) ...[
                const SizedBox(height: 8),
                Text(
                  expired
                      ? 'Hết thời gian thanh toán'
                      : 'Còn ${_formatRemaining(remaining!)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: expired ? theme.colorScheme.error : Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                if (!expired)
                  Text(
                    'Chạm để thanh toán tiếp',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _vndFormat.format(order.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (order.isPaid || order.isConfirmed)
                    Row(
                      children: [
                        Icon(Icons.receipt_long,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('Xem hóa đơn điện tử',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  if (order.isPending && !expired)
                    Row(
                      children: [
                        Icon(Icons.payment, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('Thanh toán tiếp',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('Chờ thanh toán', Colors.orange),
      'paid' => ('Đã thanh toán', Colors.blue),
      'confirmed' => ('Đã xác nhận', Colors.green),
      'cancelled' => ('Đã hủy', Colors.red),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}


