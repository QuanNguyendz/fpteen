import 'dart:convert';
import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/core/errors/app_exception.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiRepository {
  AiRepository(this._supabase) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  final SupabaseClient _supabase;
  late final GenerativeModel _model;

  /// Phân tích và gọi Gemini trả về JSON danh sách món ăn đầy đủ chi tiết
  Future<List<Map<String, dynamic>>> getFoodRecommendation({
    required String customerId,
    required String contextText, // Bối cảnh: "Đang mưa, thèm ăn cay..."
  }) async {
    try {
      // 1. Fetch all available menu items
      final menuData = await _supabase
          .from('menu_items')
          .select('id, name, price, description, store_id, image_url, stores(name)')
          .eq('is_available', true);
          
      final List<dynamic> menuList = menuData as List<dynamic>;
      
      // Tạo một map để lookup thông tin nhanh khi AI trả về ID
      final Map<String, Map<String, dynamic>> menuMap = {};
      
      // Xây dựng chuỗi menu thu gọn cho AI
      final menuString = menuList.map((m) {
        final storeName = m['stores']?['name'] ?? '';
        menuMap[m['id'].toString()] = {
           'id': m['id'],
           'name': m['name'],
           'price': m['price'],
           'description': m['description'],
           'image_url': m['image_url'],
           'store_id': m['store_id'],
           'store_name': storeName,
        };
        return "- ID: ${m['id']}, Tên: ${m['name']}, Giá: ${m['price']}đ, Quán: $storeName${m['description'] != null ? ', Mô tả: ' + m['description'] : ''}";
      }).join('\n');

      // 2. Fetch user order history 
      final orderData = await _supabase
          .from('orders')
          .select('order_items(menu_items(name))')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .limit(10);

      final List<String> historyItems = [];
      for (var order in (orderData as List)) {
        final items = order['order_items'] as List;
        for (var item in items) {
          final menuItemName = item['menu_items']?['name'];
          if (menuItemName != null) {
            historyItems.add(menuItemName.toString());
          }
        }
      }
      
      final historyString = historyItems.isEmpty 
          ? "Người dùng mới, chưa từng đặt hàng." 
          : historyItems.toSet().join(', ');

      // 3. Build Prompt
      final prompt = '''
Bạn là một trợ lý ẩm thực thông minh của căng tin trường học (gồm nhiều quán). 
Dưới đây là Menu tổng hợp hiện đang mở bán: 
$menuString

Người dùng này trước đây hay ăn: $historyString.

Hiện tại người dùng mong muốn: "$contextText"

Hãy gợi ý cho người dùng 1 đến 5 món ăn phù hợp nhất. 
CHỈ TRẢ VỀ DỮ LIỆU JSON ĐÚNG ĐỊNH DẠNG là một mảng (array) các object chứa hai trường:
[
  {
    "id": "ID món ăn",
    "reason": "Lý do gợi ý ngắn gọn"
  }
]
''';

      // 4. Call Gemini
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final textResponse = response.text;
      if (textResponse == null || textResponse.isEmpty) {
        throw Exception("Không nhận được phản hồi từ AI");
      }

      // Xử lý textResponse có thể bị bọc bởi markdown
      String jsonStr = textResponse.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.replaceFirst('```json', '');
        if (jsonStr.endsWith('```')) {
           jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst('```', '');
        if (jsonStr.endsWith('```')) {
           jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
      }

      final List<dynamic> decoded = jsonDecode(jsonStr.trim());
      final List<Map<String, dynamic>> finalResults = [];
      
      for (var aiItem in decoded) {
        final String id = aiItem['id'].toString();
        final String reason = aiItem['reason'].toString();
        
        if (menuMap.containsKey(id)) {
           final Map<String, dynamic> fullDict = Map.from(menuMap[id]!);
           fullDict['reason'] = reason;
           finalResults.add(fullDict);
        }
      }
      
      return finalResults;

    } catch (e) {
      throw AppException("Lỗi AI: $e");
    }
  }
}
