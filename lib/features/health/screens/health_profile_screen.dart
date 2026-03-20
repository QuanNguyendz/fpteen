import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/features/health/providers/health_provider.dart';
import 'package:go_router/go_router.dart';

class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  ConsumerState<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _activityLevel = 'moderate';
  String _goal = 'maintain';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(healthProfileProvider).valueOrNull;
      if (profile != null) {
        _heightCtrl.text = profile.height.toString();
        _weightCtrl.text = profile.weight.toString();
        _activityLevel = profile.activityLevel;
        _goal = profile.goal;
        setState(() {});
      }
    });
  }

  void _save() async {
    final h = int.tryParse(_heightCtrl.text);
    final w = double.tryParse(_weightCtrl.text);

    if (h == null || h <= 0 || w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập chiều cao, cân nặng hợp lệ')));
      return;
    }

    setState(() => _isLoading = true);
    await ref.read(healthProfileProvider.notifier).saveProfile(
      height: h,
      weight: w,
      activityLevel: _activityLevel,
      goal: _goal,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ sức khỏe!')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ Sức khỏe AI')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xây dựng hồ sơ',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Để AI có thể tính toán lượng Calo chính xác nhất cho bạn.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _heightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Chiều cao (cm)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.height),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cân nặng (kg)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monitor_weight_outlined),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Mức độ vận động', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _activityLevel,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'light', child: Text('Ít vận động (Chỉ ngồi học)')),
                DropdownMenuItem(value: 'moderate', child: Text('Vận động vừa (Tập thể dục 3-5 ngày/tuần)')),
                DropdownMenuItem(value: 'active', child: Text('Vận động nhiều (Chơi thể thao hàng ngày)')),
              ],
              onChanged: (v) => setState(() => _activityLevel = v!),
            ),
            const SizedBox(height: 24),
            const Text('Mục tiêu của bạn', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _goal,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'lose_weight', child: Text('Giảm cân, giảm mỡ')),
                DropdownMenuItem(value: 'maintain', child: Text('Giữ dáng cân đối')),
                DropdownMenuItem(value: 'gain_muscle', child: Text('Tăng cân, tăng cơ')),
              ],
              onChanged: (v) => setState(() => _goal = v!),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Lưu & Bắt đầu theo dõi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
