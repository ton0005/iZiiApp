import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../bloc/inventory_bloc.dart';
import 'add_product_from_image_screen.dart';
import 'edit_product_screen.dart';
import 'barcode_scanner_screen.dart';
import 'product_info_screen.dart';
import 'pallet_scale_station_screen.dart';
import 'forklift_scan_screen.dart';
import '../../warehouse_automation/screens/central_conveyor_screen.dart';
import '../../warehouse_automation/screens/fefo_outbound_screen.dart';
import '../../warehouse_automation/screens/qc_inspection_screen.dart';
import '../../warehouse_automation/screens/blind_cycle_count_screen.dart';
import '../../warehouse_automation/screens/wave_picking_screen.dart';
import '../../warehouse_automation/screens/packout_scale_audit_screen.dart';
import '../../warehouse_automation/screens/cold_chain_telemetry_screen.dart';
import '../../warehouse_automation/screens/driver_pod_screen.dart';
import '../../warehouse_automation/screens/agv_fleet_dispatch_screen.dart';
import '../../warehouse_automation/screens/warehouse_3d_layout_screen.dart';

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
              title: Text(context.tr('inv_products_title')),
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fact_check_outlined),
                  tooltip: 'Cổng Kiểm Định QC (QC Gate)',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QcInspectionScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.inventory_outlined),
                  tooltip: 'Kiểm Kê Mù Liên Tục (Blind Cycle Count)',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BlindCycleCountScreen(),
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Tự Động Hóa Kho & Logistics (WMS)',
                  onSelected: (value) {
                    if (value == 'scale') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PalletScaleStationScreen()),
                      );
                    } else if (value == 'forklift') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForkliftScanScreen()),
                      );
                    } else if (value == 'conveyor') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CentralConveyorScreen()),
                      );
                    } else if (value == 'qc') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QcInspectionScreen()),
                      );
                    } else if (value == 'fefo') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FefoOutboundScreen()),
                      );
                    } else if (value == 'cycle_count') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BlindCycleCountScreen()),
                      );
                    } else if (value == 'wave') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WavePickingScreen()),
                      );
                    } else if (value == 'packout_audit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PackoutScaleAuditScreen()),
                      );
                    } else if (value == 'cold_chain') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ColdChainTelemetryScreen()),
                      );
                    } else if (value == 'pod') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DriverPodScreen()),
                      );
                    } else if (value == 'agv') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AgvFleetDispatchScreen()),
                      );
                    } else if (value == 'wh_3d') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const Warehouse3dLayoutScreen()),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'wh_3d',
                      child: ListTile(
                        leading: Icon(Icons.view_in_ar, color: Colors.cyanAccent),
                        title: Text('3D WH Layout'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'scale',
                      child: ListTile(
                        leading: Icon(Icons.scale, color: Colors.teal),
                        title: Text('LPN Scale Station (Pallet Scale)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'forklift',
                      child: ListTile(
                        leading: Icon(Icons.forklift, color: Colors.blue),
                        title: Text('Forklift Scan (Directed Putaway & Pick)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'conveyor',
                      child: ListTile(
                        leading: Icon(Icons.conveyor_belt, color: Colors.indigo),
                        title: Text('Conveyor Line'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'qc',
                      child: ListTile(
                        leading: Icon(Icons.fact_check, color: Color(0xFF0F766E)),
                        title: Text('QC (Quality Gate)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'fefo',
                      child: ListTile(
                        leading: Icon(Icons.outbox, color: Colors.amber),
                        title: Text('FEFO Outbound (First Expired First Out)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cycle_count',
                      child: ListTile(
                        leading: Icon(Icons.inventory, color: Color(0xFF1E293B)),
                        title: Text('Cycle Count (Blind Cycle Count)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'wave',
                      child: ListTile(
                        leading: Icon(Icons.alt_route, color: Color(0xFF1E3A8A)),
                        title: Text('Wave Consolidation (S-Shape Routing)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'packout_audit',
                      child: ListTile(
                        leading: Icon(Icons.monitor_weight, color: Colors.cyan),
                        title: Text('Packout Audit (Weight Verification)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cold_chain',
                      child: ListTile(
                        leading: Icon(Icons.thermostat, color: Color(0xFF2563EB)),
                        title: Text('Cold Chain Monitoring (BLE Telemetry)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pod',
                      child: ListTile(
                        leading: Icon(Icons.assignment_turned_in, color: Color(0xFF10B981)),
                        title: Text('Electronic e-PoD (Sign on Glass)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'agv',
                      child: ListTile(
                        leading: Icon(Icons.smart_toy, color: Color(0xFF4338CA)),
                        title: Text('VDA 5050 AGV Dispatch & FAT Commissioning'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: context.tr('inv_scanner_tooltip'),
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
                      context
                          .tr('inv_load_error')
                          .replaceAll('{error}', state.error ?? ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (state.products.isEmpty) {
                  return Center(child: Text(context.tr('inv_no_products')));
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 100),
                  itemCount: state.products.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final product = state.products[index];
                    final bool outOfStock = product['stock'] == 0;
                    final customFields =
                        product['custom_fields'] as Map<String, dynamic>? ?? {};
                    final imagePath = customFields['image_path']?.toString();
                    final hasImage = imagePath != null &&
                        imagePath.isNotEmpty &&
                        File(imagePath).existsSync();

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
                        child: hasImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(imagePath),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.inventory_2_outlined,
                                color: Color(0xFF10B981)),
                      ),
                      title: Text(product['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${context.tr('inv_price_label').replaceAll('{price}', _formatPrice(product['price']))} VNĐ'),
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
                                  ? context.tr('inv_out_of_stock')
                                  : context.tr('inv_in_stock').replaceAll(
                                      '{count}', product['stock'].toString()),
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
                            tooltip: context.tr('inv_edit_product_tooltip'),
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
                  label: Text(context.tr('inv_add_from_image_title')),
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
