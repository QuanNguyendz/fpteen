import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/category_model.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/data/repositories/menu_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

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

final storeMenuProvider =
    FutureProvider.family<StoreMenuData, String>((ref, storeId) async {
  final repo = ref.watch(menuRepositoryProvider);
  final results = await Future.wait([
    repo.fetchCategories(storeId),
    repo.fetchMenuItems(storeId),
  ]);
  return StoreMenuData(
    categories: results[0] as List<CategoryModel>,
    items: results[1] as List<MenuItemModel>,
  );
});


