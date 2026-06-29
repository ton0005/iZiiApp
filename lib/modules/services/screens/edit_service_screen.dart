import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/device_identity/ble_device_discovery_service.dart';
import '../bloc/services_bloc.dart';

class EditServiceScreen extends StatefulWidget {
  final Map<String, dynamic> service;
  const EditServiceScreen({super.key, required this.service});

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  late TextEditingController _nameController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _estimatedHoursController;
  late TextEditingController _descController;
  late String _category;
  late bool _isActive;

  final Map<String, TextEditingController> _customFieldControllers = {};
  final _newFieldKeyController = TextEditingController();
  final _newFieldValueController = TextEditingController();

  static const _categories = {
    'repair': 'Sửa chữa',
    'installation': 'Lắp đặt',
    'delivery': 'Vận chuyển',
    'cleaning': 'Dọn dẹp',
    'electrical': 'Điện',
    'plumbing': 'Nước',
    'other': 'Khác',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service['name']);
    _hourlyRateController = TextEditingController(
        text: widget.service['hourly_rate']?.toString() ?? '');
    _estimatedHoursController = TextEditingController(
        text: widget.service['estimated_hours']?.toString() ?? '1');
    _descController =
        TextEditingController(text: widget.service['description'] ?? '');
    _category = widget.service['category'] ?? 'other';
    _isActive = widget.service['is_active'] ?? true;

    final customFields =
        widget.service['custom_fields'] as Map<String, dynamic>? ?? {};
    for (final entry in customFields.entries) {
      _customFieldControllers[entry.key] =
          TextEditingController(text: entry.value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hourlyRateController.dispose();
    _estimatedHoursController.dispose();
    _descController.dispose();
    _newFieldKeyController.dispose();
    _newFieldValueController.dispose();
    for (final c in _customFieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCustomField() {
    final key = _newFieldKeyController.text.trim();
    final value = _newFieldValueController.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _customFieldControllers[key] = TextEditingController(text: value);
      _newFieldKeyController.clear();
      _newFieldValueController.clear();
    });
  }

  void _removeCustomField(String key) {
    setState(() {
      _customFieldControllers[key]?.dispose();
      _customFieldControllers.remove(key);
    });
  }

  Future<void> _shareServiceBluetooth(BuildContext context) async {
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
                        backgroundColor: Color(0xFF8B5CF6),
                        child: Icon(Icons.bluetooth_connected, color: Colors.white),
                      ),
                      title: Text(peer['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(peer['deviceId'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đang gửi yêu cầu chia sẻ dịch vụ tới ${peer['name']}...')),
                        );
                        final success = await bleDiscovery.shareRecordWithPeer(
                          remoteDeviceId: peer['deviceId']!,
                          table: 'service_items',
                          recordData: widget.service,
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

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('ser_service_name_empty_err'))),
      );
      return;
    }

    final rate = double.tryParse(
            _hourlyRateController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
    final hours = double.tryParse(_estimatedHoursController.text) ?? 1.0;

    final customFields = <String, dynamic>{};
    for (final entry in _customFieldControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        customFields[entry.key] = entry.value.text;
      }
    }

    final data = {
      'id': widget.service['id'],
      'name': _nameController.text.trim(),
      'category': _category,
      'hourly_rate': rate,
      'estimated_hours': hours,
      'description': _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
      'is_active': _isActive,
      'custom_fields': customFields,
    };

    try {
      await ServiceModuleRepository().updateService(data);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context
              .tr('ser_service_updated')
              .replaceAll('{name}', _nameController.text)),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: const Color(0xFFF43F5E),
            duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('ser_edit_service_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () => _shareServiceBluetooth(context),
            tooltip: 'Chia sẻ Bluetooth',
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader(context.tr('ser_service_info_section')),
            const SizedBox(height: 12),
            _buildTextField(
                _nameController,
                context.tr('ser_service_name_label').replaceAll(' *', ''),
                Icons.home_repair_service_rounded),
            _buildTextField(_descController, context.tr('inv_description'),
                Icons.description_outlined,
                maxLines: 2),

            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                items: _categories.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(context.tr('ser_cat_${e.key}'))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'other'),
                decoration: InputDecoration(
                  labelText: context.tr('ser_service_category_label'),
                  prefixIcon: const Icon(Icons.category_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),

            // Active toggle
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: Text(context.tr('ser_active_status_label'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_isActive
                  ? context.tr('ser_active_status_desc_on')
                  : context.tr('ser_active_status_desc_off')),
              activeThumbColor: const Color(0xFF10B981),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 8),
            _buildSectionHeader(context
                .tr('ser_service_hourly_rate_label_edit')
                .split(' (')[0]),
            const SizedBox(height: 12),
            _buildTextField(
                _hourlyRateController,
                context.tr('ser_service_hourly_rate_label_edit'),
                Icons.attach_money,
                keyboardType: TextInputType.number),
            _buildTextField(_estimatedHoursController,
                context.tr('ser_service_est_hours_label'), Icons.timer_outlined,
                keyboardType: TextInputType.number),

            if (_customFieldControllers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(context.tr('inv_custom_fields')),
              const SizedBox(height: 12),
              ..._customFieldControllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildTextField(
                              entry.value, entry.key, Icons.tune_rounded)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Color(0xFFF43F5E)),
                        onPressed: () => _removeCustomField(entry.key),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),
            _buildSectionHeader(context.tr('inv_add_new_field')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    flex: 2,
                    child: _buildTextField(_newFieldKeyController,
                        context.tr('inv_field_name'), Icons.vpn_key_outlined)),
                const SizedBox(width: 8),
                Expanded(
                    flex: 3,
                    child: _buildTextField(_newFieldValueController,
                        context.tr('inv_field_value'), Icons.text_fields)),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      onPressed: _addCustomField),
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
                    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
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
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
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
            colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save_alt_rounded, size: 22),
        label: Text(context.tr('inv_save_changes'),
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
