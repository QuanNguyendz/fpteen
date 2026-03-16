import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/data/repositories/store_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.watch(supabaseClientProvider));
});

class ActiveStoresNotifier extends StateNotifier<AsyncValue<List<StoreModel>>> {
  ActiveStoresNotifier(this._repo, this._supabase)
      : super(const AsyncValue.loading()) {
    _load();
    _subscribeRealtime();
  }

  final StoreRepository _repo;
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final stores = await _repo.fetchActiveStores();
      state = AsyncValue.data(stores);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('active_stores')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stores',
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

final activeStoresProvider = StateNotifierProvider.autoDispose<
    ActiveStoresNotifier, AsyncValue<List<StoreModel>>>((ref) {
  return ActiveStoresNotifier(
    ref.watch(storeRepositoryProvider),
    ref.watch(supabaseClientProvider),
  );
});

/// Store owned by the current store_owner user (used in canteen flow).
final myStoreProvider = FutureProvider<StoreModel?>((ref) async {
  final user = ref.watch(authNotifierProvider).user;
  if (user == null || !user.isStoreOwner) return null;
  return ref.watch(storeRepositoryProvider).fetchStoreByOwnerId(user.id);
});


