import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../supply_chain/repository.dart';
import '../bloc/purchase_bloc.dart';

class PurchaseOrderFormScreen extends StatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  State<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _partnerController = TextEditingController();
  final List<Map<String, dynamic>> _lines = [];
  double _totalAmount = 0.0;

  @override
  void dispose() {
    _partnerController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    double total = 0.0;
    for (final l in _lines) {
      final qty = (l['quantity'] as num).toDouble();
      final price = (l['unit_price'] as num).toDouble();
      total += qty * price;
    }
    setState(() {
      _totalAmount = total;
    });
  }

  void _addLine() async {
    // Load supply chain products
    final products = await SupplyChainRepository().getAllProducts();

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        String productName = '';
        final qtyController = TextEditingController(text: '1');
        final priceController = TextEditingController();
        dynamic selectedProduct;

        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) => AlertDialog(
            title: Text(context.tr('purchase_line_add_title')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<dynamic>(
                    value: selectedProduct,
                    hint: Text(context.tr('purchase_select_product_hint')),
                    items: [
                      ...products.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (${p.price.toStringAsFixed(0)} VNĐ)'),
                          )),
                      DropdownMenuItem(
                        value: 'manual',
                        child: Text(context.tr('purchase_manual_input')),
                      ),
                    ],
                    onChanged: (val) {
                      setStateDialog(() {
                        selectedProduct = val;
                        if (val != 'manual' && val != null) {
                          productName = val.name;
                          priceController.text = val.price.toStringAsFixed(0);
                        } else {
                          productName = '';
                          priceController.clear();
                        }
                      });
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  if (selectedProduct == 'manual') ...[
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => productName = val,
                      decoration: InputDecoration(
                        labelText: '${context.tr('inv_product_name')} *',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${context.tr('inv_stock_quantity')} *',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${context.tr('inv_price_vnd').split(' (')[0]} *',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
              ElevatedButton(
                onPressed: () {
                  final qty = double.tryParse(qtyController.text) ?? 1.0;
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  if (productName.trim().isEmpty) return;
                  
                  Navigator.pop(ctx, {
                    'product_name': productName,
                    'quantity': qty,
                    'unit_price': price,
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                child: Text(context.tr('confirm')),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _lines.add(result);
        _calculateTotal();
      });
    }
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      _calculateTotal();
    });
  }

  void _save(BuildContext context) {
    final partner = _partnerController.text.trim();
    if (partner.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('crm_info_customer_name_empty'))),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('ser_select_service_err'))),
      );
      return;
    }

    final orderId = const Uuid().v4();
    final order = {
      'id': orderId,
      'partner_name': partner,
      'status': 'draft',
    };

    final orderLines = _lines.map((l) => <String, dynamic>{
      'id': const Uuid().v4(),
      'purchase_order_id': orderId,
      'product_name': l['product_name'],
      'quantity': l['quantity'],
      'unit_price': l['unit_price'],
    }).toList();

    context.read<PurchaseBloc>().add(AddPurchaseOrderEvent(order, orderLines));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PurchaseBloc(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.tr('purchase_create_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 20, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Text(context.tr('crm_info_customer_info'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _partnerController,
                    decoration: InputDecoration(
                      labelText: '${context.tr('purchase_partner_label')} *',
                      prefixIcon: const Icon(Icons.business),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 4, height: 20, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text(context.tr('services_action_list'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add, color: Color(0xFF8B5CF6)),
                        label: Text(context.tr('purchase_line_add_btn'), style: const TextStyle(color: Color(0xFF8B5CF6))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_lines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.15)),
                      ),
                      child: Text(
                        context.tr('inv_no_products'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _lines.length,
                      itemBuilder: (context, index) {
                        final line = _lines[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(line['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${context.tr('inv_stock_quantity')}: ${line['quantity']} × ${_formatPrice(line['unit_price'])} VNĐ'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${_formatPrice((line['quantity'] as num) * (line['unit_price'] as num))} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeLine(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('ser_booking_total_amount'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${_formatPrice(_totalAmount)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF10B981))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _save(context),
                      icon: const Icon(Icons.check_circle_outline, size: 22),
                      label: Text(context.tr('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price is num) {
      return price.toStringAsFixed(0);
    }
    return price.toString();
  }
}
