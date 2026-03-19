import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

/// Aggregated rating for a store (from `menu_item_reviews` via RPC).
class StoreRatingStats {
  const StoreRatingStats({
    required this.avgRating,
    required this.ratingCount,
    required this.star1,
    required this.star2,
    required this.star3,
    required this.star4,
    required this.star5,
  });

  final double avgRating;
  final int ratingCount;
  final int star1;
  final int star2;
  final int star3;
  final int star4;
  final int star5;

  int starCount(int star) {
    switch (star) {
      case 1:
        return star1;
      case 2:
        return star2;
      case 3:
        return star3;
      case 4:
        return star4;
      case 5:
        return star5;
      default:
        return 0;
    }
  }
}

/// One review row for display (no reviewer name — RLS may hide users).
class StoreReviewItem {
  const StoreReviewItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.rating,
    this.content,
    required this.createdAt,
  });

  final String menuItemId;
  final String menuItemName;
  final int rating;
  final String? content;
  final DateTime createdAt;
}

/// Full payload for [StoreFeedbackScreen].
class StoreFeedbackScreenData {
  const StoreFeedbackScreenData({
    required this.stats,
    required this.reviews,
  });

  final StoreRatingStats stats;
  final List<StoreReviewItem> reviews;
}

final storeRatingStatsProvider =
    FutureProvider.family.autoDispose<StoreRatingStats, String>((ref, storeId) async {
  if (storeId.isEmpty) {
    return const StoreRatingStats(
      avgRating: 0,
      ratingCount: 0,
      star1: 0,
      star2: 0,
      star3: 0,
      star4: 0,
      star5: 0,
    );
  }
  final supabase = ref.watch(supabaseClientProvider);
  final raw = await supabase.rpc(
    'get_store_rating_stats',
    params: {'p_store_id': storeId},
  );
  final list = raw as List<dynamic>;
  if (list.isEmpty) {
    return const StoreRatingStats(
      avgRating: 0,
      ratingCount: 0,
      star1: 0,
      star2: 0,
      star3: 0,
      star4: 0,
      star5: 0,
    );
  }
  final row = list.first as Map<String, dynamic>;
  return StoreRatingStats(
    avgRating: (row['avg_rating'] as num?)?.toDouble() ?? 0,
    ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
    star1: (row['star_1'] as num?)?.toInt() ?? 0,
    star2: (row['star_2'] as num?)?.toInt() ?? 0,
    star3: (row['star_3'] as num?)?.toInt() ?? 0,
    star4: (row['star_4'] as num?)?.toInt() ?? 0,
    star5: (row['star_5'] as num?)?.toInt() ?? 0,
  );
});

final storeFeedbackReviewsProvider =
    FutureProvider.family.autoDispose<List<StoreReviewItem>, String>((ref, storeId) async {
  if (storeId.isEmpty) return [];
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('menu_item_reviews')
      .select(
        'rating, content, created_at, menu_item_id, menu_items(name)',
      )
      .eq('store_id', storeId)
      .order('created_at', ascending: false)
      .limit(30);

  final rows = data as List<dynamic>;
  return rows.map((e) {
    final m = e as Map<String, dynamic>;
    final mi = m['menu_items'] as Map<String, dynamic>?;
    final name = mi?['name'] as String? ?? 'Món ăn';
    return StoreReviewItem(
      menuItemId: (m['menu_item_id'] as String?) ?? '',
      menuItemName: name,
      rating: (m['rating'] as num).toInt(),
      content: m['content'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }).toList();
});

/// Single load for feedback screen (stats + reviews).
final storeFeedbackScreenDataProvider =
    FutureProvider.family.autoDispose<StoreFeedbackScreenData, String>((ref, storeId) async {
  final stats = await ref.watch(storeRatingStatsProvider(storeId).future);
  final reviews = await ref.watch(storeFeedbackReviewsProvider(storeId).future);
  return StoreFeedbackScreenData(stats: stats, reviews: reviews);
});
