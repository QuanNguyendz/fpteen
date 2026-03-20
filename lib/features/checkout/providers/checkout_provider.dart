import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/repositories/order_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(supabaseClientProvider));
});

class PickupSlot {
  const PickupSlot({
    required this.slotStart,
    required this.slotLabel,
    required this.remaining,
    required this.capacityPerSlot,
    required this.orderCount,
  });

  final DateTime slotStart;
  final String slotLabel;
  final int remaining;
  final int capacityPerSlot;
  final int orderCount;
}

final storePickupSlotsProvider =
    FutureProvider.autoDispose.family<List<PickupSlot>, String>(
        (ref, storeId) async {
  if (storeId.isEmpty) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final from = now.toUtc().toIso8601String();
  // Default horizon: 4 hours ahead for checkout UX.
  final to = now.add(const Duration(hours: 4)).toUtc().toIso8601String();

  final raw = await supabase.rpc(
    'get_store_pickup_slots',
    params: {
      'p_store_id': storeId,
      'p_from': from,
      'p_to': to,
    },
  );

  final rows = raw as List<dynamic>;
  return rows.map((e) {
    final m = e as Map<String, dynamic>;
    return PickupSlot(
      slotStart: DateTime.parse(m['slot_start'] as String),
      slotLabel: (m['slot_label'] as String?) ?? '',
      remaining: (m['remaining'] as num?)?.toInt() ?? 0,
      capacityPerSlot: (m['capacity_per_slot'] as num?)?.toInt() ?? 0,
      orderCount: (m['order_count'] as num?)?.toInt() ?? 0,
    );
  }).toList();
});

class CheckoutState {
  const CheckoutState({
    this.selectedGateway = AppConstants.gatewayMomo,
    this.note = '',
    this.isLoading = false,
    this.error,
    this.paymentUrl,
    this.orderId,
    this.selectedPickupAt,
    this.assignedPickupAt,
    this.isRescheduled = false,
  });

  final String selectedGateway;
  final String note;
  final bool isLoading;
  final String? error;
  final String? paymentUrl;
  final String? orderId;
  final DateTime? selectedPickupAt;
  final DateTime? assignedPickupAt;
  final bool isRescheduled;

  CheckoutState copyWith({
    String? selectedGateway,
    String? note,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? paymentUrl,
    String? orderId,
    DateTime? selectedPickupAt,
    bool selectedPickupAtReset = false,
    DateTime? assignedPickupAt,
    bool assignedPickupAtReset = false,
    bool? isRescheduled,
  }) =>
      CheckoutState(
        selectedGateway: selectedGateway ?? this.selectedGateway,
        note: note ?? this.note,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        paymentUrl: paymentUrl ?? this.paymentUrl,
        orderId: orderId ?? this.orderId,
        selectedPickupAt: selectedPickupAtReset
            ? null
            : (selectedPickupAt ?? this.selectedPickupAt),
        assignedPickupAt: assignedPickupAtReset
            ? null
            : (assignedPickupAt ?? this.assignedPickupAt),
        isRescheduled: isRescheduled ?? this.isRescheduled,
      );
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this._ref) : super(const CheckoutState());

  final Ref _ref;

  void selectGateway(String gateway) =>
      state = state.copyWith(selectedGateway: gateway);

  void setNote(String note) => state = state.copyWith(note: note);

  void selectPickupAt(DateTime? pickupAt) =>
      state = state.copyWith(selectedPickupAt: pickupAt);

  Future<void> placeOrder() async {
    final cart = _ref.read(cartProvider);
    if (cart.isEmpty || cart.selectedStoreId == null || cart.selectedItems.isEmpty) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      assignedPickupAtReset: true,
      isRescheduled: false,
    );

    try {
      // Step 1: Create order via RPC (server-side price validation)
      final orderRepo = _ref.read(orderRepositoryProvider);
      final result = await orderRepo.createOrderScheduled(
        storeId: cart.selectedStoreId!,
        items: cart.selectedItems
            .map((i) => {
                  'menu_item_id': i.menuItem.id,
                  'quantity': i.quantity,
                })
            .toList(),
        note: state.note.isEmpty ? null : state.note,
        pickupAtRequested: state.selectedPickupAt,
      );

      // Step 2: Call create-payment Edge Function
      final supabase = _ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'create-payment',
        body: {'order_id': result.orderId, 'gateway': state.selectedGateway},
      );

      if (response.status != 200) {
        final err = response.data?['error'] ?? 'Không thể tạo link thanh toán';
        throw PaymentException(err.toString());
      }

      final paymentUrl = response.data['payment_url'] as String;
      if (paymentUrl.isEmpty) {
        throw const PaymentException('Link thanh toán trống. Kiểm tra cấu hình gateway.');
      }

      state = state.copyWith(
        isLoading: false,
        orderId: result.orderId,
        paymentUrl: paymentUrl,
        assignedPickupAt: result.assignedPickupAt,
        isRescheduled: result.rescheduled,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AppException ? e.message : parseSupabaseError(e),
      );
    }
  }

  /// Gets a new payment URL for an existing pending order (e.g. "thanh toán tiếp").
  /// Returns the payment URL or throws on error.
  Future<String> startPaymentForOrder(String orderId, String gateway) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final supabase = _ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'create-payment',
        body: {'order_id': orderId, 'gateway': gateway},
      );
      if (response.status != 200) {
        final err = response.data?['error'] ?? 'Không thể tạo link thanh toán';
        throw PaymentException(err.toString());
      }
      final paymentUrl = response.data['payment_url'] as String?;
      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw const PaymentException('Link thanh toán trống.');
      }
      state = state.copyWith(isLoading: false);
      return paymentUrl;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is AppException ? e.message : parseSupabaseError(e),
      );
      rethrow;
    }
  }

  void reset() => state = const CheckoutState();
}

final checkoutProvider =
    StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>((ref) {
  return CheckoutNotifier(ref);
});


