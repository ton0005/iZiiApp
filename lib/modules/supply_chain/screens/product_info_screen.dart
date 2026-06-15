import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/localization/app_localizations.dart';
import 'edit_product_screen.dart';

class ProductInfoScreen extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductInfoScreen({super.key, required this.product});

  static const _knownCustomKeys = {'description', 'category', 'brand', 'specs'};

  String _formatPrice(dynamic price) {
    if (price is double) {
      if (price >= 1000000) {
        return '${(price / 1000000).toStringAsFixed(1)}M VNĐ';
      }
      return '${price.toStringAsFixed(0)} VNĐ';
    }
    return price?.toString() ?? '-';
  }

  String _buildShareText(Map<String, dynamic> product, BuildContext context) {
    final customFields =
        (product['custom_fields'] as Map<String, dynamic>?) ?? {};
    return '''${product['name'] ?? context.tr('inv_products_title')}
${context.tr('inv_price_label').replaceAll('{price}', _formatPrice(product['price']))}
${context.tr('inv_stock_quantity')}: ${product['stock']?.toString() ?? '0'}
${context.tr('inv_barcode_qr')}: ${product['barcode'] ?? '-'}
${context.tr('inv_category')}: ${customFields['category'] ?? '-'}
${context.tr('inv_brand')}: ${customFields['brand'] ?? '-'}
${context.tr('inv_description')}: ${customFields['description'] ?? '-'}''';
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customFields =
        (product['custom_fields'] as Map<String, dynamic>?) ?? {};
    final description = customFields['description']?.toString() ?? '-';
    final category = customFields['category']?.toString() ?? '-';
    final brand = customFields['brand']?.toString() ?? '-';
    final specs = customFields['specs']?.toString() ?? '-';
    final otherFields = customFields.entries
        .where((entry) => !_knownCustomKeys.contains(entry.key))
        .toList();
    final productName = product['name']?.toString() ?? 'Thông tin sản phẩm';
    final productCode = product['barcode']?.toString() ??
        product['sku']?.toString() ??
        product['id']?.toString() ??
        '';
    final imagePath = customFields['image_path']?.toString();
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('inv_product_info_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.tr('inv_back_tooltip'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: context.tr('inv_share_tooltip'),
            onPressed: () {
              Share.share(_buildShareText(product, context));
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: context.tr('inv_copy_code_tooltip'),
            onPressed: () {
              final codeToCopy = productCode.isNotEmpty
                  ? productCode
                  : context.tr('inv_no_code');
              Clipboard.setData(ClipboardData(text: codeToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context
                      .tr('inv_copied_code_msg')
                      .replaceAll('{code}', codeToCopy)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.tr('inv_edit_product_tooltip'),
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditProductScreen(product: product),
                ),
              );
              if (result == true && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(
                  File(imagePath),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220,
                    color: const Color(0xFFF8FAFC),
                    child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 48, color: Colors.grey)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF7DD3FC)),
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF22C55E).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product['stock']?.toString() == '0'
                              ? context.tr('inv_out_of_stock')
                              : context.tr('inv_in_stock').replaceAll('{count}',
                                  product['stock']?.toString() ?? '0'),
                          style: TextStyle(
                            color: product['stock']?.toString() == '0'
                                ? Colors.red
                                : const Color(0xFF16A34A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          productCode.isNotEmpty
                              ? productCode
                              : context.tr('inv_no_code'),
                          style: const TextStyle(
                            color: Color(0xFF0369A1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoBadge(
                          label: context.tr('inv_price_vnd'),
                          value: _formatPrice(product['price']),
                          icon: Icons.attach_money,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoBadge(
                          label: context.tr('inv_sku_label'),
                          value: product['sku']?.toString() ?? '-',
                          icon: Icons.receipt_long,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('inv_detailed_info'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoTile(context.tr('inv_description'), description),
                  _buildInfoTile(context.tr('inv_category'), category),
                  _buildInfoTile(context.tr('inv_brand'), brand),
                  _buildInfoTile(context.tr('inv_specs_short'), specs),
                  if (otherFields.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('inv_custom_fields'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...otherFields.map((entry) => _buildInfoTile(
                          entry.key,
                          entry.value?.toString() ?? '-',
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.edit),
              label: Text(context.tr('inv_edit_product_tooltip')),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditProductScreen(product: product),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
