import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/models/report_model.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

// ── Stats ─────────────────────────────────────────────────────────────────────

class AdminStats {
  const AdminStats({
    required this.totalStores,
    required this.activeStores,
    required this.todayOrders,
    required this.pendingReports,
  });

  final int totalStores;
  final int activeStores;
  final int todayOrders;
  final int pendingReports;
}

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

  final results = await Future.wait([
    supabase.from('stores').select('id, is_active'),
    supabase
        .from('orders')
        .select('id')
        .gte('created_at', startOfDay),
    supabase.from('reports').select('id').eq('status', 'pending'),
  ]);

  final stores = results[0] as List;
  final orders = results[1] as List;
  final reports = results[2] as List;

  return AdminStats(
    totalStores: stores.length,
    activeStores: stores.where((s) => s['is_active'] == true).length,
    todayOrders: orders.length,
    pendingReports: reports.length,
  );
});

// ── All Stores ────────────────────────────────────────────────────────────────

final allStoresProvider = FutureProvider.autoDispose<List<StoreModel>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('stores')
      .select('*, users(full_name, email)')
      .order('created_at', ascending: false);
  return (data as List)
      .map((e) => StoreModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Toggle Store ──────────────────────────────────────────────────────────────

class StoreToggleNotifier extends StateNotifier<AsyncValue<void>> {
  StoreToggleNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> toggle(String storeId, bool currentValue) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(supabaseClientProvider)
          .from('stores')
          .update({'is_active': !currentValue})
          .eq('id', storeId);
      _ref.invalidate(allStoresProvider);
      _ref.invalidate(adminStatsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final storeToggleProvider =
    StateNotifierProvider.autoDispose<StoreToggleNotifier, AsyncValue<void>>(
        (ref) => StoreToggleNotifier(ref));

// ── All Reports ───────────────────────────────────────────────────────────────

final allReportsProvider =
    FutureProvider.autoDispose<List<ReportModel>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('reports')
      .select('*, stores(name), users(full_name)')
      .order('created_at', ascending: false);
  return (data as List)
      .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Resolve Report ────────────────────────────────────────────────────────────

class ResolveReportNotifier extends StateNotifier<AsyncValue<void>> {
  ResolveReportNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> resolve(String reportId, String adminNote) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(supabaseClientProvider).from('reports').update({
        'status': 'resolved',
        'admin_note': adminNote,
      }).eq('id', reportId);
      _ref.invalidate(allReportsProvider);
      _ref.invalidate(adminStatsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final resolveReportProvider =
    StateNotifierProvider.autoDispose<ResolveReportNotifier, AsyncValue<void>>(
        (ref) => ResolveReportNotifier(ref));

// ── Create Store Owner ────────────────────────────────────────────────────────

class CreateStoreOwnerState {
  const CreateStoreOwnerState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  final bool isLoading;
  final String? error;
  final bool success;
}

class CreateStoreOwnerNotifier
    extends StateNotifier<CreateStoreOwnerState> {
  CreateStoreOwnerNotifier(this._ref)
      : super(const CreateStoreOwnerState());

  final Ref _ref;

  Future<void> create({
    required String email,
    required String password,
    required String fullName,
    required String storeName,
    String? storeDescription,
    String? storeAddress,
  }) async {
    state = const CreateStoreOwnerState(isLoading: true);
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'create-store-owner',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'store_name': storeName,
          'store_description': storeDescription,
          'store_address': storeAddress,
        },
      );

      if (response.status != 200) {
        final err = response.data?['error'] ?? 'Không thể tạo tài khoản';
        throw AppException(err.toString());
      }

      _ref.invalidate(allStoresProvider);
      _ref.invalidate(adminStatsProvider);
      state = const CreateStoreOwnerState(success: true);
    } catch (e) {
      state = CreateStoreOwnerState(
          error: e is AppException ? e.message : e.toString());
    }
  }

  void reset() => state = const CreateStoreOwnerState();
}

final createStoreOwnerProvider = StateNotifierProvider.autoDispose<
    CreateStoreOwnerNotifier, CreateStoreOwnerState>(
  (ref) => CreateStoreOwnerNotifier(ref),
);
