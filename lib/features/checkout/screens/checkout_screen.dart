import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/features/checkout/providers/checkout_provider.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);
    final theme = Theme.of(context);
    final selectedStoreId = cart.selectedStoreId;
    final selectedItems = cart.selectedItems;

    ref.listen(checkoutProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
      if (next.paymentUrl != null && next.orderId != null && prev?.paymentUrl == null) {
        context.push('/home/payment', extra: {
          'orderId': next.orderId!,
          'paymentUrl': next.paymentUrl!,
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đơn hàng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order summary
            _SectionTitle(title: 'Chi tiết đơn hàng'),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: selectedItems.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (ctx, i) {
                  final item = selectedItems[i];
                  return Row(
                    children: [
                      Expanded(
                        child: Text('${item.menuItem.name} x${item.quantity}',
                            style: const TextStyle(fontSize: 14)),
                      ),
                      Text(
                        _vndFormat.format(item.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Note
            _SectionTitle(title: 'Ghi chú'),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Không đường, thêm đá...',
              ),
              onChanged: (v) =>
                  ref.read(checkoutProvider.notifier).setNote(v),
            ),
            const SizedBox(height: 16),
            // Payment method
            _SectionTitle(title: 'Phương thức thanh toán'),
            _PaymentMethodSelector(
              selected: checkout.selectedGateway,
              onChanged: (gw) =>
                  ref.read(checkoutProvider.notifier).selectGateway(gw),
            ),
            const SizedBox(height: 24),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tổng thanh toán',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  _vndFormat.format(cart.selectedTotalAmount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: checkout.isLoading
                  ? null
                  : (selectedStoreId == null || selectedItems.isEmpty)
                      ? null
                      : () => ref.read(checkoutProvider.notifier).placeOrder(),
              child: checkout.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Thanh toán ngay'),
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('Thanh toán an toàn & mã hóa',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector(
      {required this.selected, required this.onChanged});
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
              color: isSelected ? m.color.withValues(alpha: 0.06) : Colors.white,
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
                  child: Text(m.label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      )),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: m.color, size: 22),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}


