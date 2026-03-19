import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

class StoreAnalytics {
  const StoreAnalytics({
    required this.revenueByMonth,
    required this.bestSellers,
    required this.ratingStats,
  });

  final List<Map<String, dynamic>> revenueByMonth;
  final List<Map<String, dynamic>> bestSellers;
  final Map<String, dynamic> ratingStats;
}

final storeAnalyticsProvider =
    FutureProvider.autoDispose<StoreAnalytics>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final myStore = await supabase
      .from('stores')
      .select('id')
      .eq('owner_id', supabase.auth.currentUser!.id)
      .maybeSingle();

  if (myStore == null) {
    return const StoreAnalytics(
      revenueByMonth: [],
      bestSellers: [],
      ratingStats: {},
    );
  }

  final storeId = myStore['id'] as String;

  final results = await Future.wait([
    supabase.rpc('get_store_revenue_by_month', params: {'p_store_id': storeId}),
    supabase.rpc('get_store_best_sellers', params: {'p_store_id': storeId}),
    supabase.rpc('get_store_rating_stats', params: {'p_store_id': storeId}),
  ]);

  return StoreAnalytics(
    revenueByMonth: (results[0] as List).cast<Map<String, dynamic>>(),
    bestSellers: (results[1] as List).cast<Map<String, dynamic>>(),
    ratingStats:
        (results[2] as List).isEmpty ? {} : (results[2] as List).first,
  );
});

