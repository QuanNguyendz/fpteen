import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/features/invoice/providers/invoice_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
final _dateFormat = DateFormat('HH:mm - dd/MM/yyyy');

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hóa đơn'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.home_outlined),
            label: const Text('Trang chủ'),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const AppLoadingWidget(message: 'Đang tải hóa đơn...'),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(invoiceProvider(orderId)),
        ),
        data: (order) => _InvoiceContent(order: order),
      ),
    );
  }
}

class _InvoiceContent extends StatefulWidget {
  const _InvoiceContent({required this.order});
  final OrderModel order;

  @override
  State<_InvoiceContent> createState() => _InvoiceContentState();
}

class _InvoiceContentState extends State<_InvoiceContent> {
  static const String _pickupQrPrefix = 'fpteen-pickup:';
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isDownloading = false;

  String _pickupQrData(String orderId) => '$_pickupQrPrefix$orderId';

  Future<void> _downloadQrCode() async {
    setState(() => _isDownloading = true);
    try {
      // Check & request gallery access permission
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cần cấp quyền lưu ảnh để tải xuống QR')),
          );
          return;
        }
      }

      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
      );
      if (imageBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tạo ảnh QR')),
        );
        return;
      }

      await Gal.putImageBytes(imageBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu mã QR vào thư viện ảnh!'),
          backgroundColor: Colors.green,
        ),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lưu ảnh thất bại: ${e.type.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final theme = Theme.of(context);
    final pickupQrData = _pickupQrData(order.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Success indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đặt hàng thành công!',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.green),
                      ),
                      Text(
                        'Mang mã QR đến canteen để nhận món',
                        style: TextStyle(
                            fontSize: 13, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'QR hóa đơn',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhân viên quét mã này để xác nhận đơn',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                // Wrap QR in Screenshot widget for capture
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: pickupQrData,
                          version: QrVersions.auto,
                          size: 220,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '#${order.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'FPTeen – Đặt đồ ăn canteen',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Download button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _downloadQrCode,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                        _isDownloading ? 'Đang lưu...' : 'Tải xuống mã QR'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Order details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    label: 'Canteen',
                    value: order.storeName ?? '—',
                  ),
                  _DetailRow(
                    label: 'Thời gian',
                    value: _dateFormat.format(order.createdAt.toLocal()),
                  ),
                  _DetailRow(
                    label: 'Phương thức',
                    value: _gatewayLabel(order.paymentMethod),
                  ),
                  const Divider(height: 20),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.menuItemName ?? 'Món ăn'} x${item.quantity}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            _vndFormat.format(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng cộng',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        _vndFormat.format(order.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (order.note != null && order.note!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.notes_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Ghi chú: ${order.note}',
                            style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _gatewayLabel(String? gateway) {
    switch (gateway) {
      case 'momo':
        return 'MoMo';
      case 'vnpay':
        return 'VNPay';
      case 'zalopay':
        return 'ZaloPay';
      default:
        return '—';
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ),
          ],
        ),
      );
}

