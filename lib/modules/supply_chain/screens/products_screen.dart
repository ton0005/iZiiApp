import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/inventory_bloc.dart';
import 'add_product_from_image_screen.dart';
import 'edit_product_screen.dart';
import 'barcode_scanner_screen.dart';
import 'product_info_screen.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InventoryBloc()..add(LoadProductsEvent()),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Products'),
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Quét mã vạch/QR',
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const BarcodeScannerScreen(),
                      ),
                    );
                    if (result == true && context.mounted) {
                      context.read<InventoryBloc>().add(LoadProductsEvent());
                    }
                  },
                ),
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
              ],
            ),
            body: BlocBuilder<InventoryBloc, InventoryState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.error != null) {
                  return Center(
                    child: Text(
                      'Lỗi khi tải sản phẩm: ${state.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (state.products.isEmpty) {
                  return const Center(child: Text('No products available.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 100),
                  itemCount: state.products.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final product = state.products[index];
                    final bool outOfStock = product['stock'] == 0;
                    return ListTile(
                      onTap: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ProductInfoScreen(product: product),
                          ),
                        );
                        if (result == true && context.mounted) {
                          context
                              .read<InventoryBloc>()
                              .add(LoadProductsEvent());
                        }
                      },
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: Color(0xFF10B981)),
                      ),
                      title: Text(product['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle:
                          Text('Giá: ${_formatPrice(product['price'])} VNĐ'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: outOfStock
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              outOfStock
                                  ? 'Out of Stock'
                                  : 'In Stock: ${product['stock']}',
                              style: TextStyle(
                                color: outOfStock ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Color(0xFF10B981)),
                            tooltip: 'Chỉnh sửa sản phẩm',
                            onPressed: () async {
                              final result =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditProductScreen(product: product),
                                ),
                              );
                              if (result == true && context.mounted) {
                                context
                                    .read<InventoryBloc>()
                                    .add(LoadProductsEvent());
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Camera / Image button
                FloatingActionButton.extended(
                  heroTag: 'add_from_image',
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const AddProductFromImageScreen(),
                      ),
                    );
                    // Reload list if product was added
                    if (result == true && context.mounted) {
                      context.read<InventoryBloc>().add(LoadProductsEvent());
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Gallery / Camera'),
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price is double) {
      if (price >= 1000000) {
        return '${(price / 1000000).toStringAsFixed(1)}M';
      }
      return price.toStringAsFixed(0);
    }
    return price.toString();
  }
}
