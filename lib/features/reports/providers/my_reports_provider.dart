import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/report_model.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

final myReportsProvider =
    FutureProvider.autoDispose<List<ReportModel>>((ref) async {
  final userId = ref.watch(authNotifierProvider).user?.id;
  if (userId == null) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('reports')
      .select('*, stores(name)')
      .eq('reporter_id', userId)
      .order('created_at', ascending: false);

  return (data as List)
      .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

