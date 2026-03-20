import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/features/invoice/providers/invoice_provider.dart';
import 'package:fpteen/features/reviews/providers/review_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
final _dateFormat = DateFormat('HH:mm - dd/MM/yyyy');

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({
    super.key,
    required this.orderId,
    this.isStoreFlow = false,
  });
  final String orderId;
  final bool isStoreFlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hóa đơn'),
        automaticallyImplyLeading: isStoreFlow,
        actions: isStoreFlow
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.report_outlined),
                  tooltip: 'Báo cáo cửa hàng',
                  onPressed: () {
                    final order = invoiceAsync.valueOrNull;
                    if (order == null) return;
                    context.push(
                      '/home/report/${order.storeId}',
                      extra: {'storeName': order.storeName ?? 'Cửa hàng'},
                    );
                  },
                ),
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
                        'Mang mã QR đến cửa hàng để nhận món',
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
                          'FPTeen – Đặt đồ ăn cửa hàng',
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
                    label: 'Cửa hàng',
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
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Row(
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
                          if (item.menuItemStoreId != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  showDragHandle: true,
                                  builder: (ctx) => _ReviewSheet(
                                    menuItemId: item.menuItemId,
                                    storeId: item.menuItemStoreId!,
                                    menuItemName: item.menuItemName ?? 'Món ăn',
                                  ),
                                ),
                                child: const Text('Đánh giá'),
                              ),
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

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({
    required this.menuItemId,
    required this.storeId,
    required this.menuItemName,
  });

  final String menuItemId;
  final String storeId;
  final String menuItemName;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _contentCtrl = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myReviewAsync = ref.watch(myReviewForMenuItemProvider(widget.menuItemId));
    final upsertState = ref.watch(upsertReviewProvider);
    final theme = Theme.of(context);

    ref.listen(upsertReviewProvider, (_, next) {
      if (next.hasError) {
        final msg = next.error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể lưu đánh giá: $msg'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      } else if (next is AsyncData) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu đánh giá. Cảm ơn bạn!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: myReviewAsync.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 160,
          child: Center(child: Text(e.toString())),
        ),
        data: (review) {
          if (review != null) {
            _rating = review.rating;
            _contentCtrl.text = review.content ?? '';
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Đánh giá: ${widget.menuItemName}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setState(() => _rating = i),
                      icon: Icon(
                        i <= _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  const Spacer(),
                  Text('$_rating/5', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              TextField(
                controller: _contentCtrl,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (tuỳ chọn)',
                  hintText: 'Bạn thấy món ăn như thế nào?',
                  alignLabelWithHint: true,
                ),
              ),
              if (review != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Cập nhật: ${DateFormat('dd/MM/yyyy HH:mm').format(review.updatedAt.toLocal())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: upsertState.isLoading
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        await ref.read(upsertReviewProvider.notifier).upsert(
                              menuItemId: widget.menuItemId,
                              storeId: widget.storeId,
                              rating: _rating,
                              content: _contentCtrl.text.trim().isEmpty
                                  ? null
                                  : _contentCtrl.text.trim(),
                            );
                        if (mounted) navigator.pop();
                      },
                child: upsertState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Lưu đánh giá'),
              ),
            ],
          );
        },
      ),
    );
  }
}


