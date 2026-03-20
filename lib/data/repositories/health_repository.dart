import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/health_profile_model.dart';
import 'package:fpteen/data/models/nutrition_log_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(Supabase.instance.client);
});

class HealthRepository {
  HealthRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<HealthProfileModel?> getHealthProfile(String userId) async {
    final response = await _supabase
        .from('user_health_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return HealthProfileModel.fromJson(response);
  }

  Future<void> upsertHealthProfile(HealthProfileModel profile) async {
    await _supabase.from('user_health_profiles').upsert(profile.toJson());
  }

  Future<NutritionLogModel?> getNutritionLogToday(String userId) async {
    final today = DateTime.now();
    final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final response = await _supabase
        .from('daily_nutrition_logs')
        .select()
        .eq('user_id', userId)
        .eq('date', dateStr)
        .maybeSingle();

    if (response == null) return null;
    return NutritionLogModel.fromJson(response);
  }

  Future<void> logCalories(String userId, int addedCalories, String advice) async {
    final today = DateTime.now();
    final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final existingLog = await getNutritionLogToday(userId);

    if (existingLog != null) {
      await _supabase.from('daily_nutrition_logs').update({
        'consumed_calories': existingLog.consumedCalories + addedCalories,
        'latest_advice': advice,
      }).eq('id', existingLog.id);
    } else {
      await _supabase.from('daily_nutrition_logs').insert({
        'user_id': userId,
        'date': dateStr,
        'consumed_calories': addedCalories,
        'latest_advice': advice,
      });
    }
  }
}
