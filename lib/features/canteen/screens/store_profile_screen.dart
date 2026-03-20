import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fpteen/data/models/store_model.dart';
import 'package:fpteen/features/home/providers/stores_provider.dart';
import 'package:fpteen/features/menu/providers/menu_provider.dart';

class StoreProfileScreen extends ConsumerStatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  ConsumerState<StoreProfileScreen> createState() =>
      _StoreProfileScreenState();
}

class _StoreProfileScreenState extends ConsumerState<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _slotSizeCtrl = TextEditingController();
  final _maxOrdersCtrl = TextEditingController();
  final _openingTimeCtrl = TextEditingController();
  final _closingTimeCtrl = TextEditingController();
  File? _logoFile;
  bool _isSaving = false;
  StoreModel? _store;
  final _picker = ImagePicker();

  TimeOfDay _openingTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStore());
  }

  TimeOfDay _parseTimeOfDay(String? value, {required TimeOfDay fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    // Expected DB format: "HH:mm:ss" (or at least "HH:mm")
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]) ?? fallback.hour;
    final m = int.tryParse(parts[1]) ?? fallback.minute;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTimeLabel(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatTimeDb(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _loadStore() async {
    final storeAsync = ref.read(myStoreProvider);
    storeAsync.whenData((store) {
      if (store != null && mounted) {
        setState(() {
          _store = store;
          _nameCtrl.text = store.name;
          _descCtrl.text = store.description ?? '';
          _addressCtrl.text = store.address ?? '';
          final slotSize = store.slotSizeMinutes ?? 15;
          final maxOrders = store.maxOrdersPerSlot ?? 20;
          _slotSizeCtrl.text = slotSize.toString();
          _maxOrdersCtrl.text = maxOrders.toString();

          _openingTime = _parseTimeOfDay(
            store.openingTime,
            fallback: const TimeOfDay(hour: 10, minute: 0),
          );
          _closingTime = _parseTimeOfDay(
            store.closingTime,
            fallback: const TimeOfDay(hour: 22, minute: 0),
          );
          _openingTimeCtrl.text = _formatTimeLabel(_openingTime);
          _closingTimeCtrl.text = _formatTimeLabel(_closingTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _slotSizeCtrl.dispose();
    _maxOrdersCtrl.dispose();
    _openingTimeCtrl.dispose();
    _closingTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
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
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _store == null) return;
    setState(() => _isSaving = true);

    try {
      String? logoUrl = _store!.logoUrl;

      if (_logoFile != null) {
        final menuRepo = ref.read(menuRepositoryProvider);
        logoUrl = await menuRepo.uploadMenuImage(_store!.id, _logoFile!);
      }

      final storeRepo = ref.read(storeRepositoryProvider);
      await storeRepo.updateStore(_store!.id, {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'logo_url': logoUrl,
        'slot_size_minutes': int.parse(_slotSizeCtrl.text.trim()),
        'max_orders_per_slot': int.parse(_maxOrdersCtrl.text.trim()),
        'opening_time': _formatTimeDb(_openingTime),
        'closing_time': _formatTimeDb(_closingTime),
      });

      ref.invalidate(myStoreProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật thông tin cửa hàng!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cửa hàng')),
      body: storeAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Lỗi tải thông tin: $e')),
        data: (store) {
          if (store == null) {
            return const Center(child: Text('Không tìm thấy cửa hàng.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickLogo,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _logoFile != null
                                ? FileImage(_logoFile!)
                                : (store.logoUrl != null
                                    ? NetworkImage(store.logoUrl!)
                                        as ImageProvider
                                    : null),
                            child: (_logoFile == null && store.logoUrl == null)
                                ? Icon(Icons.store,
                                    size: 48,
                                    color: Colors.grey.shade400)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên cửa hàng *',
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nhập tên cửa hàng'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả (tuỳ chọn)',
                      prefixIcon: Icon(Icons.notes_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ / Vị trí trong trường',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Công suất theo khung giờ',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _slotSizeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Slot size (phút)',
                            prefixIcon: Icon(Icons.schedule_outlined),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n <= 0) {
                              return 'Nhập số phút hợp lệ (>0)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxOrdersCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max đơn/slot',
                            prefixIcon: Icon(Icons.numbers_outlined),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n <= 0) {
                              return 'Nhập số đơn hợp lệ (>0)';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _openingTimeCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Giờ mở cửa',
                      prefixIcon: Icon(Icons.access_time_outlined),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _openingTime,
                      );
                      if (picked == null) return;
                      setState(() {
                        _openingTime = picked;
                        _openingTimeCtrl.text = _formatTimeLabel(_openingTime);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _closingTimeCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Giờ đóng cửa',
                      prefixIcon: Icon(Icons.access_time_outlined),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _closingTime,
                      );
                      if (picked == null) return;
                      setState(() {
                        _closingTime = picked;
                        _closingTimeCtrl.text = _formatTimeLabel(_closingTime);
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Lưu thay đổi'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
