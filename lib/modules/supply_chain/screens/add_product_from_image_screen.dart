import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../bloc/inventory_bloc.dart';
import '../services/product_vision_service.dart';

class AddProductFromImageScreen extends StatefulWidget {
  const AddProductFromImageScreen({super.key});

  @override
  State<AddProductFromImageScreen> createState() => _AddProductFromImageScreenState();
}

class _AddProductFromImageScreenState extends State<AddProductFromImageScreen> {
  final _picker = ImagePicker();
  final _visionService = ProductVisionService();
  
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  ProductVisionResult? _result;
  String? _error;

  // Editable controllers (populated after AI analysis)
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '1');
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _specsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _specsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _result = null;
          _error = null;
        });
        _analyzeImage(bytes, pickedFile.mimeType ?? 'image/jpeg');
      }
    } catch (e) {
      setState(() => _error = 'Lỗi chọn ảnh: $e');
    }
  }

  Future<void> _analyzeImage(Uint8List bytes, String mimeType) async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final result = await _visionService.analyzeProductImage(bytes, mimeType);
      setState(() {
        _result = result;
        _isAnalyzing = false;
        _nameController.text = result.name;
        _descController.text = result.description;
        _priceController.text = result.suggestedPrice.toStringAsFixed(0);
        _categoryController.text = result.category;
        _brandController.text = result.brand ?? '';
        _specsController.text = result.specs ?? '';
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty) {
      setState(() => _error = 'Tên sản phẩm không được để trống');
      return;
    }

    final price = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final stock = int.tryParse(_stockController.text) ?? 1;

    // Build custom fields from AI-detected extra fields
    final customFields = <String, dynamic>{};
    if (_descController.text.isNotEmpty) {
      customFields['description'] = _descController.text;
    }
    if (_categoryController.text.isNotEmpty) {
      customFields['category'] = _categoryController.text;
    }
    if (_brandController.text.isNotEmpty) {
      customFields['brand'] = _brandController.text;
    }
    if (_specsController.text.isNotEmpty) {
      customFields['specs'] = _specsController.text;
    }

    final newProduct = {
      'id': const Uuid().v4(),
      'name': _nameController.text,
      'price': price,
      'stock': stock,
      'custom_fields': customFields,
    };

    try {
      await InventoryRepository().addProduct(newProduct);
      
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm sản phẩm "${_nameController.text}" vào kho!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thêm sản phẩm: $e'),
          backgroundColor: const Color(0xFFF43F5E),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm SP từ Hình ảnh'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Image Picker Area ---
            _buildImagePickerSection(),
            const SizedBox(height: 16),

            // --- Analysis Status ---
            if (_isAnalyzing) _buildAnalyzingIndicator(),
            if (_error != null) _buildErrorBanner(),

            // --- AI Results Form ---
            if (_result != null) ...[
              _buildSectionHeader('Thông tin AI nhận diện (chỉnh sửa được)'),
              const SizedBox(height: 12),
              _buildTextField(_nameController, 'Tên sản phẩm', Icons.label_outline),
              _buildTextField(_descController, 'Mô tả', Icons.description_outlined, maxLines: 2),
              _buildTextField(_priceController, 'Giá (VNĐ)', Icons.attach_money, keyboardType: TextInputType.number),
              _buildTextField(_stockController, 'Số lượng tồn kho', Icons.inventory, keyboardType: TextInputType.number),
              _buildTextField(_categoryController, 'Danh mục', Icons.category_outlined),
              _buildTextField(_brandController, 'Thương hiệu', Icons.business_outlined),
              _buildTextField(_specsController, 'Thông số kỹ thuật', Icons.settings_outlined, maxLines: 2),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6366F1).withValues(alpha: 0.05),
            const Color(0xFF06B6D4).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        children: [
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.memory(
                _imageBytes!,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Chụp ảnh hoặc chọn ảnh sản phẩm',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI sẽ tự động nhận diện thông tin',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI đang phân tích hình ảnh...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('Nhận diện sản phẩm, giá, thương hiệu...', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF43F5E)),
          const SizedBox(width: 12),
          Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFF43F5E)))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _saveProduct,
        icon: const Icon(Icons.save_alt_rounded, size: 22),
        label: const Text('Lưu vào Kho', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
