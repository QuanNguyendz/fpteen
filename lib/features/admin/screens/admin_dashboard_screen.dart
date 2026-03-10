import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/features/admin/providers/admin_provider.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final user = ref.watch(authNotifierProvider).user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Đăng xuất',
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminStatsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Xin chào, ${user?.fullName ?? 'Admin'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Bảng điều khiển quản trị FPTeen',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats cards
              Text('Tổng quan hôm nay',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              statsAsync.when(
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => Text('Lỗi: $e',
                    style:
                        TextStyle(color: theme.colorScheme.error)),
                data: (stats) => GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    _StatCard(
                      label: 'Tổng canteen',
                      value: '${stats.totalStores}',
                      sub: '${stats.activeStores} đang hoạt động',
                      icon: Icons.store_outlined,
                      color: Colors.blue,
                    ),
                    _StatCard(
                      label: 'Đơn hôm nay',
                      value: '${stats.todayOrders}',
                      sub: 'Tất cả canteen',
                      icon: Icons.receipt_long_outlined,
                      color: Colors.green,
                    ),
                    _StatCard(
                      label: 'Báo cáo chờ',
                      value: '${stats.pendingReports}',
                      sub: 'Cần xem xét',
                      icon: Icons.report_outlined,
                      color: stats.pendingReports > 0
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    _StatCard(
                      label: 'Canteen tắt',
                      value: '${stats.totalStores - stats.activeStores}',
                      sub: 'Đang vô hiệu hóa',
                      icon: Icons.store_mall_directory_outlined,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action menu
              Text('Quản lý',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.store_outlined,
                title: 'Quản lý Canteen',
                subtitle: 'Xem, bật/tắt các canteen',
                color: Colors.blue,
                onTap: () => context.push('/admin/stores'),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.person_add_outlined,
                title: 'Tạo tài khoản Canteen',
                subtitle: 'Thêm chủ canteen mới vào hệ thống',
                color: Colors.green,
                onTap: () => context.push('/admin/create-owner'),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.report_problem_outlined,
                title: 'Báo cáo từ sinh viên',
                subtitle: 'Xem và xử lý phản ánh về canteen',
                color: Colors.orange,
                onTap: () => context.push('/admin/reports'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
