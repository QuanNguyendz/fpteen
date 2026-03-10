import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/data/repositories/order_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:fpteen/features/checkout/providers/checkout_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Order history with Realtime: list refetches when any of the customer's orders
/// is updated (e.g. webhook sets status to 'paid'), so paid orders show correctly.
class OrderHistoryNotifier
    extends StateNotifier<AsyncValue<List<OrderModel>>> {
  OrderHistoryNotifier(this._orderRepo, this._supabase, this._userId)
      : super(const AsyncValue.loading()) {
    _load();
    if (_userId.isNotEmpty) _subscribeRealtime();
  }

  final OrderRepository _orderRepo;
  final SupabaseClient _supabase;
  final String _userId;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    if (_userId.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final orders = await _orderRepo.fetchCustomerOrders(_userId);
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('customer_orders_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: _userId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    if (_channel != null) _supabase.removeChannel(_channel!);
    super.dispose();
  }
}

final orderHistoryProvider = StateNotifierProvider.autoDispose<
    OrderHistoryNotifier, AsyncValue<List<OrderModel>>>((ref) {
  final userId = ref.watch(authNotifierProvider).user?.id ?? '';
  return OrderHistoryNotifier(
    ref.watch(orderRepositoryProvider),
    ref.watch(supabaseClientProvider),
    userId,
  );
});


