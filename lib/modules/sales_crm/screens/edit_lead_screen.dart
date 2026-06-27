import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/device_identity/ble_device_discovery_service.dart';
import '../bloc/crm_bloc.dart';
import '../ui/lead_form.dart';
import 'deal_detail_screen.dart';

class EditLeadScreen extends StatefulWidget {
  final Map<String, dynamic> lead;

  const EditLeadScreen({super.key, required this.lead});

  @override
  State<EditLeadScreen> createState() => _EditLeadScreenState();
}

class _EditLeadScreenState extends State<EditLeadScreen> {
  Map<String, dynamic>? _linkedDeal;
  bool _loadingDeal = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedDeal();
  }

  Future<void> _loadLinkedDeal() async {
    setState(() {
      _loadingDeal = true;
    });
    try {
      final deal = await CrmRepository().getDealByLeadId(widget.lead['id']);
      if (mounted) {
        setState(() {
          _linkedDeal = deal;
          _loadingDeal = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDeal = false;
        });
      }
    }
  }

  Future<void> _convertToDeal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('crm_convert_to_deal')),
        content: Text(context.tr('crm_convert_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _loadingDeal = true;
      });
      try {
        await CrmRepository().convertLeadToDeal(widget.lead['id']);
        await _loadLinkedDeal();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('crm_converted_success')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _loadingDeal = false;
          });
        }
      }
    }
  }

  Future<void> _shareLeadBluetooth(BuildContext context) async {
    final bleDiscovery = BleDeviceDiscoveryService();
    final connectedPeers = await bleDiscovery.getConnectedPeersList();
    
    if (connectedPeers.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('📡 Chia sẻ ngoại tuyến', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
              'Không tìm thấy thiết bị nào đang kết nối Bluetooth.\n\nHãy đảm bảo Bluetooth của các thiết bị đã bật, ứng dụng iZiiApp đang mở và các thiết bị đã được kết nối bắt tay trong tab "Thiết bị kết nối".',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0F172A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn thiết bị để chia sẻ qua BLE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: connectedPeers.length,
                  itemBuilder: (context, index) {
                    final peer = connectedPeers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF6366F1),
                        child: Icon(Icons.bluetooth_connected, color: Colors.white),
                      ),
                      title: Text(peer['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(peer['deviceId'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đang gửi yêu cầu chia sẻ cơ hội tới ${peer['name']}...')),
                        );
                        final success = await bleDiscovery.shareRecordWithPeer(
                          remoteDeviceId: peer['deviceId']!,
                          table: 'leads',
                          recordData: widget.lead,
                        );
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Không thể gửi yêu cầu chia sẻ. Vui lòng kiểm tra lại kết nối.')),
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _saveLead(Map<String, dynamic> values) async {
    final updatedLead = {
      ...widget.lead,
      ...values,
      'custom_fields':
          widget.lead['custom_fields'] ?? values['custom_fields'] ?? {},
    };

    await CrmRepository().updateLeadFull(updatedLead);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context
            .tr('crm_customer_updated')
            .replaceAll('{name}', updatedLead['name'] ?? '')),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('crm_edit_customer')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () => _shareLeadBluetooth(context),
            tooltip: 'Chia sẻ Bluetooth',
          ),
        ],
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
          children: [
            if (_loadingDeal)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              )
            else if (_linkedDeal != null)
              Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('crm_linked_deal'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF06B6D4),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _linkedDeal!['stage']?.toString().toUpperCase() ??
                                  '',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _linkedDeal!['title'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${context.tr('crm_deal_amount')}: \$${(_linkedDeal!['amount'] ?? 0.0).toStringAsFixed(2)}',
                        style:
                            const TextStyle(color: Colors.green, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DealDetailScreen(deal: _linkedDeal!),
                              ),
                            );
                            _loadLinkedDeal();
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(context.tr('crm_view_deal')),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(context.tr('crm_no_linked_deal')),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _convertToDeal,
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(context.tr('crm_convert_to_deal')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            LeadForm(
              initialLead: widget.lead,
              submitLabel: context.tr('crm_update_lead'),
              onSave: _saveLead,
            ),
          ],
        ),
      ),
    );
  }
}
