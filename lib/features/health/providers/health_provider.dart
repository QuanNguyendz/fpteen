import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/health_profile_model.dart';
import 'package:fpteen/data/models/nutrition_log_model.dart';
import 'package:fpteen/data/repositories/health_repository.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

final healthProfileProvider = AsyncNotifierProvider<HealthProfileNotifier, HealthProfileModel?>(HealthProfileNotifier.new);

class HealthProfileNotifier extends AsyncNotifier<HealthProfileModel?> {
  @override
  Future<HealthProfileModel?> build() async {
    final userId = ref.watch(authNotifierProvider).user?.id;
    if (userId == null) return null;
    return ref.watch(healthRepositoryProvider).getHealthProfile(userId);
  }

  Future<void> saveProfile({
    required int height,
    required double weight,
    required String activityLevel,
    required String goal,
  }) async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null) return;

    // Tính BMR (sử dụng công thức Mifflin-St Jeor cơ bản cho nam giới do không có gender, hoặc average)
    // Nam: 10 * weight + 6.25 * height - 5 * 20 + 5
    // Trung bình nam nữ: 10*wg + 6.25*hg - 5*20 - 80
    double bmr = (10 * weight) + (6.25 * height) - (5 * 20) - 80;

    // Nhân với hệ số vận động
    double multiplier = 1.2;
    if (activityLevel == 'light') multiplier = 1.375;
    if (activityLevel == 'moderate') multiplier = 1.55;
    if (activityLevel == 'active') multiplier = 1.725;
    
    double tdee = bmr * multiplier;

    // Điều chỉnh theo mục tiêu
    if (goal == 'lose_weight') tdee -= 500;
    if (goal == 'gain_muscle') tdee += 500;

    int dailyCalorieTarget = tdee.round();
    if (dailyCalorieTarget < 1200) dailyCalorieTarget = 1200; // Mức tối thiểu an toàn

    final profile = HealthProfileModel(
      userId: userId,
      height: height,
      weight: weight,
      activityLevel: activityLevel,
      goal: goal,
      dailyCalorieTarget: dailyCalorieTarget,
      createdAt: DateTime.now(),
    );

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(healthRepositoryProvider).upsertHealthProfile(profile);
      return profile;
    });
  }
}

final todayNutritionLogProvider = FutureProvider.autoDispose<NutritionLogModel?>((ref) async {
  final userId = ref.watch(authNotifierProvider).user?.id;
  if (userId == null) return null;
  return ref.watch(healthRepositoryProvider).getNutritionLogToday(userId);
});
