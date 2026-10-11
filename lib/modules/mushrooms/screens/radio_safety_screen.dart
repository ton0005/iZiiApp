import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';
import '../../../core/events/app_event_bus.dart';
import '../services/radio_gateway_service.dart';

/// Hytera radio alarms (SOS / Man Down / Lone Worker) and radio ↔ employee
/// assignment. Alarms linked to an Alone Worker job ALSO raise the normal job
/// alarm through sync; this screen is where unlinked alarms surface and where
/// a supervisor records that they are responding.
class RadioSafetyScreen extends StatefulWidget {
  final int initialTab;
  const RadioSafetyScreen({super.key, this.initialTab = 0});

  @override
  State<RadioSafetyScreen> createState() => _RadioSafetyScreenState();
}

class _RadioSafetyScreenState extends State<RadioSafetyScreen> {
  final _service = RadioGatewayService();
  StreamSubscription<AppDomainEvent>? _eventSub;
  Timer? _pollTimer;

  List<RadioAlarm> _alarms = [];
  List<RadioDevice> _devices = [];
  bool _showHistory = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
    _eventSub = AppEventBus().on('mushroom.radio_alarm').listen((_) => _reload());
    // WebSocket can drop on factory Wi-Fi; polling is the safety net.
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _reload(quiet: true));
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool quiet = false}) async {
    if (!quiet && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.listAlarms(activeOnly: !_showHistory),
        _service.listDevices(),
      ]);
      if (!mounted) return;
      setState(() {
        _alarms = results[0] as List<RadioAlarm>;
        _devices = results[1] as List<RadioDevice>;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = RadioGatewayService.describeError(e);
        _loading = false;
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _alarms.where((a) => a.needsAction).length;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hytera Radios — Lone Worker / Man Down'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _reload,
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: activeCount > 0,
                label: Text('$activeCount'),
                child: const Icon(Icons.sos),
              ),
              text: 'Radio Alarms',
            ),
            const Tab(icon: Icon(Icons.settings_input_antenna), text: 'Radios'),
          ]),
        ),
        body: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              MaterialBanner(
                backgroundColor: Colors.orange.shade50,
                leading: const Icon(Icons.cloud_off, color: Colors.orange),
                content: Text(_error!),
                actions: [TextButton(onPressed: _reload, child: const Text('RETRY'))],
              ),
            Expanded(
              child: TabBarView(children: [_buildAlarmsTab(), _buildDevicesTab()]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Alarms tab ────────────────────────────────────────────────────────────

  Widget _buildAlarmsTab() {
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          title: const Text('Show history (acknowledged & info events)'),
          value: _showHistory,
          onChanged: (v) {
            setState(() => _showHistory = v);
            _reload();
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: _alarms.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No radio alarms. Radios report SOS, Man Down and Lone Worker '
                        'timeouts here through the dispatch gateway.',
                        textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _alarms.length,
                    itemBuilder: (_, i) => _buildAlarmCard(_alarms[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAlarmCard(RadioAlarm a) {
    final urgent = a.needsAction;
    final color = urgent ? Colors.red : Colors.grey;
    final when = a.receivedAt != null ? DateFormat('HH:mm:ss dd/MM').format(a.receivedAt!) : '--';
    final ago = a.receivedAt != null ? _ago(a.receivedAt!) : '';

    return Card(
      color: urgent ? Colors.red.withValues(alpha: 0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color, width: urgent ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(a.eventType == 'man_down' ? Icons.personal_injury : Icons.sos, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${a.label} — ${a.holder}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color.shade700, fontSize: 15)),
                ),
                _statusChip(a),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text('Radio ${a.radioId}${a.system != null ? ' (${a.system!.toUpperCase()})' : ''}'),
                Text('$when  ($ago)'),
                if (a.repeatCount > 0) Text('${a.repeatCount + 1}× received'),
                if (a.jobId != null)
                  const Text('Linked to Alone Worker job — job alarm raised',
                      style: TextStyle(color: Colors.deepOrange)),
              ],
            ),
            if (a.isUnbound) ...[
              const SizedBox(height: 6),
              const Text(
                'This radio is not assigned to anyone. Find who carries it and assign it in the Radios tab.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ] else if (a.jobId == null && urgent) ...[
              const SizedBox(height: 6),
              const Text('No running Alone Worker job for this person — locate them by radio.',
                  style: TextStyle(color: Colors.deepOrange)),
            ],
            if (a.status == 'cancelled_on_radio') ...[
              const SizedBox(height: 6),
              const Text('Emergency was cancelled on the radio. Confirm the worker is safe before acknowledging.'),
            ],
            if (a.ackedBy != null) ...[
              const SizedBox(height: 6),
              Text('Acknowledged by ${a.ackedBy}'
                  '${a.ackedAt != null ? ' at ${DateFormat('HH:mm dd/MM').format(a.ackedAt!)}' : ''}'
                  '${(a.ackNote ?? '').isNotEmpty ? ' — ${a.ackNote}' : ''}'),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (a.hasLocation)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text('${a.latitude!.toStringAsFixed(5)}, ${a.longitude!.toStringAsFixed(5)}'),
                    onPressed: () => _openMap(a.latitude!, a.longitude!),
                  )
                else
                  const Text('No GPS fix', style: TextStyle(color: Colors.grey)),
                const Spacer(),
                if (urgent)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                    icon: const Icon(Icons.how_to_reg, size: 18),
                    label: const Text('I AM RESPONDING'),
                    onPressed: () => _acknowledge(a),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(RadioAlarm a) {
    final (text, color) = switch (a.status) {
      'open' => ('OPEN', Colors.red),
      'cancelled_on_radio' => ('CANCELLED ON RADIO', Colors.orange),
      'acknowledged' => ('ACKNOWLEDGED', Colors.green),
      _ => (a.status.toUpperCase(), Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Could not open map. Coordinates: $lat, $lng', error: true);
    }
  }

  Future<void> _acknowledge(RadioAlarm a) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Respond to ${a.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${a.holder} — radio ${a.radioId}'),
            const SizedBox(height: 8),
            const Text('This records that you are responding. The Alone Worker job alarm stays '
                'on until the worker is checked in from the job screen.'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (e.g. called on radio, heading to Room 52A)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Acknowledge')),
        ],
      ),
    );
    final note = noteCtrl.text;
    noteCtrl.dispose();
    if (ok != true) return;
    try {
      await _service.acknowledge(a.id, note: note);
      _toast('Alarm acknowledged.');
      await _reload();
    } catch (e) {
      _toast(RadioGatewayService.describeError(e), error: true);
    }
  }

  // ── Radios tab ────────────────────────────────────────────────────────────

  Widget _buildDevicesTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add radio'),
        onPressed: () => _editDevice(null),
      ),
      body: _devices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No radios yet. Radios appear automatically after their first '
                    'report through the gateway, or add one by Radio ID / ISSI.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: _devices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _buildDeviceTile(_devices[i]),
            ),
    );
  }

  Widget _buildDeviceTile(RadioDevice d) {
    final seen = d.lastSeenAt != null ? 'last seen ${_ago(d.lastSeenAt!)}' : 'never seen';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: d.isAssigned ? Colors.teal.shade100 : Colors.red.shade100,
        child: Icon(Icons.settings_input_antenna,
            color: d.isAssigned ? Colors.teal.shade800 : Colors.red.shade800),
      ),
      title: Text('${d.radioId}  ·  ${d.model ?? 'Hytera'} (${d.system.toUpperCase()})'
          '${(d.label ?? '').isNotEmpty ? '  ·  ${d.label}' : ''}'),
      subtitle: Text(
        '${d.isAssigned ? 'Carried by ${d.employeeName ?? d.employeeId}' : 'NOT ASSIGNED'}'
        '  ·  $seen'
        '${d.lastBattery != null ? '  ·  battery ${d.lastBattery!.toStringAsFixed(0)}%' : ''}'
        '${d.active ? '' : '  ·  inactive'}',
        style: TextStyle(color: d.isAssigned ? null : Colors.red),
      ),
      onTap: () => _editDevice(d),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          switch (v) {
            case 'edit':
              _editDevice(d);
            case 'test':
              _simulate(d);
            case 'delete':
              _delete(d);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Assign / edit')),
          PopupMenuItem(value: 'test', child: Text('Send test alarm…')),
          PopupMenuItem(value: 'delete', child: Text('Remove radio')),
        ],
      ),
    );
  }

  Future<void> _editDevice(RadioDevice? d) async {
    final db = AppDatabase();
    final employees = await (db.select(db.mushroomEmployees)
          ..where((t) => t.status.equals('active'))
          ..orderBy([(t) => drift.OrderingTerm(expression: t.name)]))
        .get();
    if (!mounted) return;

    final idCtrl = TextEditingController(text: d?.radioId ?? '');
    final labelCtrl = TextEditingController(text: d?.label ?? '');
    final modelCtrl = TextEditingController(text: d?.model ?? '');
    String system = d?.system ?? 'dmr';
    bool active = d?.active ?? true;
    String? employeeId = d?.employeeId;
    if (employeeId != null && !employees.any((e) => e.id == employeeId)) employeeId = null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(d == null ? 'Add radio' : 'Radio ${d.radioId}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idCtrl,
                    enabled: d == null,
                    decoration: const InputDecoration(
                      labelText: 'Radio ID (DMR) / ISSI (TETRA)',
                      helperText: 'Must match the ID programmed in Hytera CPS',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: employeeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Carried by'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('— Not assigned —')),
                      ...employees.map((e) => DropdownMenuItem<String?>(
                            value: e.id,
                            child: Text('${e.name} (${e.id})${e.department != null ? ' · ${e.department}' : ''}'),
                          )),
                    ],
                    onChanged: (v) => setDlg(() => employeeId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(labelText: 'Model (e.g. HP682, HP782, HP792Ex, PT580H)'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: system,
                    decoration: const InputDecoration(labelText: 'Network'),
                    items: const [
                      DropdownMenuItem(value: 'dmr', child: Text('DMR (HP6xx / HP7xx)')),
                      DropdownMenuItem(value: 'tetra', child: Text('TETRA (PT580H)')),
                    ],
                    onChanged: (v) => setDlg(() => system = v ?? 'dmr'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(labelText: 'Label (e.g. Growing #3)'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setDlg(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    final radioId = idCtrl.text.trim();
    final label = labelCtrl.text.trim();
    final model = modelCtrl.text.trim();
    idCtrl.dispose();
    labelCtrl.dispose();
    modelCtrl.dispose();
    if (saved != true) return;
    if (radioId.isEmpty) {
      _toast('Radio ID is required.', error: true);
      return;
    }

    final emp = employees.where((e) => e.id == employeeId).firstOrNull;
    try {
      await _service.saveDevice(
        radioId: radioId,
        employeeId: emp?.id,
        employeeName: emp?.name,
        label: label.isEmpty ? null : label,
        model: model.isEmpty ? null : model,
        system: system,
        active: active,
      );
      _toast('Radio $radioId saved.');
      await _reload();
    } catch (e) {
      _toast(RadioGatewayService.describeError(e), error: true);
    }
  }

  Future<void> _simulate(RadioDevice d) async {
    String eventType = 'SOS';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Send test alarm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Runs the real alarm pipeline. If the holder has a running Alone Worker '
                  'job, a REAL job alarm will be raised on every device. Warn the shift first.',
                  style: TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: eventType,
                items: const [
                  DropdownMenuItem(value: 'SOS', child: Text('SOS (emergency key)')),
                  DropdownMenuItem(value: 'MAN_DOWN', child: Text('Man Down')),
                  DropdownMenuItem(value: 'LONE_WORKER', child: Text('Lone Worker timeout')),
                ],
                onChanged: (v) => setDlg(() => eventType = v ?? 'SOS'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _service.simulate(d.radioId, eventType);
      _toast('Test alarm sent for radio ${d.radioId}.');
      await _reload();
    } catch (e) {
      _toast(RadioGatewayService.describeError(e), error: true);
    }
  }

  Future<void> _delete(RadioDevice d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove radio ${d.radioId}?'),
        content: const Text('Alarm history is kept. If this radio reports again it will reappear as unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteDevice(d.radioId);
      await _reload();
    } catch (e) {
      _toast(RadioGatewayService.describeError(e), error: true);
    }
  }
}

/// Compact red banner for the Safety tab: active radio alarms at a glance.
class RadioAlarmBanner extends StatefulWidget {
  const RadioAlarmBanner({super.key});

  @override
  State<RadioAlarmBanner> createState() => _RadioAlarmBannerState();
}

class _RadioAlarmBannerState extends State<RadioAlarmBanner> {
  StreamSubscription<AppDomainEvent>? _sub;
  Timer? _timer;
  List<RadioAlarm> _active = [];

  @override
  void initState() {
    super.initState();
    _load();
    _sub = AppEventBus().on('mushroom.radio_alarm').listen((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final alarms = await RadioGatewayService().listAlarms();
      if (mounted) setState(() => _active = alarms.where((a) => a.needsAction).toList());
    } catch (_) {
      // Server unreachable / not authorised: the full screen shows the reason.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAlarm = _active.isNotEmpty;
    return Material(
      color: hasAlarm ? Colors.red.shade700 : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RadioSafetyScreen()),
          );
          _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: hasAlarm
              ? null
              : BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E0D9)),
                  borderRadius: BorderRadius.circular(10),
                ),
          child: Row(
            children: [
              Icon(hasAlarm ? Icons.sos : Icons.settings_input_antenna,
                  color: hasAlarm ? Colors.white : null, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasAlarm
                      ? '${_active.length} RADIO ALARM${_active.length > 1 ? 'S' : ''}: '
                          '${_active.map((a) => '${a.label} · ${a.holder}').join(', ')}'
                      : 'Hytera radios — no active alarms',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasAlarm ? Colors.white : null,
                    fontWeight: hasAlarm ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: hasAlarm ? Colors.white : null),
            ],
          ),
        ),
      ),
    );
  }
}
