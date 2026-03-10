import 'dart:io';

import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/models/category_model.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuRepository {
  MenuRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<CategoryModel>> fetchCategories(String storeId) async {
    try {
      final data = await _supabase
          .from('categories')
          .select()
          .eq('store_id', storeId)
          .order('display_order');
      return (data as List)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(parseSupabaseError(e));
    }
  }

  Future<List<MenuItemModel>> fetchMenuItems(String storeId) async {
    try {
      final data = await _supabase
          .from('menu_items')
          .select()
          .eq('store_id', storeId)
          .order('name');
      return (data as List)
          .map((e) => MenuItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(parseSupabaseError(e));
    }
  }

  Future<MenuItemModel> createMenuItem(Map<String, dynamic> payload) async {
    try {
      final data = await _supabase
          .from('menu_items')
          .insert(payload)
          .select()
          .single();
      return MenuItemModel.fromJson(data);
    } catch (e) {
      throw AppException(parseSupabaseError(e));
    }
  }

  Future<MenuItemModel> updateMenuItem(
      String itemId, Map<String, dynamic> updates) async {
    try {
      final data = await _supabase
          .from('menu_items')
          .update(updates)
          .eq('id', itemId)
          .select()
          .single();
      return MenuItemModel.fromJson(data);
    } catch (e) {
      throw AppException(parseSupabaseError(e));
    }
  }

  Future<void> deleteMenuItem(String itemId) async {
    try {
      await _supabase.from('menu_items').delete().eq('id', itemId);
    } catch (e) {
      throw AppException(parseSupabaseError(e));
    }
  }

  Future<String> uploadMenuImage(String storeId, File imageFile) async {
    try {
      final ext = imageFile.path.split('.').last;
      final fileName =
          'stores/$storeId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage
          .from('menu-images')
          .upload(fileName, imageFile);
      return _supabase.storage.from('menu-images').getPublicUrl(fileName);
    } catch (e) {
      throw AppException('Không thể tải ảnh lên: ${parseSupabaseError(e)}');
    }
  }

  Future<CategoryModel> createCategory(
      String storeId, String name, int displayOrder) async {
    try {
      final data = await _supabase
          .from('categories')
          .insert({
            'store_id': storeId,
            'name': name,
            'display_order': displayOrder,
          })
          .select()
          .single();
      return CategoryModel.fromJson(data);
    } catch (e) {
      throw AppException(parseSupabaseError(e));
    }
  }
}


