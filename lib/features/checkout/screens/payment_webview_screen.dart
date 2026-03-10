import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/features/checkout/providers/checkout_provider.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';
import 'package:fpteen/features/orders/customer/providers/order_history_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.orderId,
    required this.paymentUrl,
  });

  final String orderId;
  final String paymentUrl;

  @override
  ConsumerState<PaymentWebViewScreen> createState() =>
      _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState
    extends ConsumerState<PaymentWebViewScreen> {
  late final WebViewController _controller;
  StreamSubscription? _orderStreamSub;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _setupWebView();
    _subscribeToOrderStatus();
  }

  void _setupWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            // Intercept return URL: payment-webhook Edge Function URL or callback URL
            if (_isPaymentCallbackUrl(url)) {
              _handleCallbackUrl(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) => setState(() {}),
          onPageFinished: (_) => setState(() {}),
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Chỉ chặn URL callback cuối (fpteen.app). Không chặn URL webhook Supabase
  /// để khi gateway redirect tới payment-webhook, request tới server và cập nhật orders.status = 'paid'.
  bool _isPaymentCallbackUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host == AppConstants.paymentCallbackHost &&
        uri.path.contains(AppConstants.paymentCallbackPath);
  }

  void _handleCallbackUrl(String url) {
    final uri = Uri.parse(url);
    final status = uri.queryParameters['status'] ??
        (uri.queryParameters['vnp_ResponseCode'] == '00' ? 'success' : 'failed');
    final orderId = uri.queryParameters['order_id'] ?? widget.orderId;

    if (_navigated) return;
    _navigated = true;

    if (status == 'success') {
      _onPaymentSuccess(orderId);
    } else {
      _onPaymentFailed();
    }
  }

  void _subscribeToOrderStatus() {
    final orderRepo = ref.read(orderRepositoryProvider);
    _orderStreamSub = orderRepo.streamOrder(widget.orderId).listen((order) {
      if (!mounted || _navigated) return;
      if (order.isPaid) {
        _navigated = true;
        _onPaymentSuccess(order.id);
      } else if (order.isCancelled) {
        _navigated = true;
        _onPaymentFailed();
      }
    });
  }

  void _onPaymentSuccess(String orderId) {
    if (!mounted) return;
    ref.read(orderHistoryProvider.notifier).refresh();
    ref.read(cartProvider.notifier).clear();
    ref.read(checkoutProvider.notifier).reset();
    context.go('/home/invoice/$orderId');
  }

  void _onPaymentFailed() {
    if (!mounted) return;
    ref.read(orderHistoryProvider.notifier).refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanh toán không thành công. Vui lòng thử lại.'),
        backgroundColor: Colors.red,
      ),
    );
    context.pop();
  }

  @override
  void dispose() {
    _orderStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hủy thanh toán?'),
            content: const Text(
                'Bạn có chắc muốn hủy thanh toán? Đơn hàng sẽ không được xử lý.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Tiếp tục thanh toán'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Hủy',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (shouldLeave == true && mounted) {
          ref.read(orderHistoryProvider.notifier).refresh();
          router.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thanh toán'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final router = GoRouter.of(context);
              final shouldLeave = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Hủy thanh toán?'),
                  content: const Text(
                      'Bạn có chắc muốn hủy? Đơn hàng sẽ không được xử lý.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Tiếp tục'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Hủy',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (shouldLeave == true && mounted) {
                ref.read(orderHistoryProvider.notifier).refresh();
                router.pop();
              }
            },
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}


