import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.storeId, required this.storeName});
  final String storeId;
  final String storeName;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = ref.read(authNotifierProvider).user?.id;

      await supabase.from('reports').insert({
        'reporter_id': userId,
        'store_id': widget.storeId,
        'content': _contentCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Báo cáo đã được gửi. Cảm ơn bạn!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi báo cáo thất bại: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Báo cáo: ${widget.storeName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.report_outlined, size: 60, color: Colors.orange),
              const SizedBox(height: 12),
              Text(
                'Phản ánh về canteen',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Mô tả vấn đề bạn gặp phải. Chúng tôi sẽ xem xét trong thời gian sớm nhất.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _contentCtrl,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Nội dung báo cáo',
                  hintText: 'Mô tả chi tiết vấn đề...',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập nội dung';
                  if (v.trim().length < 10) return 'Tối thiểu 10 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Gửi báo cáo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


