import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/features/analytics/providers/store_analytics_provider.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

class StoreAnalyticsScreen extends ConsumerWidget {
  const StoreAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storeAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân tích cửa hàng'),
      ),
      body: async.when(
        loading: () =>
            const AppLoadingWidget(message: 'Đang tải số liệu phân tích...'),
        error: (e, _) =>
            AppErrorWidget(message: e.toString(), onRetry: () {
          ref.invalidate(storeAnalyticsProvider);
        }),
        data: (data) {
          final stats = data.ratingStats;
          final avgRating = (stats['avg_rating'] ?? 0.0) as num;
          final ratingCount = (stats['rating_count'] ?? 0) as num;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng quan',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryCard(
                      label: 'Doanh thu tháng mới nhất',
                      value: data.revenueByMonth.isNotEmpty
                          ? _currency.format(
                              data.revenueByMonth.first['total_revenue'] ?? 0)
                          : '—',
                    ),
                    const SizedBox(width: 12),
                    _SummaryCard(
                      label: 'Điểm trung bình',
                      value: ratingCount > 0
                          ? '${avgRating.toStringAsFixed(1)} (${ratingCount.toInt()} lượt)'
                          : 'Chưa có đánh giá',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Doanh thu theo tháng',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (data.revenueByMonth.isEmpty)
                  const Text('Chưa có đơn hàng để tính doanh thu.')
                else
                  Column(
                    children: data.revenueByMonth
                        .map((row) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  '${row['month']}/${row['year']} - ${_currency.format(row['total_revenue'])}'),
                              subtitle: Text(
                                  '${row['orders_count']} đơn hoàn tất'),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Món bán chạy',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (data.bestSellers.isEmpty)
                  const Text('Chưa có dữ liệu món bán chạy.')
                else
                  Column(
                    children: data.bestSellers
                        .map((row) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(row['name'] as String),
                              subtitle: Text(
                                  '${row['total_quantity']} phần • ${_currency.format(row['total_revenue'])}'),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Phân bố đánh giá',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (ratingCount == 0)
                  const Text('Chưa có đánh giá nào.')
                else
                  Column(
                    children: [
                      for (int star = 5; star >= 1; star--)
                        _StarBar(
                          star: star,
                          count: (stats['star_$star'] ?? 0) as int,
                          total: ratingCount.toInt(),
                        ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({required this.star, required this.count, required this.total});
  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$star ⭐',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.shade200,
              color: Colors.amber.shade700,
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

