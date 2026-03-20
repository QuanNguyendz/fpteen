class NutritionLogModel {
  const NutritionLogModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.consumedCalories,
    this.latestAdvice,
  });

  final String id;
  final String userId;
  final DateTime date;
  final int consumedCalories;
  final String? latestAdvice;

  factory NutritionLogModel.fromJson(Map<String, dynamic> json) => NutritionLogModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        date: DateTime.parse(json['date'] as String),
        consumedCalories: json['consumed_calories'] as int? ?? 0,
        latestAdvice: json['latest_advice'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'consumed_calories': consumedCalories,
        'latest_advice': latestAdvice,
      };

  NutritionLogModel copyWith({
    int? consumedCalories,
    String? latestAdvice,
  }) =>
      NutritionLogModel(
        id: id,
        userId: userId,
        date: date,
        consumedCalories: consumedCalories ?? this.consumedCalories,
        latestAdvice: latestAdvice ?? this.latestAdvice,
      );
}
