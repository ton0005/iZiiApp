import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import 'barcode_scanner_screen.dart';
import '../bloc/inventory_bloc.dart';
import '../services/product_vision_service.dart';

class AddProductFromImageScreen extends StatefulWidget {
  final String? initialBarcode;
  const AddProductFromImageScreen({super.key, this.initialBarcode});

  @override
  State<AddProductFromImageScreen> createState() =>
      _AddProductFromImageScreenState();
}

class _AddProductFromImageScreenState extends State<AddProductFromImageScreen> {
  final _picker = ImagePicker();
  final _visionService = ProductVisionService();

  Uint8List? _imageBytes;
  String? _savedImagePath;
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
  late final TextEditingController _barcodeController;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.initialBarcode);
    if (widget.initialBarcode != null) {
      _result = ProductVisionResult(
        name: '',
        description: '',
        suggestedPrice: 0.0,
        category: '',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _specsController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final savedPath = await _saveImageToLocal(bytes, pickedFile.path);
        setState(() {
          _imageBytes = bytes;
          _savedImagePath = savedPath;
          _result = null;
          _error = null;
        });
        _analyzeImage(bytes, pickedFile.mimeType ?? 'image/jpeg');
      }
    } catch (e) {
      setState(() => _error =
          '${context.tr('inv_image_picked_error').replaceAll('{error}', '')} $e');
    }
  }

  Future<String?> _saveImageToLocal(Uint8List bytes, String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final extension =
          p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
      final fileName =
          'product_${const Uuid().v4()}.${extension.isNotEmpty ? extension : 'jpg'}';
      final filePath = p.join(imagesDir.path, fileName);
      final imageFile = File(filePath);
      await imageFile.writeAsBytes(bytes, flush: true);
      return imageFile.path;
    } catch (_) {
      return null;
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

  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(returnCode: true),
      ),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        _barcodeController.text = scannedCode;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty) {
      setState(() => _error = context.tr('inv_name_empty_error'));
      return;
    }

    final price = double.tryParse(
            _priceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
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
    if (_savedImagePath != null) {
      customFields['image_path'] = _savedImagePath;
    }

    final newProduct = {
      'id': const Uuid().v4(),
      'name': _nameController.text,
      'price': price,
      'stock': stock,
      'barcode':
          _barcodeController.text.isNotEmpty ? _barcodeController.text : null,
      'custom_fields': customFields,
    };

    try {
      await InventoryRepository().addProduct(newProduct);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context
              .tr('inv_product_added')
              .replaceAll('{name}', _nameController.text)),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context
              .tr('inv_error_adding')
              .replaceAll('{error}', e.toString())),
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
        title: Text(context.tr('inv_add_from_image_title')),
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
              _buildSectionHeader(context.tr('inv_ai_info_header')),
              const SizedBox(height: 12),
              _buildTextField(_nameController, context.tr('inv_product_name'),
                  Icons.label_outline),
              _buildTextField(
                _barcodeController,
                context.tr('inv_barcode_qr'),
                Icons.qr_code,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner,
                      color: Color(0xFF6366F1)),
                  tooltip: context.tr('inv_scanner_tooltip'),
                  onPressed: _scanBarcode,
                ),
              ),
              _buildTextField(_descController, context.tr('inv_description'),
                  Icons.description_outlined,
                  maxLines: 2),
              _buildTextField(_priceController, context.tr('inv_price_vnd'),
                  Icons.attach_money,
                  keyboardType: TextInputType.number),
              _buildTextField(_stockController,
                  context.tr('inv_stock_quantity'), Icons.inventory,
                  keyboardType: TextInputType.number),
              _buildTextField(_categoryController, context.tr('inv_category'),
                  Icons.category_outlined),
              _buildTextField(_brandController, context.tr('inv_brand'),
                  Icons.business_outlined),
              _buildTextField(_specsController, context.tr('inv_specs'),
                  Icons.settings_outlined,
                  maxLines: 2),
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
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
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('inv_picker_prompt'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('inv_ai_analyzing_prompt'),
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
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(context.tr('inv_camera')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(context.tr('inv_gallery')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
        border:
            Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('inv_ai_analyzing_status'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(context.tr('inv_ai_analyzing_details'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
        border:
            Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF43F5E)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFF43F5E)))),
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
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    Widget? suffixIcon,
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
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        label: Text(context.tr('inv_save_to_inventory'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
