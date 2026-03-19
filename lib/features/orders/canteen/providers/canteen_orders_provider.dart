import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/data/repositories/order_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:fpteen/features/checkout/providers/checkout_provider.dart';
import 'package:fpteen/features/home/providers/stores_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CanteenOrdersNotifier
    extends StateNotifier<AsyncValue<List<OrderModel>>> {
  CanteenOrdersNotifier(this._orderRepo, this._supabase, this._storeId)
      : super(const AsyncValue.loading()) {
    _load();
    _subscribeRealtime();
  }

  final OrderRepository _orderRepo;
  final SupabaseClient _supabase;
  final String _storeId;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final orders = await _orderRepo.fetchTodayStoreOrders(_storeId);
      if (mounted) state = AsyncValue.data(orders);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('canteen_orders_$_storeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: _storeId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  Future<void> refresh() => _load();

  /// Called after canteen confirms an order via QR scan (optimistic update).
  void markConfirmed(String orderId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current
          .map((o) => o.id == orderId ? o.copyWith(status: 'confirmed') : o)
          .toList(),
    );
  }

  /// Called after store cancels an already completed ("confirmed") order.
  /// Analytics RPC only counts orders with status 'paid'/'confirmed', so
  /// setting status='cancelled' will automatically subtract revenue.
  void markCancelled(String orderId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current
          .map((o) => o.id == orderId ? o.copyWith(status: 'cancelled') : o)
          .toList(),
    );
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel!);
    super.dispose();
  }
}

final canteenOrdersProvider = StateNotifierProvider.autoDispose<
    CanteenOrdersNotifier, AsyncValue<List<OrderModel>>>((ref) {
  final store = ref.watch(myStoreProvider).valueOrNull;
  final storeId = store?.id ?? '';
  return CanteenOrdersNotifier(
    ref.watch(orderRepositoryProvider),
    ref.watch(supabaseClientProvider),
    storeId,
  );
});


