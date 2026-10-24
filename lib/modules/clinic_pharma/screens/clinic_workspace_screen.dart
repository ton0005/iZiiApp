import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../repository.dart';
import 'dtqg_status_pane.dart';
import 'pos_sale_pane.dart';
import '../services/dtqg_rules.dart';

const _kPrimary = Color(0xFF0EA5E9);
const _kGradient = LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)]);

/// Width breakpoints for the clinic workspace.
/// >= [_kDesktop]: extended navigation rail + multi-pane layouts (PC).
/// >= [_kTablet]:  compact rail, panes sized for landscape/portrait iPad.
/// below:          bottom navigation, single pane (phone fallback).
const double _kDesktop = 1100;
const double _kTablet = 700;

String _money(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$buf đ';
}

String _fmtTime(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

String _fmtDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

int? _ageOf(String? dobIso) {
  final dob = DateTime.tryParse(dobIso ?? '');
  if (dob == null) return null;
  final now = DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  return age;
}

class ClinicWorkspaceScreen extends StatefulWidget {
  const ClinicWorkspaceScreen({super.key});

  @override
  State<ClinicWorkspaceScreen> createState() => _ClinicWorkspaceScreenState();
}

class _ClinicWorkspaceScreenState extends State<ClinicWorkspaceScreen> {
  static const _titles = ['Tiếp đón', 'Bệnh nhân', 'Khám bệnh', 'Nhà thuốc', 'Liên thông'];
  static const _icons = [
    Icons.event_available_rounded,
    Icons.people_alt_rounded,
    Icons.description_rounded,
    Icons.medication_rounded,
    Icons.cloud_sync_rounded,
  ];

  int _index = 0;
  Map<String, dynamic>? _visitPatient;
  Map<String, dynamic>? _visitAppointment;
  int _visitKey = 0;

  void _startVisit({Map<String, dynamic>? patient, Map<String, dynamic>? appointment}) {
    setState(() {
      _visitPatient = patient;
      _visitAppointment = appointment;
      _visitKey++; // fresh form state for each new visit
      _index = 2;
    });
  }

  Future<void> _editFacility(BuildContext context) async {
    final repo = ClinicPharmaRepository();
    final f = await repo.getFacility();
    if (!context.mounted) return;
    final cs = TextEditingController(text: f['ma_cskcb']);
    final name = TextEditingController(text: f['name']);
    final addr = TextEditingController(text: f['address']);
    final phone = TextEditingController(text: f['phone']);
    final supplier = TextEditingController(text: f['ma_dinh_danh_cung_ung']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cơ sở khám chữa bệnh'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: cs,
                  maxLength: 5,
                  decoration: const InputDecoration(
                      labelText: 'Mã cơ sở KCB (5 ký tự, từ donthuocquocgia.vn)',
                      helperText: 'Dùng làm 5 ký tự đầu của mã đơn thuốc',
                      border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(
                      labelText: 'Tên cơ sở', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: addr,
                  decoration: const InputDecoration(
                      labelText: 'Địa chỉ', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Điện thoại', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: supplier,
                  decoration: const InputDecoration(
                      labelText: 'Mã định danh cơ sở cung ứng thuốc (nhà thuốc)',
                      helperText: 'Tài khoản liên thông Dược quốc gia — dùng khi bán theo đơn',
                      border: OutlineInputBorder())),
              const SizedBox(height: 10),
              const Text(
                  'Mật khẩu liên thông của cơ sở và bác sĩ không lưu trên thiết bị này; sẽ khai báo ở máy chủ khi kết nối Đơn thuốc quốc gia.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok == true) {
      await repo.saveFacility({
        'ma_cskcb': cs.text,
        'name': name.text,
        'address': addr.text,
        'phone': phone.text,
        'ma_dinh_danh_cung_ung': supplier.text,
      });
    }
    cs.dispose();
    name.dispose();
    addr.dispose();
    phone.dispose();
    supplier.dispose();
  }

  Widget _body() {
    switch (_index) {
      case 0:
        return _ReceptionPane(onStartVisit: (a) => _startVisit(appointment: a));
      case 1:
        return _PatientsPane(onStartVisit: (p) => _startVisit(patient: p));
      case 2:
        return _VisitPane(
          key: ValueKey(_visitKey),
          patient: _visitPatient,
          appointment: _visitAppointment,
          onSaved: () => setState(() {
            _visitPatient = null;
            _visitAppointment = null;
            _visitKey++;
            _index = 3;
          }),
        );
      case 3:
        return const _PharmacyPane();
      default:
        return const DtqgStatusPane();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final isDesktop = w >= _kDesktop;
      final isTablet = w >= _kTablet;

      final appBar = AppBar(
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }),
        title: Text('Phòng khám & Nhà thuốc · ${_titles[_index]}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kGradient)),
        actions: [
          IconButton(
            tooltip: 'Cài đặt cơ sở & liên thông',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _editFacility(context),
          ),
        ],
      );

      if (!isTablet) {
        return Scaffold(
          appBar: appBar,
          body: _body(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (var i = 0; i < _titles.length; i++)
                NavigationDestination(icon: Icon(_icons[i]), label: _titles[i]),
            ],
          ),
        );
      }

      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              extended: isDesktop,
              minExtendedWidth: 200,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: isDesktop ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    label: Text(_titles[i]),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _body()),
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey[600])),
        ]),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.icon, this.label, this.value, {this.color = _kPrimary});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _SectionTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          if (trailing != null) trailing!,
        ]),
      );
}

({Color color, String label}) _apptStatus(String s) {
  switch (s) {
    case 'checked_in':
      return (color: Colors.orange, label: 'Đã check-in');
    case 'completed':
      return (color: Colors.green, label: 'Hoàn tất');
    case 'cancelled':
      return (color: Colors.red, label: 'Đã huỷ');
    case 'no_show':
      return (color: Colors.grey, label: 'Không đến');
    default:
      return (color: _kPrimary, label: 'Đã đặt');
  }
}

// ---------------------------------------------------------------------------
// Reception: today's schedule + stats
// ---------------------------------------------------------------------------

class _ReceptionPane extends StatefulWidget {
  final void Function(Map<String, dynamic> appointment) onStartVisit;
  const _ReceptionPane({required this.onStartVisit});

  @override
  State<_ReceptionPane> createState() => _ReceptionPaneState();
}

class _ReceptionPaneState extends State<_ReceptionPane> {
  final _repo = ClinicPharmaRepository();
  late Future<_ReceptionData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReceptionData> _load() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final today = await _repo.getAppointments(from: start, to: start.add(const Duration(days: 1)));
    final upcoming = await _repo.getAppointments(
        from: start.add(const Duration(days: 1)), status: 'scheduled');
    final patients = await _repo.getPatients();
    final pending = await _repo.getPrescriptionsByStatus();
    final meds = await _repo.getMedicines();
    return _ReceptionData(today, upcoming, patients.length, pending.length,
        meds.where((m) => (m['stock'] as num? ?? 0) < 10).length);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _setStatus(Map<String, dynamic> a, String status) async {
    await _repo.updateAppointmentStatus(a['id'], status);
    _reload();
  }

  Future<void> _book() async {
    final r = await context.push<bool>('/clinic/appointments/form');
    if (r == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReceptionData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        return LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final stats = GridView.count(
            crossAxisCount: c.maxWidth >= 700 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _StatCard(Icons.event_available, 'Lịch hẹn hôm nay', '${d.today.length}'),
              _StatCard(Icons.people_outline, 'Bệnh nhân', '${d.patientCount}',
                  color: Colors.teal),
              _StatCard(Icons.receipt_long, 'Đơn chờ cấp phát', '${d.pendingRx}',
                  color: Colors.orange),
              _StatCard(Icons.warning_amber_rounded, 'Thuốc sắp hết', '${d.lowStock}',
                  color: Colors.red),
            ],
          );

          final todayList = _appointmentList(d.today, actions: true);
          final upcomingList = _appointmentList(d.upcoming.take(8).toList(), actions: false);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stats,
                const SizedBox(height: 16),
                Expanded(
                  child: wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            flex: 3,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _SectionTitle('Hàng đợi hôm nay',
                                  trailing: FilledButton.icon(
                                      onPressed: _book,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Đặt lịch'))),
                              Expanded(child: todayList),
                            ]),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const _SectionTitle('Sắp tới'),
                              Expanded(child: upcomingList),
                            ]),
                          ),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _SectionTitle('Hàng đợi hôm nay',
                              trailing: FilledButton.icon(
                                  onPressed: _book,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Đặt lịch'))),
                          Expanded(child: todayList),
                        ]),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _appointmentList(List<Map<String, dynamic>> items, {required bool actions}) {
    if (items.isEmpty) {
      return const _EmptyState(Icons.event_busy, 'Không có lịch hẹn');
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final a = items[i];
        final st = _apptStatus(a['status'] ?? 'scheduled');
        final open = a['status'] == 'scheduled' || a['status'] == 'checked_in';
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: SizedBox(
              width: 56,
              child: Center(
                child: Text(
                  actions ? _fmtTime(a['scheduled_at']) : _fmtDate(a['scheduled_at']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            title: Text(a['patient_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text([
              if ((a['doctor_name'] as String? ?? '').isNotEmpty) 'BS. ${a['doctor_name']}',
              if ((a['reason'] as String? ?? '').isNotEmpty) a['reason'],
            ].join(' · ')),
            trailing: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(st.label, style: const TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: st.color,
                  visualDensity: VisualDensity.compact,
                ),
                if (actions && a['status'] == 'scheduled')
                  TextButton(
                      onPressed: () => _setStatus(a, 'checked_in'),
                      child: const Text('Check-in')),
                if (actions && open)
                  FilledButton(
                      onPressed: () => widget.onStartVisit(a), child: const Text('Khám')),
                if (actions && open)
                  IconButton(
                    tooltip: 'Không đến',
                    onPressed: () => _setStatus(a, 'no_show'),
                    icon: const Icon(Icons.person_off_outlined),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReceptionData {
  final List<Map<String, dynamic>> today;
  final List<Map<String, dynamic>> upcoming;
  final int patientCount;
  final int pendingRx;
  final int lowStock;
  _ReceptionData(this.today, this.upcoming, this.patientCount, this.pendingRx, this.lowStock);
}

// ---------------------------------------------------------------------------
// Patients: master-detail
// ---------------------------------------------------------------------------

class _PatientsPane extends StatefulWidget {
  final void Function(Map<String, dynamic> patient) onStartVisit;
  const _PatientsPane({required this.onStartVisit});

  @override
  State<_PatientsPane> createState() => _PatientsPaneState();
}

class _PatientsPaneState extends State<_PatientsPane> {
  final _repo = ClinicPharmaRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _search = '';
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _future = _repo.getPatients();
  }

  Future<void> _add() async {
    final r = await context.push<bool>('/clinic/patients/form');
    if (r == true) setState(() => _future = _repo.getPatients());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final split = c.maxWidth >= 800;
      final list = _buildList(split);
      if (!split) return list;
      return Row(children: [
        SizedBox(width: c.maxWidth >= _kDesktop ? 380 : 320, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selected == null
              ? const _EmptyState(Icons.person_search, 'Chọn một bệnh nhân để xem hồ sơ')
              : _PatientDetail(
                  key: ValueKey(_selected!['id']),
                  patient: _selected!,
                  onStartVisit: () => widget.onStartVisit(_selected!),
                ),
        ),
      ]);
    });
  }

  Widget _buildList(bool split) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm tên, SĐT, CCCD/BHYT',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _add, icon: const Icon(Icons.person_add_alt_1)),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final patients = (snap.data ?? []).where((p) {
              if (_search.isEmpty) return true;
              return [p['full_name'], p['phone'], p['id_number']]
                  .any((v) => (v as String? ?? '').toLowerCase().contains(_search));
            }).toList();
            if (patients.isEmpty) {
              return const _EmptyState(Icons.people_outline, 'Chưa có bệnh nhân');
            }
            return ListView.builder(
              itemCount: patients.length,
              itemBuilder: (context, i) {
                final p = patients[i];
                final sel = split && _selected?['id'] == p['id'];
                final age = _ageOf(p['dob']);
                return ListTile(
                  selected: sel,
                  selectedTileColor: _kPrimary.withValues(alpha: 0.08),
                  leading: CircleAvatar(
                    backgroundColor: _kPrimary.withValues(alpha: 0.15),
                    child: Text(((p['full_name'] as String?)?.isNotEmpty ?? false)
                        ? (p['full_name'] as String)[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(p['full_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([
                    if (age != null) '$age tuổi',
                    if ((p['phone'] as String? ?? '').isNotEmpty) p['phone'],
                  ].join(' · ')),
                  onTap: () {
                    if (split) {
                      setState(() => _selected = p);
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(p['full_name'] ?? '')),
                          body: _PatientDetail(
                            patient: p,
                            onStartVisit: () {
                              Navigator.of(context).pop();
                              widget.onStartVisit(p);
                            },
                          ),
                        ),
                      ));
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _PatientDetail extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onStartVisit;
  const _PatientDetail({super.key, required this.patient, required this.onStartVisit});

  String _gender(String? g) =>
      {'male': 'Nam', 'female': 'Nữ', 'other': 'Khác'}[g] ?? '—';

  @override
  Widget build(BuildContext context) {
    final repo = ClinicPharmaRepository();
    final age = _ageOf(patient['dob']);
    Widget info(String k, String? v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text((v == null || v.isEmpty) ? '—' : v)),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Expanded(
            child: Text(patient['full_name'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          FilledButton.icon(
              onPressed: onStartVisit,
              icon: const Icon(Icons.medical_services_outlined),
              label: const Text('Bắt đầu khám')),
        ]),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              info('Ngày sinh', '${_fmtDate(patient['dob'])}${age != null ? ' ($age tuổi)' : ''}'),
              info('Giới tính', _gender(patient['gender'])),
              info('Điện thoại', patient['phone']),
              info('CCCD/BHYT', patient['id_number']),
              info('Địa chỉ', patient['address']),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Lịch sử khám'),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.getVisitsForPatient(patient['id']),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                  padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            final visits = snap.data ?? [];
            if (visits.isEmpty) {
              return const Padding(
                  padding: EdgeInsets.all(24),
                  child: _EmptyState(Icons.history, 'Chưa có lần khám nào'));
            }
            return Column(children: [
              for (final v in visits)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined, color: _kPrimary),
                    title: Text(_fmtDate(v['visit_date']),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text([
                      if ((v['chief_complaint'] as String? ?? '').isNotEmpty)
                        'Lý do: ${v['chief_complaint']}',
                      if ((v['diagnosis'] as String? ?? '').isNotEmpty)
                        'Chẩn đoán: ${v['diagnosis']}',
                    ].join('\n')),
                    isThreeLine: (v['chief_complaint'] as String? ?? '').isNotEmpty &&
                        (v['diagnosis'] as String? ?? '').isNotEmpty,
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Visit: exam form + prescription builder side by side
// ---------------------------------------------------------------------------

class _VisitPane extends StatefulWidget {
  final Map<String, dynamic>? patient;
  final Map<String, dynamic>? appointment;
  final VoidCallback onSaved;
  const _VisitPane({super.key, this.patient, this.appointment, required this.onSaved});

  @override
  State<_VisitPane> createState() => _VisitPaneState();
}

class _VisitPaneState extends State<_VisitPane> {
  final _repo = ClinicPharmaRepository();
  final _complaint = TextEditingController();
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final _medSearch = TextEditingController();
  final _icdCode = TextEditingController();
  final _icdName = TextEditingController();
  final _weight = TextEditingController();
  final _guardian = TextEditingController();
  final _loiDan = TextEditingController();
  final _revisitDays = TextEditingController();
  int _hinhThuc = 2; // chưa kiểm chứng giá trị trong QĐ 808 (plan mục 9)

  late Future<_VisitData> _future;
  Map<String, dynamic>? _patient;
  Map<String, dynamic>? _doctor;
  final List<Map<String, dynamic>> _lines = [];
  bool _dispenseNow = true;
  bool _saving = false;
  String _medFilter = '';

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    final appt = widget.appointment;
    if (appt != null) {
      _complaint.text = appt['reason'] ?? '';
    }
    _prefillGuardian();
    _future = _load();
  }

  Future<_VisitData> _load() async {
    final patients = await _repo.getPatients();
    final doctors = await _repo.getDoctors(activeOnly: true);
    final meds = await _repo.getMedicines();
    final appt = widget.appointment;
    if (appt != null) {
      _patient ??= patients.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p!['id'] == appt['patient_id'],
          orElse: () => null);
      _doctor ??= doctors.cast<Map<String, dynamic>?>().firstWhere(
          (d) => d!['id'] == appt['doctor_id'],
          orElse: () => null);
    }
    return _VisitData(patients, doctors, meds);
  }

  @override
  void dispose() {
    _complaint.dispose();
    _diagnosis.dispose();
    _notes.dispose();
    _medSearch.dispose();
    _icdCode.dispose();
    _icdName.dispose();
    _weight.dispose();
    _guardian.dispose();
    _loiDan.dispose();
    _revisitDays.dispose();
    super.dispose();
  }

  void _prefillGuardian() {
    final p = _patient;
    if (p == null || _guardian.text.isNotEmpty) return;
    final parts = [
      p['guardian_name'],
      p['guardian_phone'],
      p['guardian_address'],
    ].whereType<String>().where((e) => e.trim().isNotEmpty);
    if (parts.isNotEmpty) _guardian.text = parts.join(', ');
  }

  double get _total => _lines.fold(
      0.0, (s, l) => s + (l['quantity'] as num) * (l['unit_price'] as num));

  void _addMedicine(Map<String, dynamic> m) {
    final idx = _lines.indexWhere((l) => l['product_id'] == m['id']);
    setState(() {
      if (idx >= 0) {
        _lines[idx]['quantity'] = (_lines[idx]['quantity'] as num) + 1;
      } else {
        _lines.add({
          'product_id': m['id'],
          'medicine_name': m['name'],
          'quantity': 1.0,
          'unit_price': (m['price'] as num).toDouble(),
          'stock': (m['stock'] as num?)?.toDouble() ?? 0,
          'ma_thuoc_cuc_qldd': (m['custom_fields'] as Map?)?['ma_thuoc_cuc_qldd'],
          'biet_duoc': (m['custom_fields'] as Map?)?['biet_duoc'],
          'don_vi_tinh': (m['custom_fields'] as Map?)?['don_vi_tinh'] ??
              (m['custom_fields'] as Map?)?['dosage_unit'],
          'dosage_instructions': '',
        });
      }
    });
  }

  Future<void> _save() async {
    if (_patient == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng chọn bệnh nhân')));
      return;
    }
    String? nz(String s) => s.trim().isEmpty ? null : s.trim();

    final diagnoses = [
      if (_icdName.text.trim().isNotEmpty || _icdCode.text.trim().isNotEmpty)
        {
          'ma_benh': _icdCode.text.trim(),
          'ten_benh': _icdName.text.trim(),
          'ket_luan': _diagnosis.text.trim(),
        }
    ];
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    final revisit = int.tryParse(_revisitDays.text.trim());
    final facility = await _repo.getFacility();
    final errors = _lines.isEmpty
        ? <String>[]
        : [
            if ((facility['ma_cskcb'] as String).length != 5)
              'Chưa khai báo mã cơ sở KCB (5 ký tự) — vào Cài đặt cơ sở',
            ...DtqgRules.validate(
            patient: _patient!,
            doctor: _doctor,
            diagnoses: diagnoses,
            items: _lines,
            canNang: weight,
            nguoiGiamHo: _guardian.text,
            hinhThucDieuTri: _hinhThuc,
          ),
          ];
    var queueForDtqg = _lines.isNotEmpty && errors.isEmpty;
    if (errors.isNotEmpty) {
      if (!mounted) return;
      final saveDraft = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đơn chưa đủ điều kiện liên thông'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in errors)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.error_outline, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(child: Text(e)),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                        'Đơn đã gửi lên hệ thống quốc gia không sửa/xóa được. Nên bổ sung đủ thông tin trước khi lưu.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('Quay lại sửa')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lưu nháp (chưa liên thông)')),
          ],
        ),
      );
      if (saveDraft != true) return;
      queueForDtqg = false;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final visitId = await _repo.addVisit({
        'id': const Uuid().v4(),
        'patient_id': _patient!['id'],
        'doctor_id': _doctor?['id'],
        'appointment_id': widget.appointment?['id'],
        'chief_complaint': nz(_complaint.text),
        'diagnosis': nz(_diagnosis.text),
        'notes': nz(_notes.text),
        'status': 'completed',
      });

      String? rxId;
      if (_lines.isNotEmpty) {
        final items = [
          for (final l in _lines)
            {
              ...l,
              'dosage_instructions': nz(l['dosage_instructions'] as String? ?? ''),
            }
        ];
        rxId = await _repo.addPrescriptionWithItems({
          'visit_id': visitId,
          'patient_id': _patient!['id'],
          'doctor_id': _doctor?['id'],
          'loai_don': 'c',
          'chan_doan': diagnoses,
          'can_nang': weight,
          'hinh_thuc_dieu_tri': _hinhThuc,
          'nguoi_giam_ho': nz(_guardian.text),
          'loi_dan': nz(_loiDan.text),
          'ngay_tai_kham': revisit,
        }, items);
        if (queueForDtqg) {
          // DtqgGateway (giai đoạn D) sẽ lấy các đơn "queued" để gửi.
          await _repo.setDtqgStatus(rxId, 'queued');
        }
        if (_dispenseNow) {
          try {
            await _repo.dispensePrescription(rxId);
          } catch (e) {
            // Visit and prescription are saved; leave the Rx pending for the
            // pharmacy queue instead of failing the whole visit.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Đã lưu đơn nhưng chưa cấp phát được: $e')));
            }
          }
        }
      }
      if (!mounted) return;

      if (rxId != null) {
        final visit = await _repo.getVisitById(visitId);
        final rxs = await _repo.getPrescriptionsForVisit(visitId);
        final rx = rxs.firstWhere((p) => p['id'] == rxId);
        if (!mounted) return;
        await context.push('/clinic/prescriptions/print', extra: {
          'patient': _patient,
          'doctor': _doctor,
          'visit': visit,
          'prescription': rx,
        });
      }
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_VisitData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        return LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final exam = _examForm(data);
          final rx = _prescriptionPanel(data, scrollable: wide);
          if (wide) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: exam)),
              const VerticalDivider(width: 1),
              Expanded(flex: 6, child: Padding(padding: const EdgeInsets.all(16), child: rx)),
            ]);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [exam, const SizedBox(height: 16), rx]),
          );
        });
      },
    );
  }

  Widget _examForm(_VisitData data) {
    final age = _ageOf(_patient?['dob']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _SectionTitle('Thông tin khám'),
      DropdownButtonFormField<String>(
        initialValue: _patient?['id'] as String?,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Bệnh nhân *',
          prefixIcon: const Icon(Icons.person_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: [
          for (final p in data.patients)
            DropdownMenuItem(value: p['id'] as String, child: Text(p['full_name'] ?? '')),
        ],
        onChanged: (id) => setState(() {
          _patient = data.patients.firstWhere((p) => p['id'] == id);
          _prefillGuardian();
        }),
      ),
      if (_patient != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            [
              if (age != null) '$age tuổi',
              if ((_patient!['phone'] as String? ?? '').isNotEmpty) _patient!['phone'],
              if ((_patient!['address'] as String? ?? '').isNotEmpty) _patient!['address'],
            ].join(' · '),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: _doctor?['id'] as String?,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Bác sĩ',
          prefixIcon: const Icon(Icons.medical_services_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: [
          for (final d in data.doctors)
            DropdownMenuItem(value: d['id'] as String, child: Text('BS. ${d['name']}')),
        ],
        onChanged: (id) => setState(() =>
            _doctor = data.doctors.cast<Map<String, dynamic>?>().firstWhere(
                (d) => d!['id'] == id,
                orElse: () => null)),
      ),
      const SizedBox(height: 14),
      _field(_complaint, 'Lý do khám', lines: 2),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: _field(_icdCode, 'Mã ICD-10')),
        const SizedBox(width: 10),
        Expanded(child: _field(_icdName, 'Tên bệnh (chẩn đoán chính) *')),
      ]),
      const SizedBox(height: 14),
      _field(_diagnosis, 'Kết luận / chẩn đoán chi tiết', lines: 2),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _field(_weight, 'Cân nặng (kg)', keyboard: TextInputType.number)),
        const SizedBox(width: 10),
        Expanded(child: _field(_revisitDays, 'Tái khám sau (ngày)', keyboard: TextInputType.number)),
      ]),
      const SizedBox(height: 14),
      DropdownButtonFormField<int>(
        initialValue: _hinhThuc,
        decoration: InputDecoration(
          labelText: 'Hình thức điều trị',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: const [
          DropdownMenuItem(value: 2, child: Text('Ngoại trú')),
          DropdownMenuItem(value: 1, child: Text('Nội trú')),
        ],
        onChanged: (v) => setState(() => _hinhThuc = v ?? 2),
      ),
      if (DtqgRules.isUnder72Months(DateTime.tryParse(_patient?['dob'] ?? ''), DateTime.now())) ...[
        const SizedBox(height: 14),
        _field(_guardian, 'Người giám hộ: họ tên, SĐT, địa chỉ * (trẻ dưới 72 tháng)', lines: 2),
      ],
      const SizedBox(height: 14),
      _field(_loiDan, 'Lời dặn của bác sĩ', lines: 2),
      const SizedBox(height: 14),
      _field(_notes, 'Ghi chú nội bộ', lines: 2),
    ]);
  }

  Widget _field(TextEditingController c, String label,
          {int lines = 1, TextInputType? keyboard}) =>
      TextField(
        controller: c,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _prescriptionPanel(_VisitData data, {required bool scrollable}) {
    final meds = data.medicines.where((m) {
      if (_medFilter.isEmpty) return true;
      return (m['name'] as String? ?? '').toLowerCase().contains(_medFilter);
    }).toList();

    final picker = Card(
      margin: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _medSearch,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm thuốc để thêm vào đơn',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _medFilter = v.toLowerCase()),
          ),
        ),
        SizedBox(
          height: 150,
          child: meds.isEmpty
              ? const _EmptyState(Icons.medication_outlined, 'Không có thuốc')
              : ListView.builder(
                  itemCount: meds.length,
                  itemBuilder: (_, i) {
                    final m = meds[i];
                    final stock = (m['stock'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      dense: true,
                      title: Text(m['name'] ?? ''),
                      subtitle: Text(
                          'Tồn: ${stock.toStringAsFixed(0)} · ${_money(m['price'] as num)}'),
                      trailing: const Icon(Icons.add_circle_outline, color: _kPrimary),
                      enabled: stock > 0,
                      onTap: () => _addMedicine(m),
                    );
                  },
                ),
        ),
      ]),
    );

    final linesView = _lines.isEmpty
        ? const _EmptyState(Icons.receipt_long_outlined, 'Chưa có thuốc trong đơn')
        : ListView.separated(
            shrinkWrap: !scrollable,
            physics: scrollable ? null : const NeverScrollableScrollPhysics(),
            itemCount: _lines.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _lineTile(i),
          );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _SectionTitle('Đơn thuốc'),
      picker,
      const SizedBox(height: 12),
      if (scrollable) Expanded(child: linesView) else linesView,
      const Divider(height: 24),
      Row(children: [
        const Expanded(
            child: Text('Tổng tiền thuốc',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        Text(_money(_total),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: _kPrimary)),
      ]),
      if (_lines.isNotEmpty)
        SwitchListTile(
          value: _dispenseNow,
          onChanged: (v) => setState(() => _dispenseNow = v),
          title: const Text('Cấp phát ngay'),
          contentPadding: EdgeInsets.zero,
        ),
      const SizedBox(height: 8),
      SizedBox(
        height: 52,
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline),
          label: const Text('Lưu phiếu khám', style: TextStyle(fontSize: 16)),
        ),
      ),
    ]);
  }

  Widget _lineTile(int i) {
    final l = _lines[i];
    final qty = (l['quantity'] as num).toDouble();
    final over = qty > (l['stock'] as num);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text(l['medicine_name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => setState(() {
                if (qty > 1) {
                  l['quantity'] = qty - 1;
                } else {
                  _lines.removeAt(i);
                }
              }),
            ),
            SizedBox(
                width: 36,
                child: Text(qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: over ? Colors.red : null))),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => l['quantity'] = qty + 1),
            ),
            SizedBox(
                width: 90,
                child: Text(_money(qty * (l['unit_price'] as num)),
                    textAlign: TextAlign.right)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => setState(() => _lines.removeAt(i)),
            ),
          ]),
          if (over)
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Vượt tồn kho',
                    style: TextStyle(color: Colors.red, fontSize: 12))),
          TextFormField(
            initialValue: l['dosage_instructions'] as String?,
            decoration: const InputDecoration(
              hintText: 'Liều dùng, VD: 2 viên/lần, 3 lần/ngày sau ăn',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => l['dosage_instructions'] = v,
          ),
        ]),
      ),
    );
  }
}

class _VisitData {
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> doctors;
  final List<Map<String, dynamic>> medicines;
  _VisitData(this.patients, this.doctors, this.medicines);
}

// ---------------------------------------------------------------------------
// Pharmacy: dispense queue + stock
// ---------------------------------------------------------------------------

class _PharmacyPane extends StatelessWidget {
  const _PharmacyPane();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(children: [
        TabBar(tabs: [
          Tab(icon: Icon(Icons.pending_actions), text: 'Đơn chờ cấp phát'),
          Tab(icon: Icon(Icons.point_of_sale), text: 'Bán theo đơn'),
          Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Tồn kho'),
        ]),
        Expanded(
            child: TabBarView(
                children: [_DispenseQueue(), PosSalePane(), _StockView()])),
      ]),
    );
  }
}

class _DispenseQueue extends StatefulWidget {
  const _DispenseQueue();

  @override
  State<_DispenseQueue> createState() => _DispenseQueueState();
}

class _DispenseQueueState extends State<_DispenseQueue> {
  final _repo = ClinicPharmaRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String? _selectedId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getPrescriptionsByStatus();
  }

  void _reload() => setState(() => _future = _repo.getPrescriptionsByStatus());

  Future<void> _dispense(Map<String, dynamic> rx) async {
    setState(() => _busy = true);
    try {
      await _repo.dispensePrescription(rx['id']);
      _selectedId = null;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã cấp phát đơn thuốc')));
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const _EmptyState(Icons.task_alt, 'Không có đơn chờ cấp phát');
        }
        return LayoutBuilder(builder: (context, c) {
          final split = c.maxWidth >= 800;
          final selected = list.cast<Map<String, dynamic>?>().firstWhere(
              (r) => r!['id'] == _selectedId,
              orElse: () => split ? list.first : null);

          final queue = ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final rx = list[i];
              return ListTile(
                selected: split && rx['id'] == selected?['id'],
                selectedTileColor: _kPrimary.withValues(alpha: 0.08),
                leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                title: Text(rx['patient_name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${_fmtTime(rx['prescription_date'])} · ${(rx['items'] as List).length} thuốc · ${_money(rx['total'] as num)}'),
                onTap: () {
                  if (split) {
                    setState(() => _selectedId = rx['id']);
                  } else {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.75,
                          child: _rxDetail(rx)),
                    );
                  }
                },
              );
            },
          );

          if (!split) return queue;
          return Row(children: [
            SizedBox(width: 340, child: queue),
            const VerticalDivider(width: 1),
            Expanded(
                child: selected == null
                    ? const _EmptyState(Icons.touch_app, 'Chọn một đơn')
                    : _rxDetail(selected)),
          ]);
        });
      },
    );
  }

  Widget _rxDetail(Map<String, dynamic> rx) {
    final items = (rx['items'] as List).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(rx['patient_name'] ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(
            '${_fmtDate(rx['prescription_date'])} ${_fmtTime(rx['prescription_date'])}'
            '${(rx['doctor_name'] as String? ?? '').isNotEmpty ? ' · BS. ${rx['doctor_name']}' : ''}',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              return ListTile(
                title: Text(it['medicine_name'] ?? ''),
                subtitle: Text(it['dosage_instructions'] as String? ?? ''),
                trailing: Text(
                    '${(it['quantity'] as num).toStringAsFixed(0)} × ${_money(it['unit_price'] as num)}'),
              );
            },
          ),
        ),
        const Divider(),
        Row(children: [
          const Expanded(
              child: Text('Tổng cộng', style: TextStyle(fontWeight: FontWeight.bold))),
          Text(_money(rx['total'] as num),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: _kPrimary)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _dispense(rx),
            icon: const Icon(Icons.check),
            label: const Text('Cấp phát', style: TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}

class _StockView extends StatefulWidget {
  const _StockView();

  @override
  State<_StockView> createState() => _StockViewState();
}

class _StockViewState extends State<_StockView> {
  final _repo = ClinicPharmaRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _search = '';
  bool _onlyAlerts = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getMedicines();
  }

  Future<void> _add() async {
    final r = await context.push<bool>('/clinic/medicines/form');
    if (r == true) setState(() => _future = _repo.getMedicines());
  }

  DateTime? _expiry(Map<String, dynamic> m) =>
      DateTime.tryParse(((m['custom_fields'] as Map)['expiry_date'] as String?) ?? '');

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm thuốc',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Sắp hết / hết hạn'),
            selected: _onlyAlerts,
            onSelected: (v) => setState(() => _onlyAlerts = v),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final soon = DateTime.now().add(const Duration(days: 90));
            final rows = (snap.data ?? []).where((m) {
              if (_search.isNotEmpty &&
                  !(m['name'] as String? ?? '').toLowerCase().contains(_search)) {
                return false;
              }
              if (_onlyAlerts) {
                final exp = _expiry(m);
                return (m['stock'] as num? ?? 0) < 10 || (exp != null && exp.isBefore(soon));
              }
              return true;
            }).toList();
            if (rows.isEmpty) {
              return const _EmptyState(Icons.medication_outlined, 'Không có thuốc');
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Tên thuốc')),
                    DataColumn(label: Text('Số lô')),
                    DataColumn(label: Text('Hạn dùng')),
                    DataColumn(label: Text('Giá bán'), numeric: true),
                    DataColumn(label: Text('Tồn'), numeric: true),
                  ],
                  rows: [
                    for (final m in rows)
                      DataRow(cells: [
                        DataCell(Text(m['name'] ?? '')),
                        DataCell(Text(
                            ((m['custom_fields'] as Map)['batch_number'] as String?) ?? '—')),
                        DataCell(() {
                          final exp = _expiry(m);
                          if (exp == null) return const Text('—');
                          final warn = exp.isBefore(soon);
                          return Text(_fmtDate(exp.toIso8601String()),
                              style: TextStyle(
                                  color: warn ? Colors.red : null,
                                  fontWeight: warn ? FontWeight.bold : null));
                        }()),
                        DataCell(Text(_money(m['price'] as num))),
                        DataCell(Text(
                          (m['stock'] as num? ?? 0).toStringAsFixed(0),
                          style: TextStyle(
                              color: (m['stock'] as num? ?? 0) < 10 ? Colors.red : null,
                              fontWeight: FontWeight.bold),
                        )),
                      ]),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
