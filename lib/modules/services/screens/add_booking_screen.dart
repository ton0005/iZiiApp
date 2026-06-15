import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../supply_chain/screens/barcode_scanner_screen.dart';
import '../bloc/services_bloc.dart';

class AddBookingScreen extends StatefulWidget {
  const AddBookingScreen({super.key});

  @override
  State<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _serviceCodeController = TextEditingController();

  List<Map<String, dynamic>> _availableServices = [];
  Map<String, dynamic>? _selectedService;
  DateTime? _scheduledAt;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final services = await ServiceModuleRepository().getServices();
    setState(() {
      _availableServices =
          services.where((s) => s['is_active'] == true).toList();
      _isLoading = false;
    });
  }

  Future<void> _scanServiceCode() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(returnCode: true),
      ),
    );

    if (scannedCode == null || scannedCode.isEmpty) return;

    setState(() {
      _serviceCodeController.text = scannedCode;
    });

    Map<String, dynamic>? matchedService;
    try {
      matchedService = _availableServices.firstWhere(
        (s) {
          final serviceName = (s['name'] as String?)?.toLowerCase() ?? '';
          final codeLower = scannedCode.toLowerCase();
          return s['id'] == scannedCode || serviceName == codeLower;
        },
      );
    } catch (_) {
      matchedService = null;
    }

    if (matchedService != null) {
      setState(() {
        _selectedService = matchedService;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('ser_no_matching_services'))),
      );
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    _serviceCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('ser_select_service_err'))),
      );
      return;
    }
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('ser_customer_name_empty_err'))),
      );
      return;
    }

    final data = {
      'id': const Uuid().v4(),
      'service_item_id': _selectedService!['id'],
      'customer_name': _customerNameController.text.trim(),
      'customer_phone': _customerPhoneController.text.trim().isNotEmpty
          ? _customerPhoneController.text.trim()
          : null,
      'scheduled_at': _scheduledAt?.toIso8601String(),
      'estimated_hours': _selectedService!['estimated_hours'],
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    };

    try {
      await ServiceModuleRepository().addBooking(data);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('ser_booking_created')),
            backgroundColor: const Color(0xFF10B981)),
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
        title: Text(context.tr('ser_booking_create_title')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader(context.tr('ser_select_service_section')),
                  const SizedBox(height: 12),

                  // Service selector
                  if (_availableServices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(context.tr('ser_no_services_alert'),
                          textAlign: TextAlign.center),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedService?['id'],
                        hint: Text(context.tr('ser_select_service_section')),
                        items: _availableServices.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(
                                '${s['name']} (${_formatPrice(s['hourly_rate'])} VNĐ/giờ)'),
                          );
                        }).toList(),
                        onChanged: (id) {
                          setState(() {
                            _selectedService = _availableServices
                                .firstWhere((s) => s['id'] == id);
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                              Icons.home_repair_service_rounded,
                              size: 20),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),

                  // Barcode / QR scan for service lookup
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _serviceCodeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: context.tr('inv_barcode_qr'),
                        prefixIcon: const Icon(Icons.qr_code, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: Color(0xFF8B5CF6)),
                          tooltip: context.tr('inv_scanner_tooltip'),
                          onPressed: _scanServiceCode,
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),

                  // Estimated cost preview
                  if (_selectedService != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined,
                              color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.tr('ser_cost_estimation'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatPrice(_selectedService!['hourly_rate'])} × ${_selectedService!['estimated_hours']} giờ = ${_formatPrice((_selectedService!['hourly_rate'] as num) * (_selectedService!['estimated_hours'] as num))} VNĐ',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  _buildSectionHeader(context.tr('ser_customer_info_section')),
                  const SizedBox(height: 12),
                  _buildTextField(
                      _customerNameController,
                      context.tr('ser_customer_name_label'),
                      Icons.person_outline),
                  _buildTextField(
                      _customerPhoneController,
                      context.tr('ser_customer_phone_label'),
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone),

                  const SizedBox(height: 8),
                  _buildSectionHeader(
                      context.tr('ser_booking_datetime_section')),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDateTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3)),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 20, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _scheduledAt != null
                                  ? '${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} - ${_scheduledAt!.hour}:${_scheduledAt!.minute.toString().padLeft(2, '0')}'
                                  : context.tr('ser_booking_datetime_hint'),
                              style: TextStyle(
                                color:
                                    _scheduledAt != null ? null : Colors.grey,
                              ),
                            ),
                          ),
                          if (_scheduledAt != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _scheduledAt = null),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildTextField(
                      _notesController,
                      context.tr('ser_booking_notes_label'),
                      Icons.notes_outlined,
                      maxLines: 3),

                  const SizedBox(height: 24),
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
            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.check_circle_outline, size: 22),
        label: Text(context.tr('ser_booking_btn_create'),
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

  String _formatPrice(dynamic price) {
    if (price is num) {
      if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
      if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
      return price.toStringAsFixed(0);
    }
    return '0';
  }
}
