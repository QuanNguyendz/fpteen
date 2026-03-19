import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/repositories/order_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(supabaseClientProvider));
});

class CheckoutState {
  const CheckoutState({
    this.selectedGateway = AppConstants.gatewayMomo,
    this.note = '',
    this.isLoading = false,
    this.error,
    this.paymentUrl,
    this.orderId,
  });

  final String selectedGateway;
  final String note;
  final bool isLoading;
  final String? error;
  final String? paymentUrl;
  final String? orderId;

  CheckoutState copyWith({
    String? selectedGateway,
    String? note,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? paymentUrl,
    String? orderId,
  }) =>
      CheckoutState(
        selectedGateway: selectedGateway ?? this.selectedGateway,
        note: note ?? this.note,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
        paymentUrl: paymentUrl ?? this.paymentUrl,
        orderId: orderId ?? this.orderId,
      );
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this._ref) : super(const CheckoutState());

  final Ref _ref;

  void selectGateway(String gateway) =>
      state = state.copyWith(selectedGateway: gateway);

  void setNote(String note) => state = state.copyWith(note: note);

  Future<void> placeOrder() async {
    final cart = _ref.read(cartProvider);
    if (cart.isEmpty || cart.selectedStoreId == null || cart.selectedItems.isEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Step 1: Create order via RPC (server-side price validation)
      final orderRepo = _ref.read(orderRepositoryProvider);
      final orderId = await orderRepo.createOrder(
        storeId: cart.selectedStoreId!,
        items: cart.selectedItems
            .map((i) => {
                  'menu_item_id': i.menuItem.id,
                  'quantity': i.quantity,
                })
            .toList(),
        note: state.note.isEmpty ? null : state.note,
      );

      // Step 2: Call create-payment Edge Function
      final supabase = _ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'create-payment',
        body: {'order_id': orderId, 'gateway': state.selectedGateway},
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
        orderId: orderId,
        paymentUrl: paymentUrl,
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


