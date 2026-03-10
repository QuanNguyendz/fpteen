import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fpteen/features/admin/providers/admin_provider.dart';

class CreateStoreOwnerScreen extends ConsumerStatefulWidget {
  const CreateStoreOwnerScreen({super.key});

  @override
  ConsumerState<CreateStoreOwnerScreen> createState() =>
      _CreateStoreOwnerScreenState();
}

class _CreateStoreOwnerScreenState
    extends ConsumerState<CreateStoreOwnerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _storeDescCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _storeNameCtrl.dispose();
    _storeDescCtrl.dispose();
    _storeAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(createStoreOwnerProvider.notifier).create(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: _fullNameCtrl.text.trim(),
          storeName: _storeNameCtrl.text.trim(),
          storeDescription: _storeDescCtrl.text.trim().isEmpty
              ? null
              : _storeDescCtrl.text.trim(),
          storeAddress: _storeAddressCtrl.text.trim().isEmpty
              ? null
              : _storeAddressCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createStoreOwnerProvider);
    final theme = Theme.of(context);

    ref.listen(createStoreOwnerProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        ref.read(createStoreOwnerProvider.notifier).reset();
      }
      if (next.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo tài khoản canteen thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản Canteen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Account info section
              _SectionHeader(
                  icon: Icons.person_outline,
                  title: 'Thông tin tài khoản'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Họ tên chủ canteen *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nhập họ tên'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email đăng nhập *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập email';
                  if (!v.contains('@')) return 'Email không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Nhập mật khẩu';
                  if (v.length < 6) return 'Tối thiểu 6 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Store info section
              _SectionHeader(
                  icon: Icons.store_outlined,
                  title: 'Thông tin Canteen'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _storeNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Tên canteen *',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nhập tên canteen'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _storeDescCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (tuỳ chọn)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _storeAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ / Vị trí trong trường (tuỳ chọn)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Tạo tài khoản & Canteen'),
              ),
              const SizedBox(height: 12),
              Text(
                'Tài khoản sẽ được tạo ngay lập tức và chủ canteen có thể đăng nhập bằng email/mật khẩu này.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
