import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/settings/settings_service.dart';

class ProductVisionResult {
  final String name;
  final String description;
  final double suggestedPrice;
  final String category;
  final int suggestedStock;
  final String? brand;
  final String? specs;

  ProductVisionResult({
    required this.name,
    required this.description,
    required this.suggestedPrice,
    required this.category,
    this.suggestedStock = 1,
    this.brand,
    this.specs,
  });
}

class ProductVisionService {
  static final ProductVisionService _instance = ProductVisionService._internal();
  factory ProductVisionService() => _instance;
  ProductVisionService._internal();

  /// Analyze a product image using Gemini Vision
  Future<ProductVisionResult> analyzeProductImage(Uint8List imageBytes, String mimeType) async {
    final settingsService = SettingsService();
    final apiKey = await settingsService.getGeminiApiKey();
    
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Chưa cấu hình API Key. Vui lòng vào Cài đặt để nhập Gemini API Key.');
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );

    final prompt = '''Phân tích hình ảnh sản phẩm này và trả về thông tin dưới dạng JSON thuần túy (không có markdown, không có ```json```).

Trả về ĐÚNG định dạng sau:
{"name": "Tên sản phẩm đầy đủ", "description": "Mô tả ngắn gọn về sản phẩm", "suggested_price": 0, "category": "Danh mục", "brand": "Thương hiệu", "specs": "Thông số kỹ thuật chính"}

Quy tắc:
- name: Tên sản phẩm bằng tiếng Việt hoặc tiếng Anh tùy theo sản phẩm
- description: Mô tả 1-2 câu bằng tiếng Việt
- suggested_price: Giá ước lượng bằng VNĐ (chỉ số, không có ký tự)
- category: Một trong các danh mục: Điện thoại, Laptop, Máy tính bảng, Phụ kiện, Linh kiện, Đồ gia dụng, Thực phẩm, Thời trang, Khác
- brand: Thương hiệu nếu nhận diện được
- specs: Thông số kỹ thuật chính nếu có

CHỈ TRẢ VỀ JSON THUẦN TÚY, KHÔNG CÓ GÌ KHÁC.''';

    final content = Content.multi([
      TextPart(prompt),
      DataPart(mimeType, imageBytes),
    ]);

    final response = await model.generateContent([content]);
    final text = response.text ?? '';
    
    return _parseResponse(text);
  }

  ProductVisionResult _parseResponse(String text) {
    try {
      // Clean up the response - remove markdown code blocks if present
      String cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // Simple manual JSON parsing to avoid dart:convert issues on web
      final name = _extractJsonString(cleaned, 'name') ?? 'Sản phẩm không xác định';
      final description = _extractJsonString(cleaned, 'description') ?? 'Không có mô tả';
      final priceStr = _extractJsonValue(cleaned, 'suggested_price');
      final category = _extractJsonString(cleaned, 'category') ?? 'Khác';
      final brand = _extractJsonString(cleaned, 'brand');
      final specs = _extractJsonString(cleaned, 'specs');

      double price = 0;
      if (priceStr != null) {
        price = double.tryParse(priceStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      }

      return ProductVisionResult(
        name: name,
        description: description,
        suggestedPrice: price,
        category: category,
        brand: brand,
        specs: specs,
      );
    } catch (e) {
      print('[ProductVisionService] Parse error: $e, raw: $text');
      return ProductVisionResult(
        name: 'Sản phẩm từ ảnh',
        description: text.length > 100 ? text.substring(0, 100) : text,
        suggestedPrice: 0,
        category: 'Khác',
      );
    }
  }

  String? _extractJsonString(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*"([^"]*)"');
    final match = pattern.firstMatch(json);
    return match?.group(1);
  }

  String? _extractJsonValue(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*([^,}]+)');
    final match = pattern.firstMatch(json);
    return match?.group(1)?.trim();
  }
}
