import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/features/health/providers/health_provider.dart';
import 'package:go_router/go_router.dart';

class HealthSummaryCard extends ConsumerWidget {
  const HealthSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(healthProfileProvider);
    final logAsync = ref.watch(todayNutritionLogProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) {
          return _buildRequireSetupCard(context);
        }

        return logAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const SizedBox.shrink(),
          data: (log) {
            final consumed = log?.consumedCalories ?? 0;
            final advice = log?.latestAdvice ?? "Tuyệt vời! Hôm nay bạn chưa măm măm món gì bị dư thừa Calo.";
            final target = profile.dailyCalorieTarget;
            final progress = (consumed / target).clamp(0.0, 1.0);
            
            final isOver = consumed > target;

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.monitor_heart_outlined, color: Colors.teal.shade600, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Nhật ký Calo AI',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => context.push('/home/health-profile'),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Cập nhật', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã nạp hôm nay',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$consumed',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isOver ? Colors.red.shade700 : Colors.teal.shade700),
                                  ),
                                  TextSpan(
                                    text: ' / $target Kcal',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                                  ),
                                ]
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profile.goal == 'lose_weight' ? 'Giảm mỡ' : profile.goal == 'gain_muscle' ? 'Tăng cơ' : 'Giữ dáng',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Custom Gradient Progress Bar
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: isOver 
                                  ? [Colors.red.shade300, Colors.red.shade600] 
                                  : [Colors.teal.shade300, Colors.tealAccent.shade700],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isOver ? Colors.red : Colors.teal).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // AI Advice Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOver ? Colors.red.shade50 : Colors.amber.shade50.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isOver ? Colors.red.shade100 : Colors.amber.shade200.withOpacity(0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isOver ? Icons.warning_amber_rounded : Icons.auto_awesome, 
                            color: isOver ? Colors.red.shade600 : Colors.amber.shade600, 
                            size: 18
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              advice,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: isOver ? Colors.red.shade800 : Colors.brown.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequireSetupCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: const CircleAvatar(
          backgroundColor: Colors.teal,
          child: Icon(Icons.monitor_weight, color: Colors.white),
        ),
        title: const Text('Bật Theo Dõi Dinh Dưỡng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: const Text('Cập nhật số đo để AI tính calo.', style: TextStyle(fontSize: 12)),
        trailing: FilledButton(
          onPressed: () => context.push('/home/health-profile'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          child: const Text('Bật'),
        ),
      ),
    );
  }
}
