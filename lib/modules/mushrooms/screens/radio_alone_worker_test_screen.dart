import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/session/work_session_service.dart';
import '../../../core/sync/sync_service.dart';
import '../repository.dart';
import '../services/job_list_service.dart';
import '../services/manager_attendance_service.dart';
import '../services/radio_gateway_service.dart';

/// Step-by-step test of Alone Worker with a Hytera radio, using the REAL app, server and bridge paths:
///
///   1. Check the worker in (manager batch check-in)
///   2. Register a radio to them for this shift
///   3. Ask the radio whether Lone Worker is on; turn it on/off
///   4. Start an Alone Worker job (short time limit)
///   5. When the app timer expires, confirm the server sent a message to that radio and the radio
///      acknowledged it
///
/// Needs iZiiServer, radio_bridge and a radio (or `python -m radio_bridge.simulator --scenario serve`).
class RadioAloneWorkerTestScreen extends StatefulWidget {
  final String initialRadioId;
  final String preferredEmployeeName;

  const RadioAloneWorkerTestScreen({
    super.key,
    this.initialRadioId = '507',
    this.preferredEmployeeName = 'Andrew',
  });

  @override
  State<RadioAloneWorkerTestScreen> createState() => _RadioAloneWorkerTestScreenState();
}

class _LogLine {
  final DateTime at;
  final String text;
  final bool? ok; // null = info
  _LogLine(this.text, {this.ok}) : at = DateTime.now();
}

class _RadioAloneWorkerTestScreenState extends State<RadioAloneWorkerTestScreen> {
  final _radio = RadioGatewayService();
  final _db = AppDatabase();
  late final TextEditingController _radioCtrl = TextEditingController(text: widget.initialRadioId);

  List<MushroomEmployee> _employees = [];
  List<GrowRoom> _rooms = [];
  MushroomEmployee? _employee;
  GrowRoom? _room;
  int _limitMinutes = 1;

  bool? _onShift;
  RadioDevice? _device;
  RadioCommand? _lwCommand;
  MushroomJob? _job;
  List<RadioCommand> _commands = [];
  List<RadioAlarm> _alarms = [];
  DateTime? _alarmSeenAt;
  bool _autoTimeoutFired = false;

  String? _busy; // which action is running
  final List<_LogLine> _log = [];
  Timer? _tick;
  int _tickCount = 0;

  String get _radioId => _radioCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _radioCtrl.dispose();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _loadLocal() async {
    final emps = await (_db.select(_db.mushroomEmployees)
          ..where((t) => t.status.equals('active'))
          ..orderBy([(t) => drift.OrderingTerm(expression: t.name)]))
        .get();
    final rooms = await (_db.select(_db.growRooms)..orderBy([(t) => drift.OrderingTerm(expression: t.name)])).get();
    if (!mounted) return;
    final want = widget.preferredEmployeeName.toLowerCase();
    setState(() {
      _employees = emps;
      _rooms = rooms;
      _employee ??= emps.where((e) => e.name.toLowerCase().contains(want)).firstOrNull;
      _room ??= rooms.firstOrNull;
    });
    await _refreshOnShift();
    await _refreshRemote();
  }

  Future<void> _refreshOnShift() async {
    final emp = _employee;
    if (emp == null) return;
    final on = await WorkSessionService().isPersonOnShift(emp.name);
    if (mounted) setState(() => _onShift = on);
  }

  Future<void> _refreshRemote() async {
    if (_radioId.isEmpty) return;
    try {
      final results = await Future.wait([
        _radio.listDevices(),
        _radio.listCommands(radioId: _radioId, limit: 30),
        _radio.listAlarms(activeOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _device = (results[0] as List<RadioDevice>).where((d) => d.radioId == _radioId).firstOrNull;
        _commands = results[1] as List<RadioCommand>;
        _alarms = (results[2] as List<RadioAlarm>).where((a) => a.radioId == _radioId).toList();
      });
    } catch (_) {
      // Shown when the user runs an action; polling stays quiet.
    }
  }

  Future<void> _refreshJob() async {
    final id = _job?.id;
    if (id == null) return;
    final job = await (_db.select(_db.mushroomJobs)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (mounted) setState(() => _job = job);
  }

  void _onTick() {
    _tickCount++;
    if (!mounted) return;
    setState(() {}); // countdown
    final job = _job;
    // Same check the app runs every 30 s (MushroomsBloc → checkSoloJobsAlarms), run once at expiry.
    if (job != null && job.status == 'in_progress' && job.alarmTriggered != true && !_autoTimeoutFired) {
      final remaining = _remaining(job);
      if (remaining != null && remaining <= Duration.zero) {
        _autoTimeoutFired = true;
        _act('timeout', () async {
          await MushroomsRepository().checkSoloJobsAlarms();
          await SyncService().triggerSync();
          await _refreshJob();
          _addLog('Alone Worker timer expired in the app → job alarm raised and synced', ok: true);
        });
      }
    }
    if (_tickCount % 3 == 0) {
      _refreshRemote();
      _refreshJob();
    }
    final alarmed = _job?.alarmTriggered == true;
    if (alarmed && _alarmSeenAt == null) _alarmSeenAt = DateTime.now();
  }

  Duration? _remaining(MushroomJob job) {
    final start = job.startedAt;
    if (start == null) return null;
    return start.add(Duration(minutes: job.timeLimitMinutes ?? 45)).difference(DateTime.now());
  }

  RadioCommand? get _timeoutCommand {
    final job = _job;
    if (job == null) return null;
    return _commands.where((c) => c.reason == 'alone_worker_timeout' && c.jobId == job.id).firstOrNull;
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void _addLog(String text, {bool? ok}) {
    if (!mounted) return;
    setState(() => _log.insert(0, _LogLine(text, ok: ok)));
  }

  Future<void> _act(String key, Future<void> Function() body) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      await body();
    } catch (e) {
      _addLog(RadioGatewayService.describeError(e).replaceFirst('Exception: ', ''), ok: false);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _checkIn() => _act('checkin', () async {
        final emp = _employee!;
        final res = await ManagerAttendanceService().batchCheckIn(employeeIds: [emp.id], note: 'Radio Alone Worker test');
        await SyncService().triggerSync();
        await _refreshOnShift();
        _addLog('Check-in ${emp.name}: ${res.successCount}/${res.totalRequested} — on shift: ${_onShift == true ? 'yes' : 'no'}',
            ok: _onShift == true);
      });

  Future<void> _registerRadio() => _act('register', () async {
        final emp = _employee!;
        final prev = _device;
        await _radio.saveDevice(
          radioId: _radioId,
          employeeId: emp.id,
          employeeName: emp.name,
          model: prev?.model ?? 'HP682',
          label: 'Shift ${DateFormat('dd/MM').format(DateTime.now())}',
        );
        await _refreshRemote();
        final from = (prev?.isAssigned ?? false) && prev!.employeeId != emp.id ? ' (was ${prev.employeeName ?? prev.employeeId})' : '';
        _addLog('Radio $_radioId registered to ${emp.name} for this shift$from', ok: true);
      });

  Future<void> _loneWorker(String command) => _act(command, () async {
        _addLog('Sending "$command" to radio $_radioId…');
        final cmd = await _radio.runCommand(_radioId, command);
        await _refreshRemote();
        setState(() => _lwCommand = cmd);
        if (cmd.isOk) {
          _addLog('Radio $_radioId answered: Lone Worker ${(cmd.loneWorker ?? '?').toUpperCase()}', ok: true);
        } else {
          _addLog('Radio $_radioId: ${cmd.isFinished ? (cmd.error ?? cmd.status) : 'no answer yet (status ${cmd.status})'}',
              ok: false);
        }
      });

  Future<void> _startJob() => _act('job', () async {
        final emp = _employee!;
        final room = _room!;
        await JobListServiceImpl().addSpecialSoloJob(room.id, 'Radio test - Alone Worker', emp.name, _limitMinutes);
        await SyncService().triggerSync();
        final job = await (_db.select(_db.mushroomJobs)
              ..where((t) =>
                  t.assignee.equals(emp.name) &
                  t.status.equals('in_progress') &
                  (t.isSoloJob.equals(true) | t.jobType.equals('alone_worker')))
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
        setState(() {
          _job = job;
          _autoTimeoutFired = false;
          _alarmSeenAt = null;
        });
        _addLog('Alone Worker job started for ${emp.name} in ${room.name}, limit $_limitMinutes min', ok: job != null);
      });

  Future<void> _forceTimeout() => _act('timeout', () async {
        _autoTimeoutFired = true;
        await MushroomsRepository().triggerSafetyAlarm(_job!.id);
        await SyncService().triggerSync();
        await _refreshJob();
        _addLog('Forced timeout: job alarm raised and synced to the server', ok: true);
      });

  Future<void> _workerCheckedIn() => _act('reset', () async {
        await JobListServiceImpl().checkInSoloJob(_job!.id);
        await SyncService().triggerSync();
        await _refreshJob();
        setState(() {
          _autoTimeoutFired = false;
          _alarmSeenAt = null;
        });
        _addLog('Worker checked in on the job — timer restarted, alarm cleared', ok: true);
      });

  Future<void> _completeJob() => _act('complete', () async {
        await JobListServiceImpl().completeJob(_job!.id);
        await SyncService().triggerSync();
        _addLog('Test job completed', ok: true);
        setState(() => _job = null);
      });

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test: Alone Worker × Hytera radio'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () {
            _refreshOnShift();
            _refreshRemote();
            _refreshJob();
          }),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _prerequisites(),
              _step1(),
              _step2(),
              _step3(),
              _step4(),
              _step5(),
              _logCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prerequisites() {
    final seen = _device?.isRecentlySeen() ?? false;
    const simCmd = 'python -m radio_bridge.simulator --target <bridge-ip>:3005 --radio 507 --scenario serve';
    return Card(
      color: Colors.blueGrey.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Before you start', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('• iZiiServer reachable (Sync Server settings), with IZIIAPP_RADIO_GATEWAY_SECRET set\n'
                '• radio_bridge running next to the HR1062 (or on this PC)\n'
                '• The radio switched on — or the HP682 simulator running:'),
            const SizedBox(height: 6),
            Row(children: [
              const Expanded(
                child: SelectableText(simCmd, style: TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => Clipboard.setData(const ClipboardData(text: simCmd)),
              ),
            ]),
            const SizedBox(height: 4),
            _chip(
              _device == null
                  ? 'Radio $_radioId not known to the server yet'
                  : seen
                      ? 'Radio $_radioId online — last seen ${_ago(_device!.lastSeenAt!)}'
                      : 'Radio $_radioId not heard from recently${_device!.lastSeenAt != null ? ' (last ${_ago(_device!.lastSeenAt!)})' : ''}',
              _device == null ? null : seen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _step1() {
    final emp = _employee;
    return _StepCard(
      number: 1,
      title: 'Check the worker in',
      done: _onShift == true,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<MushroomEmployee>(
              initialValue: emp,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Worker', isDense: true),
              items: _employees
                  .map((e) => DropdownMenuItem(value: e, child: Text('${e.name} (${e.id})', overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (e) {
                setState(() {
                  _employee = e;
                  _onShift = null;
                });
                _refreshOnShift();
              },
            ),
          ),
          FilledButton.icon(
            icon: _spin('checkin', Icons.login),
            label: const Text('Check in'),
            onPressed: emp == null || _busy != null ? null : _checkIn,
          ),
          if (_onShift != null) _chip(_onShift! ? 'On shift' : 'Not checked in', _onShift),
        ],
      ),
    );
  }

  Widget _step2() {
    final d = _device;
    final emp = _employee;
    final mine = d != null && emp != null && d.employeeId == emp.id;
    return _StepCard(
      number: 2,
      title: 'Register the radio for this shift',
      done: mine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _radioCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Radio ID', isDense: true),
                  onSubmitted: (_) => _refreshRemote(),
                ),
              ),
              FilledButton.icon(
                icon: _spin('register', Icons.settings_input_antenna),
                label: Text('Give radio $_radioId to ${emp?.name ?? '…'}'),
                onPressed: emp == null || _radioId.isEmpty || _busy != null ? null : _registerRadio,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(d == null
              ? 'Radio $_radioId is not registered yet.'
              : 'Radio ${d.radioId} · ${d.model ?? 'Hytera'} · carried by ${d.isAssigned ? (d.employeeName ?? d.employeeId) : 'nobody'}'),
        ],
      ),
    );
  }

  Widget _step3() {
    final state = _device?.loneWorkerState;
    final last = _lwCommand;
    return _StepCard(
      number: 3,
      title: 'Is Lone Worker on at the radio?',
      done: state == 'on',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: _spin('lone_worker_status', Icons.help_outline),
              label: const Text('Ask the radio'),
              onPressed: _device == null || _busy != null ? null : () => _loneWorker('lone_worker_status'),
            ),
            FilledButton.icon(
              icon: _spin('lone_worker_enable', Icons.toggle_on),
              label: const Text('Turn ON'),
              onPressed: _device == null || _busy != null ? null : () => _loneWorker('lone_worker_enable'),
            ),
            OutlinedButton.icon(
              icon: _spin('lone_worker_disable', Icons.toggle_off),
              label: const Text('Turn OFF'),
              onPressed: _device == null || _busy != null ? null : () => _loneWorker('lone_worker_disable'),
            ),
          ]),
          const SizedBox(height: 8),
          _chip(
            state == null
                ? 'Not asked yet'
                : 'Lone Worker ${state.toUpperCase()}'
                    '${_device?.loneWorkerCheckedAt != null ? ' — radio answered ${_ago(_device!.loneWorkerCheckedAt!)}' : ''}',
            state == null ? null : state == 'on',
          ),
          if (last != null && !last.isOk) ...[
            const SizedBox(height: 6),
            Text('Last request: ${last.error ?? last.status}', style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 6),
          const Text(
            'With Lone Worker ON, the radio itself beeps after its Response Time and raises an emergency if '
            'nobody presses a key — that alarm shows in step 5 under "Alarms from radio".',
            style: TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _step4() {
    final job = _job;
    final remaining = job == null ? null : _remaining(job);
    return _StepCard(
      number: 4,
      title: 'Start an Alone Worker job',
      done: job != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<GrowRoom>(
                  initialValue: _room,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Room', isDense: true),
                  items: _rooms.map((r) => DropdownMenuItem(value: r, child: Text(r.name))).toList(),
                  onChanged: (r) => setState(() => _room = r),
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int>(
                  initialValue: _limitMinutes,
                  decoration: const InputDecoration(labelText: 'Time limit', isDense: true),
                  items: const [1, 2, 5, 10]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: (m) => setState(() => _limitMinutes = m ?? 1),
                ),
              ),
              FilledButton.icon(
                icon: _spin('job', Icons.play_arrow),
                label: const Text('Start job'),
                onPressed: _employee == null || _room == null || _busy != null || job != null ? null : _startJob,
              ),
            ],
          ),
          if (job != null) ...[
            const SizedBox(height: 8),
            Text('${job.name} · ${job.assignee} · status ${job.status}'
                '${remaining != null && job.alarmTriggered != true ? ' · time out in ${_fmt(remaining)}' : ''}'),
          ],
        ],
      ),
    );
  }

  Widget _step5() {
    final job = _job;
    final alarmed = job?.alarmTriggered == true;
    final cmd = _timeoutCommand;
    final waiting = alarmed && cmd == null && _alarmSeenAt != null ? DateTime.now().difference(_alarmSeenAt!) : null;

    Widget status;
    if (job == null) {
      status = const Text('Start a job in step 4 first.');
    } else if (!alarmed) {
      final r = _remaining(job);
      status = _chip(r == null ? 'Timer not started' : 'Waiting for time out (${_fmt(r)})', null);
    } else if (cmd == null) {
      status = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _chip('Job alarm raised — waiting for the server to queue a message for radio $_radioId', null),
        if (waiting != null && waiting.inSeconds > 20)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Nothing queued yet. Check: the job assignee is the person holding this radio (step 2), '
              'this device synced (Sync screen), and the server has the radio_commands update.',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),
      ]);
    } else {
      final ok = cmd.isOk;
      status = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _chip(
          switch (cmd.status) {
            'done' => 'Radio $_radioId confirmed it received the message',
            'pending' => 'Message queued — waiting for the bridge',
            'sent' => 'Bridge is sending it to the radio…',
            _ => 'Not delivered: ${cmd.error ?? cmd.status}',
          },
          cmd.isFinished ? ok : null,
        ),
        const SizedBox(height: 6),
        Text('“${cmd.text ?? ''}”', style: const TextStyle(fontStyle: FontStyle.italic)),
      ]);
    }

    return _StepCard(
      number: 5,
      title: 'After time out: is radio $_radioId notified?',
      done: cmd?.isOk == true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          status,
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: _spin('timeout', Icons.timer_off),
              label: const Text('Force time out now'),
              onPressed: job == null || alarmed || _busy != null ? null : _forceTimeout,
            ),
            OutlinedButton.icon(
              icon: _spin('reset', Icons.how_to_reg),
              label: Text('${job?.assignee ?? 'Worker'} checked in'),
              onPressed: job == null || _busy != null ? null : _workerCheckedIn,
            ),
            TextButton.icon(
              icon: _spin('complete', Icons.check),
              label: const Text('Complete test job'),
              onPressed: job == null || _busy != null ? null : _completeJob,
            ),
          ]),
          const Divider(height: 24),
          Text('Alarms from radio $_radioId (${_alarms.length} active)',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_alarms.isEmpty)
            const Text('None.', style: TextStyle(color: Colors.grey))
          else
            ..._alarms.map((a) => Text('• ${a.label} · ${a.status}'
                '${a.receivedAt != null ? ' · ${DateFormat('HH:mm:ss').format(a.receivedAt!)}' : ''}'
                '${a.jobId != null ? ' · linked to job' : ''}')),
          const SizedBox(height: 10),
          Text('Commands sent to radio $_radioId', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_commands.isEmpty)
            const Text('None.', style: TextStyle(color: Colors.grey))
          else
            ..._commands.take(8).map(_commandRow),
        ],
      ),
    );
  }

  Widget _commandRow(RadioCommand c) {
    final color = c.isOk ? Colors.green : (c.isFinished ? Colors.red : Colors.orange);
    final what = c.command == 'text_message' ? 'Message' : c.command.replaceAll('_', ' ');
    final detail = c.isOk
        ? (c.loneWorker != null ? 'Lone Worker ${c.loneWorker!.toUpperCase()}' : 'delivered')
        : (c.error ?? c.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(c.createdAt != null ? DateFormat('HH:mm:ss').format(c.createdAt!) : '--:--:--',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$what${c.reason == 'alone_worker_timeout' ? ' (time out)' : ''} — ${c.status}: $detail',
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _logCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test log', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (_log.isEmpty) const Text('No actions yet.', style: TextStyle(color: Colors.grey)),
            ..._log.take(40).map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(DateFormat('HH:mm:ss').format(l.at),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                    const SizedBox(width: 8),
                    Icon(
                      l.ok == null ? Icons.info_outline : (l.ok! ? Icons.check_circle : Icons.error),
                      size: 16,
                      color: l.ok == null ? Colors.blueGrey : (l.ok! ? Colors.green : Colors.red),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(l.text)),
                  ]),
                )),
          ],
        ),
      ),
    );
  }

  // ── small helpers ─────────────────────────────────────────────────────────

  Widget _spin(String key, IconData icon) => _busy == key
      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
      : Icon(icon, size: 18);

  Widget _chip(String text, bool? ok) {
    final color = ok == null ? Colors.blueGrey : (ok ? Colors.green : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color.shade800, fontWeight: FontWeight.w600)),
    );
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00';
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    return '${d.inHours} h ago';
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final bool done;
  final Widget child;

  const _StepCard({required this.number, required this.title, required this.done, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: done ? Colors.green : Colors.blueGrey.shade300,
                child: done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text('$number', style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
