import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/app_database.dart';
import '../../supply_chain/repository.dart';
import '../models/putaway_fefo_models.dart';
import '../services/fefo_allocation_engine.dart';

class FefoOutboundScreen extends StatefulWidget {
  const FefoOutboundScreen({super.key});

  @override
  State<FefoOutboundScreen> createState() => _FefoOutboundScreenState();
}

class _FefoOutboundScreenState extends State<FefoOutboundScreen> {
  final SupplyChainRepository _supplyRepo = SupplyChainRepository();
  final FefoAllocationEngine _fefoEngine = FefoAllocationEngine();
  final TextEditingController _demandQtyController = TextEditingController(text: '72');

  List<Product> _products = [];
  Product? _selectedProduct;
  bool _isLoading = true;
  bool _isAllocating = false;

  FefoAllocationResult? _allocationResult;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _demandQtyController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final prods = await _supplyRepo.getAllProducts();
    setState(() {
      _products = prods;
      if (prods.isNotEmpty) {
        _selectedProduct = prods.first;
      }
      _isLoading = false;
    });
  }

  Future<void> _runFefoAllocation() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product for outbound allocation.')),
      );
      return;
    }

    final demand = double.tryParse(_demandQtyController.text);
    if (demand == null || demand <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid outbound quantity.')),
      );
      return;
    }

    setState(() => _isAllocating = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await _fefoEngine.allocateStockFefo(
        productId: _selectedProduct!.id,
        requestedQty: demand,
        executeReservation: true,
      );

      setState(() {
        _allocationResult = result;
        _isAllocating = false;
      });

      if (result.isFullyAllocated) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() => _isAllocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red.shade900, content: Text('Allocation error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AUTOMATED FEFO OUTBOUND ALLOCATION',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Automated First-Expired, First-Out Allocation Engine',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Section 1: Order Parameters ---
                  _buildDemandInputCard(),
                  const SizedBox(height: 16),

                  // --- Section 2: Allocation Summary ---
                  if (_allocationResult != null) ...[
                    _buildAllocationSummaryCard(_allocationResult!),
                    const SizedBox(height: 16),
                    _buildPickingListSection(_allocationResult!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildDemandInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.outbox, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                'OUTBOUND ORDER & DEMAND PARAMETERS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Product Dropdown
          DropdownButtonFormField<Product>(
            initialValue: _selectedProduct,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Outbound Product',
              labelStyle: TextStyle(color: Colors.white60),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
            ),
            items: _products.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text('${p.name} (${p.sku})'),
              );
            }).toList(),
            onChanged: (p) => setState(() => _selectedProduct = p),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _demandQtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Required Outbound Quantity',
                    labelStyle: TextStyle(color: Colors.white60),
                    suffixText: 'boxes',
                    suffixStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('1 Pallet (72)'),
                    backgroundColor: const Color(0xFF334155),
                    labelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                    onPressed: () => setState(() => _demandQtyController.text = '72'),
                  ),
                  ActionChip(
                    label: const Text('2 Pallets (144)'),
                    backgroundColor: const Color(0xFF334155),
                    labelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                    onPressed: () => setState(() => _demandQtyController.text = '144'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isAllocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, color: Colors.white),
              label: Text(
                _isAllocating ? 'CALCULATING FEFO ALLOCATION...' : 'AUTOMATE FEFO ALLOCATION (RUN ALLOCATION)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _isAllocating ? null : _runFefoAllocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationSummaryCard(FefoAllocationResult res) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: res.isFullyAllocated ? const Color(0xFF10B981) : Colors.orangeAccent,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    res.isFullyAllocated ? Icons.check_circle : Icons.warning_amber,
                    color: res.isFullyAllocated ? const Color(0xFF34D399) : Colors.orangeAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    res.isFullyAllocated ? 'FEFO ALLOCATION COMPLETED 100%' : 'STOCK SHORTAGE WARNING (APPROVED LOTS)',
                    style: TextStyle(
                      color: res.isFullyAllocated ? const Color(0xFF34D399) : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: res.isFullyAllocated ? const Color(0xFF065F46) : Colors.deepOrange.shade900,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${res.allocatedQuantity.toInt()} / ${res.requestedQuantity.toInt()} BOXES',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            res.summaryNotes,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (res.earliestExpiry != null) ...[
            const SizedBox(height: 6),
            Text(
              'Priority Outbound Lot (Earliest Expiry): ${res.earliestExpiry!.day}/${res.earliestExpiry!.month}/${res.earliestExpiry!.year}',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickingListSection(FefoAllocationResult res) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.format_list_numbered, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'FEFO PICKING SEQUENCE (PICKING LIST)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '${res.lines.length} Locations / Pallets',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (res.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No eligible stock lots allocated.',
                style: TextStyle(color: Colors.white38),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: res.lines.length,
              separatorBuilder: (context, idx) => const Divider(color: Colors.white12),
              itemBuilder: (context, idx) {
                final line = res.lines[idx];
                final isUrgent = line.daysUntilExpiry <= 3;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  line.lotNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isUrgent ? Colors.red.shade900 : const Color(0xFF065F46),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isUrgent
                                        ? 'NEAR EXPIRY (${line.daysUntilExpiry} days)'
                                        : 'EXPIRY: ${line.daysUntilExpiry} days',
                                    style: TextStyle(
                                      color: isUrgent ? Colors.redAccent : const Color(0xFF6EE7B7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pick Location: ${line.locationCode} • Pallet: ${line.lpnCode ?? "No LPN"}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Pick: ${line.allocatedQty.toInt()} ${line.uom}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Text(
                            'RESERVED',
                            style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
