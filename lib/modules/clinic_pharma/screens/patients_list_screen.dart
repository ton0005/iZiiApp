import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../repository.dart';

const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

class PatientsListScreen extends StatefulWidget {
  const PatientsListScreen({super.key});

  @override
  State<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends State<PatientsListScreen> {
  late Future<List<Map<String, dynamic>>> _patientsFuture;
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _patientsFuture = ClinicPharmaRepository().getPatients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('clinic_patients_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kGradient)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.tr('clinic_patients_title'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _patientsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final patients = (snapshot.data ?? [])
                    .where((p) => (p['full_name'] as String)
                        .toLowerCase()
                        .contains(_search))
                    .toList();

                if (patients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(context.tr('clinic_no_patients'),
                            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final p = patients[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2FE),
                          child: Icon(Icons.person, color: Color(0xFF0EA5E9)),
                        ),
                        title: Text(p['full_name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(p['phone'] ?? ''),
                        onTap: () => context.push<bool>('/clinic/visits/form',
                            extra: {'patient': p}),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_patient',
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await context.push<bool>('/clinic/patients/form');
          if (result == true && mounted) {
            setState(_reload);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
