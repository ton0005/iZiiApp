import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/localization/app_localizations.dart';
import '../services/prescription_pdf_service.dart';

const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

/// Lets the user fill in the fields the pharmacy pad template needs but
/// which aren't captured on the medical visit form (facility header, patient
/// weight, guardian name for pediatric visits, free-text advice), then
/// previews and prints/exports the prescription as a PDF matching the
/// standard "ĐƠN THUỐC" pad.
class PrescriptionPrintScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final Map<String, dynamic>? doctor;
  final Map<String, dynamic> visit;
  final Map<String, dynamic> prescription;

  const PrescriptionPrintScreen({
    super.key,
    required this.patient,
    this.doctor,
    required this.visit,
    required this.prescription,
  });

  @override
  State<PrescriptionPrintScreen> createState() => _PrescriptionPrintScreenState();
}

class _PrescriptionPrintScreenState extends State<PrescriptionPrintScreen> {
  final _authorityController = TextEditingController(text: 'SỞ Y TẾ');
  final _facilityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _weightController = TextEditingController();
  final _adviceController = TextEditingController();
  final _guardianController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adviceController.text = (widget.visit['notes'] as String?) ?? '';
  }

  @override
  void dispose() {
    _authorityController.dispose();
    _facilityController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _adviceController.dispose();
    _guardianController.dispose();
    super.dispose();
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) {
    final items = (widget.prescription['items'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    return PrescriptionPdfService.generate(
      facilityAuthority: _authorityController.text.trim(),
      facilityName: _facilityController.text.trim(),
      facilityPhone: _phoneController.text.trim(),
      patient: widget.patient,
      doctor: widget.doctor,
      visit: widget.visit,
      prescription: widget.prescription,
      items: items,
      weight: _weightController.text.trim(),
      advice: _adviceController.text.trim(),
      guardianName: _guardianController.text.trim(),
    );
  }

  void _refreshPreview() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('clinic_print_prescription_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kGradient)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _authorityController,
                        decoration: InputDecoration(
                          labelText: context.tr('clinic_facility_authority'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _facilityController,
                        decoration: InputDecoration(
                          labelText: context.tr('clinic_facility_name'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: context.tr('clinic_facility_phone'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr('clinic_patient_weight'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _adviceController,
                  decoration: InputDecoration(
                    labelText: context.tr('clinic_prescription_advice'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _guardianController,
                        decoration: InputDecoration(
                          labelText: context.tr('clinic_guardian_name'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: _kGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: _refreshPreview,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: context.tr('clinic_refresh_preview'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PdfPreview(
              build: (format) => _buildPdf(format),
              initialPageFormat: PdfPageFormat.a5,
              canChangePageFormat: false,
              canChangeOrientation: false,
              pdfFileName: 'don_thuoc_${widget.patient['full_name'] ?? ''}.pdf',
            ),
          ),
        ],
      ),
    );
  }
}
