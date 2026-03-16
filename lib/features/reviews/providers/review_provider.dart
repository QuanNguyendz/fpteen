import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/review_model.dart';
import 'package:fpteen/data/repositories/review_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(supabaseClientProvider));
});

final myReviewForMenuItemProvider =
    FutureProvider.family.autoDispose<ReviewModel?, String>((ref, menuItemId) {
  return ref.watch(reviewRepositoryProvider).fetchMyReviewForMenuItem(menuItemId);
});

class UpsertReviewNotifier extends StateNotifier<AsyncValue<void>> {
  UpsertReviewNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> upsert({
    required String menuItemId,
    required String storeId,
    required int rating,
    String? content,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(reviewRepositoryProvider).upsertReview(
            menuItemId: menuItemId,
            storeId: storeId,
            rating: rating,
            content: content,
          );
      _ref.invalidate(myReviewForMenuItemProvider(menuItemId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final upsertReviewProvider =
    StateNotifierProvider.autoDispose<UpsertReviewNotifier, AsyncValue<void>>(
        (ref) => UpsertReviewNotifier(ref));

