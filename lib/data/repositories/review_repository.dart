import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/models/review_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewRepository {
  ReviewRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<ReviewModel?> fetchMyReviewForMenuItem(String menuItemId) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw const AppAuthException('Bạn cần đăng nhập.');
      final data = await _supabase
          .from('menu_item_reviews')
          .select()
          .eq('menu_item_id', menuItemId)
          .eq('reviewer_id', uid)
          .maybeSingle();
      return data == null ? null : ReviewModel.fromJson(data);
    } catch (e) {
      throw AppException(parseSupabaseError(e));
    }
  }

  Future<ReviewModel> upsertReview({
    required String menuItemId,
    required String storeId,
    required int rating,
    String? content,
  }) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw const AppAuthException('Bạn cần đăng nhập.');
      final payload = {
        'menu_item_id': menuItemId,
        'store_id': storeId,
        'reviewer_id': uid,
        'rating': rating,
        'content': content,
      };
      final data = await _supabase
          .from('menu_item_reviews')
          .upsert(payload, onConflict: 'menu_item_id,reviewer_id')
          .select()
          .single();
      return ReviewModel.fromJson(data);
    } catch (e) {
      throw AppException(parseSupabaseError(e));
    }
  }
}

