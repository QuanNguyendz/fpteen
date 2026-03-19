import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/features/checkout/providers/checkout_provider.dart';
import 'package:fpteen/features/orders/customer/providers/order_history_provider.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

class ContinuePaymentScreen extends ConsumerStatefulWidget {
  const ContinuePaymentScreen({
    super.key,
    required this.orderId,
    this.order,
  });

  final String orderId;
  final OrderModel? order;

  @override
  ConsumerState<ContinuePaymentScreen> createState() =>
      _ContinuePaymentScreenState();
}

class _ContinuePaymentScreenState extends ConsumerState<ContinuePaymentScreen> {
  String _selectedGateway = AppConstants.gatewayMomo;

  @override
  void initState() {
    super.initState();
    if (widget.order != null && widget.order!.paymentMethod != null) {
      _selectedGateway = widget.order!.paymentMethod!;
    } else {
      _selectedGateway = AppConstants.gatewayMomo;
    }
  }

  Future<void> _startPayment() async {
    final theme = Theme.of(context);
    try {
      final paymentUrl = await ref
          .read(checkoutProvider.notifier)
          .startPaymentForOrder(widget.orderId, _selectedGateway);
      if (!mounted) return;
      context.push('/home/payment', extra: {
        'orderId': widget.orderId,
        'paymentUrl': paymentUrl,
      }).then((_) {
        if (mounted) ref.read(orderHistoryProvider.notifier).refresh();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(checkoutProvider).error ?? 'Lỗi tạo link thanh toán'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(_orderForContinuePaymentProvider(widget.orderId));
    final checkout = ref.watch(checkoutProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán tiếp')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(_orderForContinuePaymentProvider(widget.orderId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Đơn không tồn tại hoặc không còn chờ thanh toán.'));
          }
          if (!order.isPending) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Đơn này đã được thanh toán hoặc hủy.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.storeName ?? 'cửa hàng',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${order.items.length} món',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _vndFormat.format(order.totalAmount),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Phương thức thanh toán',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _PaymentMethodSelector(
                  selected: _selectedGateway,
                  onChanged: (gw) => setState(() => _selectedGateway = gw),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: checkout.isLoading ? null : _startPayment,
                  child: checkout.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Thanh toán tiếp'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

final _orderForContinuePaymentProvider =
    FutureProvider.autoDispose.family<OrderModel?, String>((ref, orderId) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  try {
    return await orderRepo.fetchOrder(orderId);
  } catch (_) {
    return null;
  }
});

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.onChanged,
  });
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final methods = [
      (
        id: AppConstants.gatewayMomo,
        label: 'MoMo',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFFAE2070),
      ),
      (
        id: AppConstants.gatewayVnpay,
        label: 'VNPay',
        icon: Icons.credit_card_outlined,
        color: const Color(0xFF006DB3),
      ),
      (
        id: AppConstants.gatewayZalopay,
        label: 'ZaloPay',
        icon: Icons.payment_outlined,
        color: const Color(0xFF0068FF),
      ),
    ];

    return Column(
      children: methods.map((m) {
        final isSelected = selected == m.id;
        return GestureDetector(
          onTap: () => onChanged(m.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? m.color.withValues(alpha: 0.06)
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: isSelected ? m.color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(m.icon, color: m.color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected) Icon(Icons.check_circle, color: m.color, size: 22),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
