import 'package:flutter/material.dart';
import '../bloc/inventory_bloc.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;

  // Custom field controllers
  late TextEditingController _descController;
  late TextEditingController _categoryController;
  late TextEditingController _brandController;
  late TextEditingController _specsController;

  // Dynamic custom fields (beyond the known ones)
  final Map<String, TextEditingController> _extraFieldControllers = {};
  final _newFieldKeyController = TextEditingController();
  final _newFieldValueController = TextEditingController();

  // Known custom field keys (displayed with dedicated UI)
  static const _knownCustomKeys = {'description', 'category', 'brand', 'specs'};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product['name']);
    _priceController = TextEditingController(text: widget.product['price'].toString());
    _stockController = TextEditingController(text: widget.product['stock'].toString());

    // Load custom fields
    final customFields = widget.product['custom_fields'] as Map<String, dynamic>? ?? {};
    _descController = TextEditingController(text: customFields['description'] ?? '');
    _categoryController = TextEditingController(text: customFields['category'] ?? '');
    _brandController = TextEditingController(text: customFields['brand'] ?? '');
    _specsController = TextEditingController(text: customFields['specs'] ?? '');

    // Load extra (unknown) custom fields
    for (final entry in customFields.entries) {
      if (!_knownCustomKeys.contains(entry.key)) {
        _extraFieldControllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _specsController.dispose();
    _newFieldKeyController.dispose();
    _newFieldValueController.dispose();
    for (final c in _extraFieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCustomField() {
    final key = _newFieldKeyController.text.trim();
    final value = _newFieldValueController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _extraFieldControllers[key] = TextEditingController(text: value);
      _newFieldKeyController.clear();
      _newFieldValueController.clear();
    });
  }

  void _removeCustomField(String key) {
    setState(() {
      _extraFieldControllers[key]?.dispose();
      _extraFieldControllers.remove(key);
    });
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên sản phẩm không được để trống')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final stock = int.tryParse(_stockController.text) ?? 0;

    // Build custom fields
    final customFields = <String, dynamic>{};
    if (_descController.text.isNotEmpty) customFields['description'] = _descController.text;
    if (_categoryController.text.isNotEmpty) customFields['category'] = _categoryController.text;
    if (_brandController.text.isNotEmpty) customFields['brand'] = _brandController.text;
    if (_specsController.text.isNotEmpty) customFields['specs'] = _specsController.text;
    for (final entry in _extraFieldControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        customFields[entry.key] = entry.value.text;
      }
    }

    final updatedProduct = {
      ...widget.product,
      'name': _nameController.text,
      'price': price,
      'stock': stock,
      'custom_fields': customFields,
    };

    try {
      await InventoryRepository().updateProduct(updatedProduct);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật sản phẩm "${_nameController.text}"!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật: $e'),
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
        title: const Text('Chỉnh sửa Sản phẩm'),
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
            _buildSectionHeader('Thông tin cơ bản'),
            const SizedBox(height: 12),
            _buildTextField(_nameController, 'Tên sản phẩm', Icons.label_outline),
            _buildTextField(_priceController, 'Giá (VNĐ)', Icons.attach_money, keyboardType: TextInputType.number),
            _buildTextField(_stockController, 'Số lượng tồn kho', Icons.inventory, keyboardType: TextInputType.number),

            const SizedBox(height: 20),
            _buildSectionHeader('Thông tin mở rộng'),
            const SizedBox(height: 12),
            _buildTextField(_descController, 'Mô tả', Icons.description_outlined, maxLines: 2),
            _buildTextField(_categoryController, 'Danh mục', Icons.category_outlined),
            _buildTextField(_brandController, 'Thương hiệu', Icons.business_outlined),
            _buildTextField(_specsController, 'Thông số kỹ thuật', Icons.settings_outlined, maxLines: 2),

            // --- Extra custom fields ---
            if (_extraFieldControllers.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionHeader('Trường tuỳ chỉnh'),
              const SizedBox(height: 12),
              ..._extraFieldControllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          entry.value,
                          entry.key,
                          Icons.tune_rounded,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFF43F5E)),
                        onPressed: () => _removeCustomField(entry.key),
                        tooltip: 'Xoá trường',
                      ),
                    ],
                  ),
                );
              }),
            ],

            // --- Add new custom field ---
            const SizedBox(height: 16),
            _buildSectionHeader('Thêm trường mới'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(_newFieldKeyController, 'Tên trường', Icons.vpn_key_outlined),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildTextField(_newFieldValueController, 'Giá trị', Icons.text_fields),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    onPressed: _addCustomField,
                    tooltip: 'Thêm trường',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
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
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
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
        label: const Text('Lưu thay đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
