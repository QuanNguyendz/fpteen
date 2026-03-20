import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/repositories/ai_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fpteen/features/auth/providers/auth_provider.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(supabaseClientProvider));
});

final aiRecommendationProvider = StateNotifierProvider<AiRecommendationNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return AiRecommendationNotifier(ref.watch(aiRepositoryProvider));
});

class AiRecommendationNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  AiRecommendationNotifier(this._repository) : super(const AsyncValue.data([]));

  final AiRepository _repository;

  Future<void> getRecommendations({
    required String customerId,
    required String contextText,
  }) async {
    state = const AsyncValue.loading();
    try {
      final results = await _repository.getFoodRecommendation(
        customerId: customerId,
        contextText: contextText,
      );
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
