import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:fpteen/features/orders/canteen/providers/canteen_orders_provider.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  static const String _pickupQrPrefix = 'fpteen-pickup:';
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  String? _extractOrderId(String rawQrValue) {
    final value = rawQrValue.trim();
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    // New format: fpteen-pickup:<uuid>
    if (value.toLowerCase().startsWith(_pickupQrPrefix)) {
      final extracted = value.substring(_pickupQrPrefix.length).trim();
      return uuidRegex.hasMatch(extracted) ? extracted : null;
    }

    // Backward compatibility: plain UUID QR
    return uuidRegex.hasMatch(value) ? value : null;
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final rawCode = capture.barcodes.firstOrNull?.rawValue;
    if (rawCode == null || rawCode.isEmpty) return;

    final orderId = _extractOrderId(rawCode);
    if (orderId == null) {
      setState(() {
        _message = 'QR không hợp lệ. Vui lòng quét mã nhận hàng FPTeen.';
        _success = false;
      });
      return;
    }

    setState(() => _isProcessing = true);
    await _scannerCtrl.stop();

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'confirm-order',
        body: {'order_id': orderId},
      );

      if (response.status == 200) {
        // Optimistic UI update
        ref.read(canteenOrdersProvider.notifier).markConfirmed(orderId);

        setState(() {
          _message = 'Xác nhận thành công!';
          _success = true;
          _isProcessing = false;
        });

        if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác nhận thành công!'),
              backgroundColor: Colors.green,
            ),
          );

        // After success: show the scanned e-invoice detail screen.
        // When the user presses back/exit, they will return to the store invoice list screen (`/canteen`).
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        context.go('/canteen/invoice/$orderId');
      } else {
        final errorMsg = response.data?['error'] ??
            response.data?['current_status'] ?? 'Lỗi xác nhận đơn hàng';
        setState(() {
          _message = _friendlyError(errorMsg.toString(), response.data?['current_status']);
          _success = false;
          _isProcessing = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) await _scannerCtrl.start();
      }
    } catch (e) {
      setState(() {
        _message = 'Không thể kết nối. Kiểm tra mạng và thử lại.';
        _success = false;
        _isProcessing = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) await _scannerCtrl.start();
    }
  }

  String _friendlyError(String error, dynamic currentStatus) {
    if (error.contains('not found')) return 'Không tìm thấy đơn hàng.';
    if (error.contains('confirmed') || currentStatus == 'confirmed') {
      return 'Đơn hàng này đã được xác nhận trước đó.';
    }
    if (error.contains('pending') || currentStatus == 'pending') {
      return 'Đơn hàng chưa thanh toán.';
    }
    if (error.contains('cancelled') || currentStatus == 'cancelled') {
      return 'Đơn hàng đã bị hủy.';
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét QR hóa đơn',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerCtrl,
              builder: (ctx, state, _) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
            ),
            onPressed: () => _scannerCtrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerCtrl,
            onDetect: _handleDetect,
          ),
          // Overlay frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _success
                      ? Colors.green
                      : theme.colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isProcessing
                  ? Center(
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.primary))
                  : null,
            ),
          ),
          // Instruction / result text
          Positioned(
            bottom: 80,
            left: 24,
            right: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _message != null
                  ? Container(
                      key: ValueKey(_message),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: _success
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _success
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _message!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      key: const ValueKey('instruction'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Đưa camera vào QR của hóa đơn khách hàng',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
