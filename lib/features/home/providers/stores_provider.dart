import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/data/repositories/store_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.watch(supabaseClientProvider));
});

final activeStoresProvider = FutureProvider<List<StoreModel>>((ref) async {
  return ref.watch(storeRepositoryProvider).fetchActiveStores();
});

/// Store owned by the current store_owner user (used in canteen flow).
final myStoreProvider = FutureProvider<StoreModel?>((ref) async {
  final user = ref.watch(authNotifierProvider).user;
  if (user == null || !user.isStoreOwner) return null;
  return ref.watch(storeRepositoryProvider).fetchStoreByOwnerId(user.id);
});


