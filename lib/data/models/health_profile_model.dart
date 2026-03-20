class HealthProfileModel {
  const HealthProfileModel({
    required this.userId,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.goal,
    required this.dailyCalorieTarget,
    required this.createdAt,
  });

  final String userId;
  final int height;
  final double weight;
  final String activityLevel;
  final String goal;
  final int dailyCalorieTarget;
  final DateTime createdAt;

  factory HealthProfileModel.fromJson(Map<String, dynamic> json) => HealthProfileModel(
        userId: json['user_id'] as String,
        height: json['height'] as int,
        weight: (json['weight'] as num).toDouble(),
        activityLevel: json['activity_level'] as String? ?? 'moderate',
        goal: json['goal'] as String? ?? 'maintain',
        dailyCalorieTarget: json['daily_calorie_target'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'height': height,
        'weight': weight,
        'activity_level': activityLevel,
        'goal': goal,
        'daily_calorie_target': dailyCalorieTarget,
        'created_at': createdAt.toIso8601String(),
      };

  HealthProfileModel copyWith({
    int? height,
    double? weight,
    String? activityLevel,
    String? goal,
    int? dailyCalorieTarget,
  }) =>
      HealthProfileModel(
        userId: userId,
        height: height ?? this.height,
        weight: weight ?? this.weight,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
        dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
        createdAt: createdAt,
      );
}
