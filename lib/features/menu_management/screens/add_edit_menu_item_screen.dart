import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/features/menu_management/providers/menu_management_provider.dart';

class AddEditMenuItemScreen extends ConsumerStatefulWidget {
  const AddEditMenuItemScreen({super.key, required this.menuItem});
  final MenuItemModel? menuItem;

  @override
  ConsumerState<AddEditMenuItemScreen> createState() =>
      _AddEditMenuItemScreenState();
}

class _AddEditMenuItemScreenState
    extends ConsumerState<AddEditMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  late bool _isAvailable;
  File? _imageFile;
  final _picker = ImagePicker();

  bool get _isEditing => widget.menuItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.menuItem;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _priceCtrl = TextEditingController(
        text: item != null ? '${item.price}' : '');
    _descCtrl = TextEditingController(text: item?.description ?? '');
    _isAvailable = item?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final price = int.tryParse(_priceCtrl.text.replaceAll(',', '').trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá không hợp lệ')),
      );
      return;
    }

    final success = await ref.read(menuManagementProvider.notifier).saveItem(
          existing: widget.menuItem,
          name: _nameCtrl.text.trim(),
          price: price,
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          isAvailable: _isAvailable,
          imageFile: _imageFile,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_isEditing ? 'Cập nhật thành công!' : 'Thêm món thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(menuManagementProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa món ăn' : 'Thêm món ăn'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_imageFile!, fit: BoxFit.cover))
                      : widget.menuItem?.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(widget.menuItem!.imageUrl!,
                                  fit: BoxFit.cover))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 48,
                                    color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('Thêm ảnh món ăn',
                                    style: TextStyle(
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên món ăn *'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nhập tên món'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá (VNĐ) *',
                  prefixText: '₫ ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập giá';
                  final n = int.tryParse(v.replaceAll(',', '').trim());
                  if (n == null || n <= 0) return 'Giá không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Mô tả (tuỳ chọn)'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                title: const Text('Còn hàng'),
                subtitle: Text(_isAvailable
                    ? 'Hiển thị trong menu'
                    : 'Ẩn khỏi menu khách hàng'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: state.isSaving ? null : _save,
                child: state.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Lưu thay đổi' : 'Thêm món'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


