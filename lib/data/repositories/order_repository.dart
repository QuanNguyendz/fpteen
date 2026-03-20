import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateOrderScheduledResult {
  const CreateOrderScheduledResult({
    required this.orderId,
    required this.assignedPickupAt,
    required this.rescheduled,
  });

  final String orderId;
  final DateTime assignedPickupAt;
  final bool rescheduled;
}

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
    final result = await createOrderScheduled(
      storeId: storeId,
      items: items,
      note: note,
      pickupAtRequested: null,
    );
    return result.orderId;
  }

  /// Creates an order with pickup time-slot assignment (capacity enforced).
  ///
  /// If the requested slot is full, server will automatically reschedule.
  Future<CreateOrderScheduledResult> createOrderScheduled({
    required String storeId,
    required List<Map<String, dynamic>> items,
    String? note,
    DateTime? pickupAtRequested,
  }) async {
    try {
      final raw = await _supabase.rpc(
        'create_order_with_items_and_pickup',
        params: {
          'p_store_id': storeId,
          'p_items': items,
          'p_note': note,
          'p_pickup_at_requested': pickupAtRequested?.toUtc().toIso8601String(),
        },
      );

      Map<String, dynamic> row;
      if (raw is List) {
        if (raw.isEmpty) {
          throw OrderException('Không thể tạo đơn hàng.');
        }
        row = raw.first as Map<String, dynamic>;
      } else if (raw is Map) {
        row = raw as Map<String, dynamic>;
      } else {
        throw OrderException('Không thể đọc kết quả tạo đơn.');
      }

      final orderId = row['order_id'] as String? ?? row['id'] as String?;
      final assignedPickupAtStr =
          row['assigned_pickup_at'] as String? ?? row['pickup_at'] as String?;
      final rescheduled = (row['rescheduled'] as bool?) ?? false;

      if (orderId == null || assignedPickupAtStr == null) {
        throw OrderException('Kết quả tạo đơn không hợp lệ.');
      }

      return CreateOrderScheduledResult(
        orderId: orderId,
        assignedPickupAt: DateTime.parse(assignedPickupAtStr),
        rescheduled: rescheduled,
      );
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
  /// Returns orders for canteen dashboard (paid, confirmed, cancelled).
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
          .or('status.eq.paid,status.eq.confirmed,status.eq.cancelled')
          // Sort by pickup time to help canteen prep earlier and
          // avoid rush when many orders are due at the same moment.
          .order('pickup_at', ascending: true)
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
        .order('pickup_at', ascending: true)
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


