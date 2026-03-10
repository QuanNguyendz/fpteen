import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/order_model.dart';
import 'package:fpteen/features/checkout/providers/checkout_provider.dart';

final invoiceProvider =
    FutureProvider.family.autoDispose<OrderModel, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).fetchOrder(orderId);
});


