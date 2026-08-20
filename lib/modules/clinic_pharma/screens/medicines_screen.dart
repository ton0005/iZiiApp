import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../repository.dart';

const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  late Future<List<Map<String, dynamic>>> _medicinesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _medicinesFuture = ClinicPharmaRepository().getMedicines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('clinic_medicines_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kGradient)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _medicinesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final medicines = snapshot.data ?? [];
          if (medicines.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(context.tr('clinic_no_medicines'),
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              final m = medicines[index];
              final stock = (m['stock'] as num? ?? 0);
              final customFields = m['custom_fields'] as Map? ?? {};
              final lowStock = stock < 10;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (lowStock ? const Color(0xFFF43F5E) : const Color(0xFF14B8A6))
                            .withValues(alpha: 0.15),
                    child: Icon(Icons.medication,
                        color: lowStock ? const Color(0xFFF43F5E) : const Color(0xFF14B8A6)),
                  ),
                  title: Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([
                    'Tồn kho: $stock ${customFields['dosage_unit'] ?? ''}',
                    if ((customFields['expiry_date'] as String? ?? '').isNotEmpty)
                      'HSD: ${customFields['expiry_date']}',
                  ].join(' • ')),
                  trailing: Text('${(m['price'] as num).toStringAsFixed(0)} VNĐ',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_medicine',
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await context.push<bool>('/clinic/medicines/form');
          if (result == true && mounted) {
            setState(_reload);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
