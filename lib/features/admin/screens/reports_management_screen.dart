import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/report_model.dart';
import 'package:fpteen/features/admin/providers/admin_provider.dart';
import 'package:fpteen/shared/widgets/app_error_widget.dart';
import 'package:fpteen/shared/widgets/empty_state_widget.dart';
import 'package:fpteen/shared/widgets/loading_widget.dart';
import 'package:intl/intl.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

class ReportsManagementScreen extends ConsumerWidget {
  const ReportsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(allReportsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Báo cáo từ sinh viên'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chờ xử lý'),
              Tab(text: 'Đã giải quyết'),
            ],
          ),
        ),
        body: reportsAsync.when(
          loading: () => const AppLoadingWidget(message: 'Đang tải...'),
          error: (e, _) => AppErrorWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(allReportsProvider),
          ),
          data: (reports) {
            final pending =
                reports.where((r) => r.isPending).toList();
            final resolved =
                reports.where((r) => r.isResolved).toList();

            return TabBarView(
              children: [
                _ReportList(
                    reports: pending,
                    emptyMessage: 'Không có báo cáo nào chờ xử lý.'),
                _ReportList(
                    reports: resolved,
                    emptyMessage: 'Chưa có báo cáo nào được giải quyết.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportList extends ConsumerWidget {
  const _ReportList(
      {required this.reports, required this.emptyMessage});
  final List<ReportModel> reports;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reports.isEmpty) {
      return EmptyStateWidget(
          message: emptyMessage, icon: Icons.check_circle_outline);
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(allReportsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _ReportCard(report: reports[i]),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});
  final ReportModel report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolveState = ref.watch(resolveReportProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.storeName ?? 'Cửa hàng',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: report.isPending
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.isPending ? 'Chờ xử lý' : 'Đã giải quyết',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: report.isPending
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  report.reporterName ?? 'Sinh viên',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _dateFormat.format(report.createdAt.toLocal()),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(report.content,
                  style: const TextStyle(fontSize: 14)),
            ),
            if (report.adminNote != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.admin_panel_settings,
                        size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.adminNote!,
                        style: TextStyle(
                            fontSize: 13, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (report.isPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Đánh dấu đã giải quyết'),
                  onPressed: resolveState.isLoading
                      ? null
                      : () => _showResolveDialog(context, ref),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showResolveDialog(
      BuildContext context, WidgetRef ref) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Giải quyết báo cáo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ghi chú xử lý (tuỳ chọn):'),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Mô tả cách đã xử lý...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(resolveReportProvider.notifier)
          .resolve(report.id, noteCtrl.text.trim());
    }
    noteCtrl.dispose();
  }
}
