import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreRepository {
  StoreRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<StoreModel>> fetchActiveStores() async {
    try {
      final data = await _supabase
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('name');
      return (data as List).map((e) => StoreModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw StoreException(parseSupabaseError(e));
    }
  }

  Future<StoreModel?> fetchStoreByOwnerId(String ownerId) async {
    try {
      final data = await _supabase
          .from('stores')
          .select()
          .eq('owner_id', ownerId)
          .maybeSingle();
      return data == null ? null : StoreModel.fromJson(data);
    } catch (e) {
      throw StoreException(parseSupabaseError(e));
    }
  }

  Future<StoreModel> fetchStore(String storeId) async {
    try {
      final data = await _supabase.from('stores').select().eq('id', storeId).single();
      return StoreModel.fromJson(data);
    } catch (e) {
      throw StoreException(parseSupabaseError(e));
    }
  }

  Future<StoreModel> updateStore(String storeId, Map<String, dynamic> updates) async {
    try {
      final data = await _supabase
          .from('stores')
          .update(updates)
          .eq('id', storeId)
          .select()
          .single();
      return StoreModel.fromJson(data);
    } catch (e) {
      throw StoreException(parseSupabaseError(e));
    }
  }
}


