import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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

  String _buildShareText(Map<String, dynamic> product) {
    final customFields =
        (product['custom_fields'] as Map<String, dynamic>?) ?? {};
    return '''${product['name'] ?? 'Sản phẩm'}
Giá: ${_formatPrice(product['price'])}
Tồn kho: ${product['stock']?.toString() ?? '0'}
Mã vạch: ${product['barcode'] ?? '-'}
Danh mục: ${customFields['category'] ?? '-'}
Thương hiệu: ${customFields['brand'] ?? '-'}
Mô tả: ${customFields['description'] ?? '-'}''';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin sản phẩm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Chia sẻ',
            onPressed: () {
              Share.share(_buildShareText(product));
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Sao chép mã',
            onPressed: () {
              final codeToCopy =
                  productCode.isNotEmpty ? productCode : 'Không có mã';
              Clipboard.setData(ClipboardData(text: codeToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã sao chép: $codeToCopy'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa',
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
                          color: const Color(0xFF22C55E).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product['stock']?.toString() == '0'
                              ? 'Hết hàng'
                              : 'Còn ${product['stock']?.toString() ?? '0'}',
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
                          color: const Color(0xFF0284C7).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          productCode.isNotEmpty ? productCode : 'Không có mã',
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
                          label: 'Giá',
                          value: _formatPrice(product['price']),
                          icon: Icons.attach_money,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoBadge(
                          label: 'Mã hàng',
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
            const Text(
              'Thông tin chi tiết',
              style: TextStyle(
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
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoTile('Mô tả', description),
                  _buildInfoTile('Danh mục', category),
                  _buildInfoTile('Thương hiệu', brand),
                  _buildInfoTile('Thông số', specs),
                  if (otherFields.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    const Text(
                      'Trường tuỳ chỉnh',
                      style: TextStyle(
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
              label: const Text('Chỉnh sửa sản phẩm'),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
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
