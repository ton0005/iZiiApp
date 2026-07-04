import 'package:flutter/material.dart';

class SafetyTabScreen extends StatefulWidget {
  final bool isDark;
  final List<Map<String, dynamic>> safetyLogs;
  final Function(bool) onTriggerEmergency;
  final Function() onTriggerSafetyCheckAll;
  final Function() onResetSafety;
  final Function(String, String) onReportIncident;

  const SafetyTabScreen({
    super.key,
    required this.isDark,
    required this.safetyLogs,
    required this.onTriggerEmergency,
    required this.onTriggerSafetyCheckAll,
    required this.onResetSafety,
    required this.onReportIncident,
  });

  @override
  State<SafetyTabScreen> createState() => _SafetyTabScreenState();
}

class _SafetyTabScreenState extends State<SafetyTabScreen> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Control Buttons & Incident Form
          SizedBox(
            width: 340,
            child: Column(
              children: [
                // Alarms panel card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: const Color(0xFFE2E0D9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('Farm Safety Controls',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.emergency_share,
                            color: Colors.white),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(42)),
                        onPressed: () => widget.onTriggerEmergency(true),
                        label: const Text('TRIGGER RED ALERT'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42)),
                        onPressed: widget.onTriggerSafetyCheckAll,
                        child: const Text('Request Routine Check-In'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42)),
                        onPressed: widget.onResetSafety,
                        child: const Text('Restore Safe Status'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Report Form card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border.all(color: const Color(0xFFE2E0D9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildIncidentReportForm(widget.isDark),
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Safety log list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(color: const Color(0xFFE2E0D9)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Safety Logs (Check-In / Check-Out / Solo)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _buildSafetyLogsTable(),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSafetyLogsTable() {
    return ListView.builder(
      itemCount: widget.safetyLogs.length,
      itemBuilder: (context, idx) {
        final log = widget.safetyLogs[idx];
        final isSolo = log['solo'] as bool;
        return ListTile(
          selected: isSolo,
          selectedColor: Colors.red,
          selectedTileColor: Colors.red.shade50,
          leading: Icon(
            log['action'] == 'Check-in' ? Icons.login : Icons.logout,
            color: log['action'] == 'Check-in' ? Colors.green : Colors.grey,
          ),
          title: Text(
              '${log['empName']} (${log['empId']}) — Room ${log['room']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Role: ${log['role']} · Time: ${log['time']}'),
          trailing: isSolo
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.red, size: 14),
                    SizedBox(width: 4),
                    Text('Solo Timer: 45m',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildIncidentReportForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Report Safety Incident',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
              labelText: 'Incident Location',
              hintText: 'e.g. Room 55 or Cold Room M1'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _descController,
          decoration: const InputDecoration(labelText: 'Detailed Incident Description'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () {
              final loc = _locationController.text.trim();
              final d = _descController.text.trim();
              widget.onReportIncident(loc, d);
              _locationController.clear();
              _descController.clear();
            },
            child: const Text('Submit Incident Report'),
          ),
        )
      ],
    );
  }
}
