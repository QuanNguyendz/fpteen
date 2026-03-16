import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/category_model.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/data/repositories/menu_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(supabaseClientProvider));
});

class StoreMenuData {
  const StoreMenuData({
    required this.categories,
    required this.items,
  });

  final List<CategoryModel> categories;
  final List<MenuItemModel> items;

  List<MenuItemModel> itemsByCategory(String? categoryId) =>
      items.where((i) => i.categoryId == categoryId).toList();

  List<MenuItemModel> get uncategorized =>
      items.where((i) => i.categoryId == null).toList();
}

class StoreMenuNotifier extends StateNotifier<AsyncValue<StoreMenuData>> {
  StoreMenuNotifier(this._repo, this._supabase, this._storeId)
      : super(const AsyncValue.loading()) {
    _load();
    if (_storeId.isNotEmpty) _subscribeRealtime();
  }

  final MenuRepository _repo;
  final SupabaseClient _supabase;
  final String _storeId;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    if (_storeId.isEmpty) {
      state = const AsyncValue.data(StoreMenuData(categories: [], items: []));
      return;
    }
    state = const AsyncValue.loading();
    try {
      final results = await Future.wait([
        _repo.fetchCategories(_storeId),
        _repo.fetchMenuItems(_storeId),
      ]);
      state = AsyncValue.data(
        StoreMenuData(
          categories: results[0] as List<CategoryModel>,
          items: results[1] as List<MenuItemModel>,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('store_menu_$_storeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'menu_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: _storeId,
          ),
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'categories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: _storeId,
          ),
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'menu_item_reviews',
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

  @override
  void dispose() {
    if (_channel != null) _supabase.removeChannel(_channel!);
    super.dispose();
  }
}

final storeMenuProvider = StateNotifierProvider.autoDispose
    .family<StoreMenuNotifier, AsyncValue<StoreMenuData>, String>((ref, storeId) {
  return StoreMenuNotifier(
    ref.watch(menuRepositoryProvider),
    ref.watch(supabaseClientProvider),
    storeId,
  );
});


