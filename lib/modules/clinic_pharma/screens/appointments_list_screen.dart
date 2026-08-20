import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../repository.dart';

const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  static const _statusColors = {
    'scheduled': Color(0xFF3B82F6),
    'checked_in': Color(0xFF8B5CF6),
    'completed': Color(0xFF10B981),
    'cancelled': Color(0xFFF43F5E),
    'no_show': Color(0xFF94A3B8),
  };

  late Future<List<Map<String, dynamic>>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _appointmentsFuture = ClinicPharmaRepository().getAppointments();
  }

  String _statusLabel(String status, BuildContext context) {
    switch (status) {
      case 'scheduled':
        return context.tr('clinic_status_scheduled');
      case 'checked_in':
        return context.tr('clinic_status_checked_in');
      case 'completed':
        return context.tr('clinic_status_completed');
      case 'cancelled':
        return context.tr('clinic_status_cancelled');
      case 'no_show':
        return context.tr('clinic_status_no_show');
      default:
        return status;
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('clinic_appointments_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kGradient)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _appointmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final appointments = snapshot.data ?? [];
          if (appointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(context.tr('clinic_no_appointments'),
                      style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final a = appointments[index];
              final status = a['status'] as String? ?? 'scheduled';
              final color = _statusColors[status] ?? Colors.grey;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(Icons.event, color: color),
                  ),
                  title: Text(a['patient_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([
                    _formatDateTime(a['scheduled_at']),
                    if ((a['doctor_name'] as String? ?? '').isNotEmpty)
                      'BS. ${a['doctor_name']}',
                  ].join(' • ')),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_statusLabel(status, context),
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () async {
                    final result = await context.push<bool>('/clinic/visits/form', extra: {
                      'patient': {'id': a['patient_id'], 'full_name': a['patient_name']},
                      'appointment': a,
                    });
                    if (result == true && mounted) setState(_reload);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_appointment',
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await context.push<bool>('/clinic/appointments/form');
          if (result == true && mounted) {
            setState(_reload);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
