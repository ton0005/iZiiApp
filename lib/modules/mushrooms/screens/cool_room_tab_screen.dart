import 'package:flutter/material.dart';
import 'mushboom_monarto_screen.dart'; // For FarmColors

class CoolRoomTabScreen extends StatefulWidget {
  final bool isDark;
  final Map<String, Map<String, dynamic>> localRooms;
  final String activePlant;
  final double stockButton;
  final double stockMedium;
  final double stockOpen;
  final List<Map<String, dynamic>> orders;
  final Function(String, int, int, int) onSendPickingPlan;
  final Function(Map<String, dynamic>) onDeliverOrder;

  const CoolRoomTabScreen({
    super.key,
    required this.isDark,
    required this.localRooms,
    required this.activePlant,
    required this.stockButton,
    required this.stockMedium,
    required this.stockOpen,
    required this.orders,
    required this.onSendPickingPlan,
    required this.onDeliverOrder,
  });

  @override
  State<CoolRoomTabScreen> createState() => _CoolRoomTabScreenState();
}

class _CoolRoomTabScreenState extends State<CoolRoomTabScreen> {
  late String _roomSelected;
  int _buttonVal = 50;
  int _mediumVal = 100;
  int _openVal = 30;

  @override
  void initState() {
    super.initState();
    _roomSelected = widget.localRooms.keys
        .firstWhere((k) => widget.localRooms[k]!['plant'] == widget.activePlant);
  }

  @override
  void didUpdateWidget(covariant CoolRoomTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePlant != widget.activePlant) {
      _roomSelected = widget.localRooms.keys
          .firstWhere((k) => widget.localRooms[k]!['plant'] == widget.activePlant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Stock display & Create Plan Form
          SizedBox(
            width: 350,
            child: Column(
              children: [
                // Stock inventory gauges card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kho lạnh - Tồn kho hiện tại',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 16),
                      _buildStockRow(
                          'Button Size (Cỡ Nhỏ)', widget.stockButton, Colors.orange),
                      const SizedBox(height: 12),
                      _buildStockRow(
                          'Medium Size (Cỡ Vừa)', widget.stockMedium, Colors.purple),
                      const SizedBox(height: 12),
                      _buildStockRow(
                          'Open Size (Cỡ Lớn)', widget.stockOpen, Colors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Create plan card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: FarmColors.borderLight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildCreatePickingPlanCard(widget.isDark),
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Orders list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: FarmColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Đơn hàng xuất kho hôm nay (Orders List)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.orders.length,
                      itemBuilder: (context, idx) {
                        final order = widget.orders[idx];
                        final isDelivered = order['status'] == 'Delivered';
                        return ListTile(
                          title: Text(
                              '${order['customer']} — Đơn ${order['id']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(order['req']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${order['total']} kg',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 16),
                              if (!isDelivered)
                                ElevatedButton(
                                  onPressed: () => widget.onDeliverOrder(order),
                                  child: const Text('Giao hàng'),
                                )
                              else
                                const Text('Đã giao',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStockRow(String size, double val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(size, style: const TextStyle(fontSize: 13)),
          ],
        ),
        Text('${val.toInt()} kg',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildCreatePickingPlanCard(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lập kế hoạch Picking gửi cho Harvest',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Phòng thu hoạch'),
          value: _roomSelected,
          items: widget.localRooms.keys
              .where((k) => widget.localRooms[k]!['plant'] == widget.activePlant)
              .map((r) =>
                  DropdownMenuItem(value: r, child: Text('Phòng $r')))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _roomSelected = val);
            }
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Button Size (kg)'),
          initialValue: _buttonVal.toString(),
          keyboardType: TextInputType.number,
          onChanged: (val) => _buttonVal = int.tryParse(val) ?? 0,
        ),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Medium Size (kg)'),
          initialValue: _mediumVal.toString(),
          keyboardType: TextInputType.number,
          onChanged: (val) => _mediumVal = int.tryParse(val) ?? 0,
        ),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Open Size (kg)'),
          initialValue: _openVal.toString(),
          keyboardType: TextInputType.number,
          onChanged: (val) => _openVal = int.tryParse(val) ?? 0,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: FarmColors.coolBlue,
                foregroundColor: Colors.white),
            onPressed: () {
              widget.onSendPickingPlan(_roomSelected, _buttonVal, _mediumVal, _openVal);
            },
            child: const Text('Gửi Yêu Cầu Thu Hoạch'),
          ),
        )
      ],
    );
  }
}
