
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/features/ai_assistant/providers/ai_provider.dart';
import 'package:fpteen/features/auth/providers/auth_provider.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fpteen/data/models/menu_item_model.dart';
import 'package:fpteen/features/menu/providers/cart_provider.dart';
import 'package:intl/intl.dart';

final _vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final customerId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập trước!')),
      );
      return;
    }

    ref.read(aiRecommendationProvider.notifier).getRecommendations(
      customerId: customerId,
      contextText: text,
    );
    // Xoá text sau khi gửi & Đóng bàn phím
    _textController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recommendationsState = ref.watch(aiRecommendationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý Ẩm thực AI'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Phần nội dung rỗng (Welcome) hoặc Kết quả (List)
          Expanded(
            child: recommendationsState.when(
              data: (list) {
                if (list.isEmpty) {
                  return _buildWelcomeState(theme);
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final price = item['price'] as int? ?? 0;
                    final imageUrl = item['image_url'] as String?;
                    final storeName = item['store_name']?.toString() ?? 'Cửa hàng';

                    return Card(
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail hình vuông
                                if (imageUrl != null && imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      height: 110,
                                      width: 110,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        height: 110,
                                        width: 110,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.restaurant, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                if (imageUrl != null && imageUrl.isNotEmpty)
                                  const SizedBox(width: 16),
                                
                                // Cột thông tin bên phải
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 12),
                                            const SizedBox(width: 4),
                                            Text('AI Đề xuất', style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['name'] ?? 'Món ăn',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.2),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _vndFormat.format(price),
                                        style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary, fontSize: 15),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.storefront, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              storeName, 
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.secondaryContainer),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💡', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item['reason'] ?? '',
                                      style: TextStyle(color: theme.colorScheme.onSecondaryContainer, height: 1.4, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  final mItem = MenuItemModel(
                                    id: item['id'].toString(),
                                    storeId: item['store_id'].toString(),
                                    name: item['name'].toString(),
                                    price: price,
                                    isAvailable: true,
                                    createdAt: DateTime.now(),
                                    imageUrl: imageUrl,
                                  );
                                  ref.read(cartProvider.notifier).addItem(mItem, mItem.storeId);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Đã thêm ${mItem.name} vào giỏ hàng!'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_shopping_cart, size: 18),
                                label: const Text('Thêm vào giỏ', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              error: (error, __) => _buildErrorState(error.toString()),
              loading: () => _buildLoadingState(theme),
            ),
          ),
          
          // Thanh Chat ở đáy màn hình
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'VD: Đang mưa, buồn ngủ...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _submitRequest(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _submitRequest,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    tooltip: 'Gửi',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, size: 60, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Hôm nay bạn muốn ăn gì?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Chỉ cần chia sẻ cảm xúc, AI sẽ tìm món ăn hoàn hảo nhất dành cho bạn!',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Gợi ý nhanh:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickChip('🔥 Nóng nực', 'Trời đang rất nóng, thèm đồ mát lạnh giải nhiệt'),
              _buildQuickChip('🌧️ Đang mưa', 'Trời đang mưa, thèm đồ ăn ấm bụng và cay cay'),
              _buildQuickChip('🏃 Đang vội', 'Đang vội lên lớp, hãy gợi ý món làm nhanh'),
              _buildQuickChip('💆 Xả stress', 'Muốn ăn đồ ngọt ngào để xả stress sau khi thi'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Gemini đang phân tích thực đơn...',
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Có lỗi xảy ra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, String contextText) {
    final theme = Theme.of(context);
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
      backgroundColor: theme.colorScheme.secondaryContainer,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      onPressed: () {
        _textController.text = contextText;
        _submitRequest();
      },
    );
  }
}
