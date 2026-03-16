import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderRepository {
  OrderRepository(this._supabase);

  final SupabaseClient _supabase;

  static const String _orderSelect =
      '*, order_items(*, menu_items(name, store_id)), stores(name)';

  /// Creates order atomically via RPC (price validated server-side).
  Future<String> createOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    try {
      final orderId = await _supabase.rpc('create_order_with_items', params: {
        'p_store_id': storeId,
        'p_items': items,
        'p_note': note,
      });
      return orderId as String;
    } catch (e) {
      throw OrderException(parseSupabaseError(e));
    }
  }

  Future<OrderModel> fetchOrder(String orderId) async {
    try {
      final data = await _supabase
          .from('orders')
          .select(_orderSelect)
          .eq('id', orderId)
          .single();
      return OrderModel.fromJson(data);
    } catch (e) {
      throw OrderException(parseSupabaseError(e));
    }
  }

  Future<List<OrderModel>> fetchCustomerOrders(String customerId) async {
    try {
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*, menu_items(name, store_id)), stores(name)')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw OrderException(parseSupabaseError(e));
    }
  }

  /// Fetches today's orders for a store (canteen dashboard).
  /// Only returns orders that have been successfully paid (paid or confirmed).
  Future<List<OrderModel>> fetchTodayStoreOrders(String storeId) async {
    try {
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*, menu_items(name)), users(full_name, phone)')
          .eq('store_id', storeId)
          .gte('created_at', startOfDay)
          .or('status.eq.paid,status.eq.confirmed')
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw OrderException(parseSupabaseError(e));
    }
  }

  /// Stream of today's orders for canteen via Supabase Realtime.
  Stream<List<OrderModel>> streamTodayOrders(String storeId) {
    final today = DateTime.now();
    final startOfDay =
        DateTime(today.year, today.month, today.day).toUtc().toIso8601String();
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('store_id', storeId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((r) => (r['created_at'] as String).compareTo(startOfDay) >= 0)
            .map((e) => OrderModel.fromJson(e))
            .toList());
  }

  /// Cancels a pending order (customer's own order only). RLS enforces ownership.
  Future<void> cancelOrder(String orderId) async {
    try {
      final res = await _supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId)
          .eq('status', 'pending')
          .select('id');
      if ((res as List).isEmpty) {
        throw OrderException('Đơn không tồn tại hoặc không thể hủy');
      }
    } catch (e) {
      throw OrderException(parseSupabaseError(e));
    }
  }

  /// Stream a single order for payment status tracking.
  Stream<OrderModel> streamOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) => OrderModel.fromJson(rows.first));
  }
}


