import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/data/repositories/menu_repository.dart';
import 'package:fpteen/features/home/providers/stores_provider.dart';
import 'package:fpteen/features/menu/providers/menu_provider.dart';

class MenuManagementState {
  const MenuManagementState({
    this.items = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<MenuItemModel> items;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  MenuManagementState copyWith({
    List<MenuItemModel>? items,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) =>
      MenuManagementState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : error ?? this.error,
      );
}

class MenuManagementNotifier extends StateNotifier<MenuManagementState> {
  MenuManagementNotifier(this._menuRepo, this._storeId)
      : super(const MenuManagementState(isLoading: true)) {
    _load();
  }

  final MenuRepository _menuRepo;
  final String _storeId;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _menuRepo.fetchMenuItems(_storeId);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<bool> saveItem({
    MenuItemModel? existing,
    required String name,
    required int price,
    String? description,
    String? categoryId,
    File? imageFile,
    required bool isAvailable,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      String? imageUrl = existing?.imageUrl;
      if (imageFile != null) {
        imageUrl = await _menuRepo.uploadMenuImage(_storeId, imageFile);
      }

      final payload = {
        'store_id': _storeId,
        'name': name,
        'price': price,
        'description': description,
        'category_id': categoryId,
        'image_url': imageUrl,
        'is_available': isAvailable,
      };

      if (existing == null) {
        final created = await _menuRepo.createMenuItem(payload);
        state = state.copyWith(
            items: [...state.items, created], isSaving: false);
      } else {
        final updated = await _menuRepo.updateMenuItem(existing.id, payload);
        state = state.copyWith(
          items: state.items
              .map((i) => i.id == existing.id ? updated : i)
              .toList(),
          isSaving: false,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteItem(String itemId) async {
    try {
      await _menuRepo.deleteMenuItem(itemId);
      state = state.copyWith(
          items: state.items.where((i) => i.id != itemId).toList());
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> toggleAvailability(MenuItemModel item) async {
    try {
      final updated = await _menuRepo.updateMenuItem(item.id, {
        'is_available': !item.isAvailable,
      });
      state = state.copyWith(
        items: state.items
            .map((i) => i.id == item.id ? updated : i)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final menuManagementProvider = StateNotifierProvider.autoDispose<
    MenuManagementNotifier, MenuManagementState>((ref) {
  final storeId = ref.watch(myStoreProvider).valueOrNull?.id ?? '';
  return MenuManagementNotifier(ref.watch(menuRepositoryProvider), storeId);
});


