import 'dart:async';
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
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
                    child: Text('Alone Worker Sessions (Gas Safety & Live Countdown)',
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
    if (widget.safetyLogs.isEmpty) {
      return const Center(child: Text('No active alone worker sessions.'));
    }
    return ListView.builder(
      itemCount: widget.safetyLogs.length,
      itemBuilder: (context, idx) {
        final job = widget.safetyLogs[idx];
        final done = job['status'] == 'done' || job['status'] == 'completed';
        final isAlarm = job['alarm_triggered'] == true;

        String getTimerString() {
          if (done) {
            return 'Completed';
          }
          if (job['started_at'] == null) {
            return 'Pending';
          }
          final startedAt = DateTime.parse(job['started_at'] as String);
          final limitMins = job['time_limit_minutes'] as int;
          final deadline = startedAt.add(Duration(minutes: limitMins));
          final remaining = deadline.difference(DateTime.now());
          if (remaining.isNegative) {
            return 'EXPIRED (ALARM)';
          }
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        }

        final timerStr = getTimerString();
        final isExpired = timerStr.contains('EXPIRED') || isAlarm;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isExpired
              ? Colors.red.withOpacity(0.08)
              : (widget.isDark ? const Color(0xFF2E2E2E) : Colors.grey.shade50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isExpired
                  ? Colors.red
                  : (done ? Colors.green : Colors.grey.shade300),
              width: isExpired ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isExpired
                                ? Icons.warning_rounded
                                : (done ? Icons.check_circle_rounded : Icons.timer_outlined),
                            color: isExpired
                                ? Colors.red
                                : (done ? Colors.green : Colors.blue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${job['assignee']} — Room ${job['room_name']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.red
                            : (done ? Colors.green : Colors.orange),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isExpired
                            ? 'ALARM'
                            : (done ? 'COMPLETED' : 'ACTIVE'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (job['co_level'] != null) ...[
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text('CO: ${job['co_level']} ppm',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 20),
                    ],
                    if (job['co2_level'] != null) ...[
                      Icon(Icons.cloud_queue_rounded,
                          size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('CO₂: ${job['co2_level']} ppm',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (job['check_in_time'] != null) ...[
                      Text(
                        'Check In: ${DateTime.parse(job['check_in_time'] as String).toLocal().toString().substring(11, 16)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 20),
                    ],
                    if (job['check_out_time'] != null) ...[
                      Text(
                        'Check Out: ${DateTime.parse(job['check_out_time'] as String).toLocal().toString().substring(11, 16)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                if (!done) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Limit: ${job['time_limit_minutes']} mins',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Remaining: $timerStr',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
